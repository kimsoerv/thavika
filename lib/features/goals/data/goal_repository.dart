import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';

class GoalWithSaved {
  const GoalWithSaved(this.goal, this.savedMinor);

  final GoalRow goal;
  final int savedMinor;
}

class GoalRepository {
  GoalRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// All goals with the money saved so far, oldest first.
  Stream<List<GoalWithSaved>> watchGoals() {
    final g = _db.goals;
    final c = _db.goalContributions;
    final saved = c.amountMinor.sum();
    final query =
        _db.select(g).join([
            leftOuterJoin(c, c.goalId.equalsExp(g.id) & c.deletedAt.isNull()),
          ])
          ..addColumns([saved])
          ..where(g.deletedAt.isNull())
          ..groupBy([g.id])
          ..orderBy([OrderingTerm.asc(g.name)]);
    return query.watch().map(
      (rows) => rows
          .map((r) => GoalWithSaved(r.readTable(g), r.read(saved) ?? 0))
          .toList(),
    );
  }

  /// Money moved into goals during [month] (all goals together).
  Stream<int> watchMovedInMonth(DateTime month) {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    final c = _db.goalContributions;
    final total = c.amountMinor.sum();
    final query = _db.selectOnly(c)
      ..addColumns([total])
      ..where(
        c.deletedAt.isNull() &
            c.occurredOn.isBiggerOrEqualValue(from) &
            c.occurredOn.isSmallerThanValue(to),
      );
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// Goal money that already left a wallet (contributions with a wallet).
  Stream<int> watchMovedOutOfWallets() {
    final c = _db.goalContributions;
    final total = c.amountMinor.sum();
    final query = _db.selectOnly(c)
      ..addColumns([total])
      ..where(c.deletedAt.isNull() & c.walletId.isNotNull());
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  Stream<List<GoalContributionRow>> watchContributions(String goalId) {
    final query = _db.select(_db.goalContributions)
      ..where((c) => c.goalId.equals(goalId) & c.deletedAt.isNull())
      ..orderBy([
        (c) => OrderingTerm.desc(c.occurredOn),
        (c) => OrderingTerm.desc(c.updatedAt),
      ]);
    return query.watch();
  }

  Future<String> addGoal({
    required String name,
    required int targetMinor,
    required String currency,
    DateTime? targetDate,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.goals)
          .insert(
            GoalsCompanion.insert(
              id: id,
              name: name,
              targetMinor: targetMinor,
              currency: currency,
              targetDate: Value(targetDate),
              updatedAt: DateTime.now(),
            ),
          );
      await _db.enqueue('goals', id, 'upsert');
    });
    return id;
  }

  Future<void> updateGoal(
    String id, {
    required String name,
    required int targetMinor,
    DateTime? targetDate,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(
          name: Value(name),
          targetMinor: Value(targetMinor),
          targetDate: Value(targetDate),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('goals', id, 'upsert');
    });
  }

  /// Deletes the goal and its savings history (soft, so it can sync).
  Future<void> deleteGoal(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('goals', id, 'delete');

      final rows = await (_db.select(
        _db.goalContributions,
      )..where((c) => c.goalId.equals(id) & c.deletedAt.isNull())).get();
      for (final c in rows) {
        await (_db.update(
          _db.goalContributions,
        )..where((t) => t.id.equals(c.id))).write(
          GoalContributionsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('goal_contributions', c.id, 'delete');
      }
    });
  }

  Future<String> addContribution({
    required String goalId,
    required int amountMinor,
    required DateTime date,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.goalContributions)
          .insert(
            GoalContributionsCompanion.insert(
              id: id,
              goalId: goalId,
              amountMinor: amountMinor,
              occurredOn: date,
              updatedAt: DateTime.now(),
            ),
          );
      await _db.enqueue('goal_contributions', id, 'upsert');
    });
    return id;
  }

  Future<void> deleteContribution(String id) =>
      _setContributionDeleted(id, true);

  Future<void> restoreContribution(String id) =>
      _setContributionDeleted(id, false);

  Future<void> _setContributionDeleted(String id, bool deleted) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(
        _db.goalContributions,
      )..where((c) => c.id.equals(id))).write(
        GoalContributionsCompanion(
          deletedAt: Value(deleted ? now : null),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue(
        'goal_contributions',
        id,
        deleted ? 'delete' : 'upsert',
      );
    });
  }
}
