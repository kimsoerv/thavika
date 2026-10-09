import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';

class DebtWithPaid {
  const DebtWithPaid(this.debt, this.paidMinor);

  final DebtRow debt;
  final int paidMinor;
}

class DebtRepository {
  DebtRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// All debts with what was paid back so far. Open ones first, by due date.
  Stream<List<DebtWithPaid>> watchAll() {
    final d = _db.debts;
    final p = _db.debtPayments;
    final paid = p.amountMinor.sum();
    final query =
        _db.select(d).join([
            leftOuterJoin(p, p.debtId.equalsExp(d.id) & p.deletedAt.isNull()),
          ])
          ..addColumns([paid])
          ..where(d.deletedAt.isNull())
          ..groupBy([d.id])
          ..orderBy([OrderingTerm.asc(d.startedOn)]);
    return query.watch().map((rows) {
      final list = [
        for (final r in rows) DebtWithPaid(r.readTable(d), r.read(paid) ?? 0),
      ];
      bool open(DebtWithPaid x) => x.paidMinor < x.debt.amountMinor;
      list.sort((a, b) {
        if (open(a) != open(b)) return open(a) ? -1 : 1;
        final ad = a.debt.dueOn;
        final bd = b.debt.dueOn;
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return b.debt.startedOn.compareTo(a.debt.startedOn);
      });
      return list;
    });
  }

  Stream<List<DebtPaymentRow>> watchPayments(String debtId) {
    final query = _db.select(_db.debtPayments)
      ..where((p) => p.debtId.equals(debtId) & p.deletedAt.isNull())
      ..orderBy([
        (p) => OrderingTerm.desc(p.occurredOn),
        (p) => OrderingTerm.desc(p.updatedAt),
      ]);
    return query.watch();
  }

  Future<String> add({
    required String person,
    required String direction,
    required int amountMinor,
    required String currency,
    String note = '',
    required DateTime startedOn,
    DateTime? dueOn,
    String? walletId,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      final wallet = walletId ?? await _db.defaultWalletId();
      await _db
          .into(_db.debts)
          .insert(
            DebtsCompanion.insert(
              id: id,
              person: person,
              direction: direction,
              amountMinor: amountMinor,
              currency: currency,
              note: Value(note),
              startedOn: _day(startedOn),
              dueOn: Value(dueOn == null ? null : _day(dueOn)),
              walletId: Value(wallet),
              updatedAt: DateTime.now(),
            ),
          );
      await _db.enqueue('debts', id, 'upsert');
    });
    return id;
  }

  Future<void> update(
    String id, {
    required String person,
    required String direction,
    required int amountMinor,
    required String note,
    required DateTime startedOn,
    DateTime? dueOn,
    String? walletId,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.debts)..where((t) => t.id.equals(id))).write(
        DebtsCompanion(
          person: Value(person),
          direction: Value(direction),
          amountMinor: Value(amountMinor),
          note: Value(note),
          startedOn: Value(_day(startedOn)),
          dueOn: Value(dueOn == null ? null : _day(dueOn)),
          walletId: walletId == null ? const Value.absent() : Value(walletId),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('debts', id, 'upsert');
    });
  }

  /// Removes the debt and its payments from every list and balance.
  Future<void> delete(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.debts)..where((t) => t.id.equals(id))).write(
        DebtsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('debts', id, 'delete');
      final rows = await (_db.select(
        _db.debtPayments,
      )..where((p) => p.debtId.equals(id) & p.deletedAt.isNull())).get();
      for (final p in rows) {
        await (_db.update(
          _db.debtPayments,
        )..where((t) => t.id.equals(p.id))).write(
          DebtPaymentsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('debt_payments', p.id, 'delete');
      }
    });
  }

  Future<String> addPayment({
    required String debtId,
    required int amountMinor,
    required DateTime date,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              id: id,
              debtId: debtId,
              amountMinor: amountMinor,
              occurredOn: _day(date),
              updatedAt: DateTime.now(),
            ),
          );
      await _db.enqueue('debt_payments', id, 'upsert');
    });
    return id;
  }

  Future<void> deletePayment(String id) => _setPaymentDeleted(id, true);

  Future<void> restorePayment(String id) => _setPaymentDeleted(id, false);

  Future<void> _setPaymentDeleted(String id, bool deleted) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.debtPayments)..where((t) => t.id.equals(id))).write(
        DebtPaymentsCompanion(
          deletedAt: Value(deleted ? now : null),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('debt_payments', id, deleted ? 'delete' : 'upsert');
    });
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
