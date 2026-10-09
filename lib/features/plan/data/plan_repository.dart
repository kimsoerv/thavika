import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../domain/plan_templates.dart';

class PlanWithItems {
  const PlanWithItems(this.plan, this.items);

  final PlanRow plan;
  final List<PlanItemRow> items;
}

class PlanRepository {
  PlanRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// The plan that applies to the month of [month] with its lines, or null.
  /// A month uses the latest plan that started on or before it, so earlier
  /// months keep the plan they had.
  Stream<PlanWithItems?> watchForMonth(DateTime month) {
    final first = DateTime(month.year, month.month);
    final query = _db.select(_db.plans)
      ..where(
        (p) =>
            p.deletedAt.isNull() &
            p.activeFrom.isNotNull() &
            p.activeFrom.isSmallerOrEqualValue(first),
      )
      ..orderBy([
        (p) => OrderingTerm.desc(p.activeFrom),
        (p) => OrderingTerm.desc(p.updatedAt),
      ])
      ..limit(1);
    return query.watchSingleOrNull().asyncMap((plan) async {
      if (plan == null) return null;
      final items =
          await (_db.select(_db.planItems)
                ..where((i) => i.planId.equals(plan.id) & i.deletedAt.isNull())
                ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
              .get();
      return PlanWithItems(plan, items);
    });
  }

  /// The plan of the current month.
  Stream<PlanWithItems?> watchActive() => watchForMonth(DateTime.now());

  /// Saves a plan that applies from [month] on (this month by default).
  /// A plan already saved for the same month is replaced; plans of earlier
  /// months are kept as history.
  Future<void> savePlan({
    required String template,
    required int incomeMinor,
    required String currency,
    required List<PlanItemDraft> items,
    DateTime? month,
    String? name,
  }) async {
    final now = DateTime.now();
    final from = DateTime((month ?? now).year, (month ?? now).month);
    await _db.transaction(() async {
      await _removeForMonth(from, now);

      final planId = _uuid.v4();
      await _db
          .into(_db.plans)
          .insert(
            PlansCompanion.insert(
              id: planId,
              template: template,
              incomeMinor: incomeMinor,
              currency: currency,
              name: Value(name),
              activeFrom: Value(from),
              updatedAt: now,
            ),
          );
      await _db.enqueue('plans', planId, 'upsert');

      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final id = _uuid.v4();
        await _db
            .into(_db.planItems)
            .insert(
              PlanItemsCompanion.insert(
                id: id,
                planId: planId,
                groupName: item.group,
                name: item.name,
                categoryId: Value(item.categoryId),
                amountMinor: item.amountMinor,
                isFixed: Value(item.isFixed),
                sortOrder: Value(index),
                updatedAt: now,
              ),
            );
        await _db.enqueue('plan_items', id, 'upsert');
      }
    });
  }

  Future<void> _removeForMonth(DateTime from, DateTime now) async {
    final old = await (_db.select(
      _db.plans,
    )..where((p) => p.deletedAt.isNull() & p.activeFrom.equals(from))).get();
    for (final p in old) {
      await (_db.update(_db.plans)..where((t) => t.id.equals(p.id))).write(
        PlansCompanion(
          isActive: const Value(false),
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('plans', p.id, 'delete');

      final oldItems = await (_db.select(
        _db.planItems,
      )..where((i) => i.planId.equals(p.id) & i.deletedAt.isNull())).get();
      for (final i in oldItems) {
        await (_db.update(
          _db.planItems,
        )..where((t) => t.id.equals(i.id))).write(
          PlanItemsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('plan_items', i.id, 'delete');
      }
    }
  }

  // ---- Saved plans ("library") ------------------------------------------

  /// Plans saved by name that apply to no month until the user picks one.
  Stream<List<PlanRow>> watchLibrary() {
    final query = _db.select(_db.plans)
      ..where((p) => p.deletedAt.isNull() & p.activeFrom.isNull())
      ..orderBy([
        (p) => OrderingTerm.asc(p.name),
        (p) => OrderingTerm.asc(p.updatedAt),
      ]);
    return query.watch();
  }

  /// Copies a plan with its lines. [activeFrom] null puts the copy in the
  /// library. Returns the new plan's id.
  Future<String> duplicateAs(
    String planId, {
    DateTime? activeFrom,
    String? name,
  }) async {
    final now = DateTime.now();
    final newId = _uuid.v4();
    await _db.transaction(() async {
      final source = await (_db.select(
        _db.plans,
      )..where((p) => p.id.equals(planId))).getSingle();
      final items =
          await (_db.select(_db.planItems)
                ..where((i) => i.planId.equals(planId) & i.deletedAt.isNull())
                ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
              .get();
      await _db
          .into(_db.plans)
          .insert(
            PlansCompanion.insert(
              id: newId,
              template: source.template,
              incomeMinor: source.incomeMinor,
              currency: source.currency,
              name: Value(name ?? source.name),
              activeFrom: Value(activeFrom),
              updatedAt: now,
            ),
          );
      await _db.enqueue('plans', newId, 'upsert');
      for (final item in items) {
        final id = _uuid.v4();
        await _db
            .into(_db.planItems)
            .insert(
              PlanItemsCompanion.insert(
                id: id,
                planId: newId,
                groupName: item.groupName,
                name: item.name,
                categoryId: Value(item.categoryId),
                amountMinor: item.amountMinor,
                isFixed: Value(item.isFixed),
                sortOrder: Value(item.sortOrder),
                updatedAt: now,
              ),
            );
        await _db.enqueue('plan_items', id, 'upsert');
      }
    });
    return newId;
  }

  Future<String> saveToLibrary(String planId, String name) =>
      duplicateAs(planId, name: name);

  /// Makes a saved plan the plan of [month] (and later months). The saved
  /// plan stays in the library.
  Future<void> applyFromLibrary(String libraryId, {DateTime? month}) async {
    final now = DateTime.now();
    final from = DateTime((month ?? now).year, (month ?? now).month);
    await _db.transaction(() async {
      await _removeForMonth(from, now);
      await duplicateAs(libraryId, activeFrom: from);
    });
  }

  Future<void> deleteFromLibrary(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.plans)..where((t) => t.id.equals(id))).write(
        PlansCompanion(
          isActive: const Value(false),
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('plans', id, 'delete');
    });
  }
}
