import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../domain/recurrence.dart';

class RecurringWithCategory {
  const RecurringWithCategory(this.rule, this.category);

  final RecurringRow rule;
  final CategoryRow? category;
}

class RecurringRepository {
  RecurringRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<RecurringWithCategory>> watchAll() {
    final r = _db.recurringRules;
    final c = _db.categories;
    final query =
        _db.select(r).join([leftOuterJoin(c, c.id.equalsExp(r.categoryId))])
          ..where(r.deletedAt.isNull())
          ..orderBy([OrderingTerm.asc(r.nextRunOn)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (x) => RecurringWithCategory(x.readTable(r), x.readTableOrNull(c)),
          )
          .toList(),
    );
  }

  Future<String> add({
    required String type,
    required int amountMinor,
    required String currency,
    required String categoryId,
    required String note,
    required String frequency,
    required DateTime startOn,
    bool isBill = false,
    bool autoCreate = true,
    int remindDaysBefore = 2,
  }) async {
    final id = _uuid.v4();
    final start = dateOnly(startOn);
    await _db.transaction(() async {
      await _db
          .into(_db.recurringRules)
          .insert(
            RecurringRulesCompanion.insert(
              id: id,
              type: type,
              amountMinor: amountMinor,
              currency: currency,
              categoryId: categoryId,
              note: Value(note),
              frequency: frequency,
              startOn: start,
              nextRunOn: start,
              isBill: Value(isBill),
              autoCreate: Value(autoCreate),
              remindDaysBefore: Value(remindDaysBefore),
              updatedAt: DateTime.now(),
            ),
          );
      await _db.enqueue('recurring_rules', id, 'upsert');
    });
    return id;
  }

  /// Changes a rule. Changing the first date restarts the schedule from it.
  Future<void> update(
    RecurringRow existing, {
    required String type,
    required int amountMinor,
    required String categoryId,
    required String note,
    required String frequency,
    required DateTime startOn,
    required bool isActive,
    bool isBill = false,
    bool autoCreate = true,
    int remindDaysBefore = 2,
  }) async {
    final start = dateOnly(startOn);
    final restart = start != dateOnly(existing.startOn);
    await _db.transaction(() async {
      await (_db.update(
        _db.recurringRules,
      )..where((r) => r.id.equals(existing.id))).write(
        RecurringRulesCompanion(
          type: Value(type),
          amountMinor: Value(amountMinor),
          categoryId: Value(categoryId),
          note: Value(note),
          frequency: Value(frequency),
          startOn: Value(start),
          nextRunOn: restart ? Value(start) : const Value.absent(),
          isActive: Value(isActive),
          isBill: Value(isBill),
          autoCreate: Value(autoCreate),
          remindDaysBefore: Value(remindDaysBefore),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('recurring_rules', existing.id, 'upsert');
    });
  }

  Future<void> delete(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(
        _db.recurringRules,
      )..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(
          deletedAt: Value(now),
          isActive: const Value(false),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('recurring_rules', id, 'delete');
    });
  }

  /// Creates the entries that are due up to [today] and moves each rule to
  /// its next date. Safe to call often: entries have a fixed id per rule and
  /// date, so nothing is created twice. Returns how many entries were added.
  Future<int> generateDue(DateTime today) async {
    var created = 0;
    await _db.transaction(() async {
      final rules = await (_db.select(
        _db.recurringRules,
      )..where((r) => r.isActive.equals(true) & r.deletedAt.isNull())).get();
      final defaultWallet = await _db.defaultWalletId();
      for (final rule in rules) {
        // A bill that changes every time waits until the user marks it paid.
        if (rule.isBill && !rule.autoCreate) continue;
        final result = dueDates(
          nextRunOn: rule.nextRunOn,
          frequency: rule.frequency,
          anchorDay: rule.startOn.day,
          today: today,
        );
        if (result.due.isEmpty) continue;

        for (final date in result.due) {
          final id = recurringEntryId(rule.id, date);
          final exists = await (_db.select(
            _db.transactions,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
          if (exists != null) continue;
          await _db
              .into(_db.transactions)
              .insert(
                TransactionsCompanion.insert(
                  id: id,
                  type: rule.type,
                  amountMinor: rule.amountMinor,
                  currency: rule.currency,
                  categoryId: rule.categoryId,
                  note: Value(rule.note),
                  walletId: Value(rule.walletId ?? defaultWallet),
                  occurredOn: date,
                  updatedAt: DateTime.now(),
                ),
              );
          await _db.enqueue('transactions', id, 'upsert');
          created++;
        }

        await (_db.update(
          _db.recurringRules,
        )..where((r) => r.id.equals(rule.id))).write(
          RecurringRulesCompanion(
            nextRunOn: Value(result.next),
            updatedAt: Value(DateTime.now()),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('recurring_rules', rule.id, 'upsert');
      }
    });
    return created;
  }

  /// Records that a bill was paid: creates the entry for its due date (with
  /// the real [amountMinor], dated [paidOn]) and moves the bill to its next
  /// date. Does nothing if that due date was already paid.
  Future<void> markPaid(
    String ruleId, {
    required int amountMinor,
    DateTime? paidOn,
  }) async {
    await _db.transaction(() async {
      final rule = await (_db.select(
        _db.recurringRules,
      )..where((r) => r.id.equals(ruleId))).getSingle();
      final due = dateOnly(rule.nextRunOn);
      final id = recurringEntryId(rule.id, due);
      final exists = await (_db.select(
        _db.transactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final defaultWallet = await _db.defaultWalletId();
      if (exists == null) {
        await _db
            .into(_db.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: id,
                type: rule.type,
                amountMinor: amountMinor,
                currency: rule.currency,
                categoryId: rule.categoryId,
                note: Value(rule.note),
                walletId: Value(rule.walletId ?? defaultWallet),
                occurredOn: dateOnly(paidOn ?? DateTime.now()),
                updatedAt: DateTime.now(),
              ),
            );
        await _db.enqueue('transactions', id, 'upsert');
      }
      await (_db.update(
        _db.recurringRules,
      )..where((r) => r.id.equals(rule.id))).write(
        RecurringRulesCompanion(
          nextRunOn: Value(advance(due, rule.frequency, rule.startOn.day)),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('recurring_rules', rule.id, 'upsert');
    });
  }
}

/// Reads a recurring rule as an entry-like item, for lists.
extension RecurringTx on RecurringWithCategory {
  bool get isIncome => rule.type == 'income';
}
