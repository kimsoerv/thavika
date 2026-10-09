import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Live list of categories of one kind ('expense' or 'income').
  Stream<List<CategoryRow>> watch(String kind) {
    final query = _db.select(_db.categories)
      ..where(
        (c) =>
            c.kind.equals(kind) &
            c.deletedAt.isNull() &
            c.isHidden.equals(false),
      )
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
    return query.watch();
  }

  /// Every category that can be offered, both kinds.
  Stream<List<CategoryRow>> watchAllVisible() {
    final query = _db.select(_db.categories)
      ..where((c) => c.deletedAt.isNull() & c.isHidden.equals(false))
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
    return query.watch();
  }

  /// Creates a user category and returns its id.
  Future<String> add({
    required String name,
    required String icon,
    required String kind,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: id,
              name: name,
              icon: icon,
              kind: kind,
              sortOrder: const Value(500),
              updatedAt: now,
            ),
          );
      await _db.enqueue('categories', id, 'upsert');
    });
    return id;
  }

  /// Every category of one kind, including hidden ones, for the manage screen.
  Stream<List<CategoryRow>> watchManage(String kind) {
    final query = _db.select(_db.categories)
      ..where((c) => c.kind.equals(kind) & c.deletedAt.isNull())
      ..orderBy([
        (c) => OrderingTerm.asc(c.sortOrder),
        (c) => OrderingTerm.asc(c.name),
      ]);
    return query.watch();
  }

  /// How many entries each category has.
  Stream<Map<String, int>> watchUsage() {
    final count = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.categoryId, count])
      ..where(_db.transactions.deletedAt.isNull())
      ..groupBy([_db.transactions.categoryId]);
    return query.watch().map(
      (rows) => {
        for (final r in rows)
          r.read(_db.transactions.categoryId)!: r.read(count) ?? 0,
      },
    );
  }

  /// Renames a category or changes its icon. Built-in ones keep their name
  /// (it is translated), so only custom categories use this.
  Future<void> update(
    String id, {
    required String name,
    required String icon,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(name),
          icon: Value(icon),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('categories', id, 'upsert');
    });
  }

  /// Hidden categories are not offered when adding entries. Entries that
  /// already use them keep them.
  Future<void> setHidden(String id, bool hidden) async {
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.categories,
      )..where((c) => c.id.equals(id))).getSingle();
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          isHidden: Value(hidden),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      // Built-in categories are the same on every phone and are not synced.
      if (!row.isDefault) await _db.enqueue('categories', id, 'upsert');
    });
  }

  /// True when entries, recurring entries or plan lines use the category.
  Future<bool> isInUse(String id) async {
    final tx =
        await (_db.select(_db.transactions)
              ..where((t) => t.categoryId.equals(id) & t.deletedAt.isNull())
              ..limit(1))
            .get();
    if (tx.isNotEmpty) return true;
    final rules =
        await (_db.select(_db.recurringRules)
              ..where((r) => r.categoryId.equals(id) & r.deletedAt.isNull())
              ..limit(1))
            .get();
    if (rules.isNotEmpty) return true;
    final lines =
        await (_db.select(_db.planItems)
              ..where((i) => i.categoryId.equals(id) & i.deletedAt.isNull())
              ..limit(1))
            .get();
    return lines.isNotEmpty;
  }

  /// Deletes a custom category. Its entries, recurring entries and plan
  /// lines move to [moveTo], which must be a category of the same kind.
  Future<void> delete(String id, {required String moveTo}) async {
    if (id == moveTo) {
      throw ArgumentError('Pick a different category to move to.');
    }
    final now = DateTime.now();
    await _db.transaction(() async {
      final from = await (_db.select(
        _db.categories,
      )..where((c) => c.id.equals(id))).getSingle();
      if (from.isDefault) {
        throw ArgumentError('Built-in categories can only be hidden.');
      }
      final target = await (_db.select(
        _db.categories,
      )..where((c) => c.id.equals(moveTo))).getSingle();
      if (target.kind != from.kind) {
        throw ArgumentError('Pick a category of the same kind.');
      }

      final txs = await (_db.select(
        _db.transactions,
      )..where((t) => t.categoryId.equals(id))).get();
      for (final t in txs) {
        await (_db.update(
          _db.transactions,
        )..where((x) => x.id.equals(t.id))).write(
          TransactionsCompanion(
            categoryId: Value(moveTo),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('transactions', t.id, 'upsert');
      }

      final rules = await (_db.select(
        _db.recurringRules,
      )..where((r) => r.categoryId.equals(id))).get();
      for (final r in rules) {
        await (_db.update(
          _db.recurringRules,
        )..where((x) => x.id.equals(r.id))).write(
          RecurringRulesCompanion(
            categoryId: Value(moveTo),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('recurring_rules', r.id, 'upsert');
      }

      // Plan lines show the category name; built-in ones store their key.
      final lineName = target.isDefault ? target.id : target.name;
      final lines = await (_db.select(
        _db.planItems,
      )..where((i) => i.categoryId.equals(id))).get();
      for (final i in lines) {
        await (_db.update(
          _db.planItems,
        )..where((x) => x.id.equals(i.id))).write(
          PlanItemsCompanion(
            categoryId: Value(moveTo),
            name: Value(lineName),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('plan_items', i.id, 'upsert');
      }

      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('categories', id, 'delete');
    });
  }
}
