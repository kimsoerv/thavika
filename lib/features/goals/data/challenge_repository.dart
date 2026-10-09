import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../domain/challenge_math.dart';

class ChallengeRepository {
  ChallengeRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// The goal's running challenge, or null.
  Stream<ChallengeRow?> watchForGoal(String goalId) {
    final query = _db.select(_db.challenges)
      ..where((c) => c.goalId.equals(goalId) & c.deletedAt.isNull())
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<String> start({
    required String goalId,
    required String kind,
    required int unitMinor,
    required int steps,
    DateTime? startOn,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final day = DateTime(
      (startOn ?? now).year,
      (startOn ?? now).month,
      (startOn ?? now).day,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.challenges)
          .insert(
            ChallengesCompanion.insert(
              id: id,
              goalId: goalId,
              kind: kind,
              unitMinor: unitMinor,
              steps: steps,
              startOn: day,
              updatedAt: now,
            ),
          );
      await _db.enqueue('challenges', id, 'upsert');
    });
    return id;
  }

  /// Same id on every phone for the same challenge week.
  static String contributionId(String challengeId, int step) =>
      _uuid.v5(Namespace.url.value, 'challenge:$challengeId:$step');

  /// Marks a week done (and puts that week's money into the goal) or takes
  /// it back (and removes the money again).
  Future<void> toggleStep(String challengeId, int step) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      final c = await (_db.select(
        _db.challenges,
      )..where((t) => t.id.equals(challengeId))).getSingle();
      final done = ChallengeMath.parseSteps(c.completedSteps);
      final cid = contributionId(c.id, step);
      final existing = await (_db.select(
        _db.goalContributions,
      )..where((g) => g.id.equals(cid))).getSingleOrNull();

      if (done.contains(step)) {
        done.remove(step);
        if (existing != null && existing.deletedAt == null) {
          await (_db.update(
            _db.goalContributions,
          )..where((g) => g.id.equals(cid))).write(
            GoalContributionsCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
              syncState: const Value('pending'),
            ),
          );
          await _db.enqueue('goal_contributions', cid, 'delete');
        }
      } else {
        done.add(step);
        final amount = ChallengeMath.stepAmount(c.kind, c.unitMinor, step);
        final today = DateTime(now.year, now.month, now.day);
        if (existing == null) {
          await _db
              .into(_db.goalContributions)
              .insert(
                GoalContributionsCompanion.insert(
                  id: cid,
                  goalId: c.goalId,
                  amountMinor: amount,
                  occurredOn: today,
                  updatedAt: now,
                ),
              );
        } else {
          await (_db.update(
            _db.goalContributions,
          )..where((g) => g.id.equals(cid))).write(
            GoalContributionsCompanion(
              amountMinor: Value(amount),
              occurredOn: Value(today),
              deletedAt: const Value(null),
              updatedAt: Value(now),
              syncState: const Value('pending'),
            ),
          );
        }
        await _db.enqueue('goal_contributions', cid, 'upsert');
      }

      await (_db.update(_db.challenges)..where((t) => t.id.equals(c.id))).write(
        ChallengesCompanion(
          completedSteps: Value(ChallengeMath.encodeSteps(done)),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('challenges', c.id, 'upsert');
    });
  }

  /// Stops the challenge. Money already put into the goal stays.
  Future<void> delete(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.challenges)..where((t) => t.id.equals(id))).write(
        ChallengesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('challenges', id, 'delete');
    });
  }
}
