import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/goals/data/challenge_repository.dart';
import 'package:thavika/features/goals/data/goal_repository.dart';
import 'package:thavika/features/goals/domain/challenge_math.dart';

void main() {
  group('ChallengeMath', () {
    test('step-up amounts', () {
      expect(ChallengeMath.stepAmount('weekly', 100, 5), 500);
      expect(ChallengeMath.stepAmount('fixed', 100, 5), 100);
    });

    test('the classic 52 week challenge saves 1378 units', () {
      expect(ChallengeMath.totalAmount('weekly', 1, 52), 1378);
      expect(ChallengeMath.totalAmount('fixed', 500, 10), 5000);
    });

    test('steps are stored as text and come back', () {
      expect(ChallengeMath.parseSteps(''), isEmpty);
      expect(ChallengeMath.parseSteps('1,2, 5'), {1, 2, 5});
      expect(ChallengeMath.encodeSteps({5, 1, 2}), '1,2,5');
    });

    test('due step counts weeks from the start and stops at the last', () {
      final start = DateTime(2026, 3, 1);
      expect(ChallengeMath.dueStep(start, DateTime(2026, 2, 28), 52), 0);
      expect(ChallengeMath.dueStep(start, DateTime(2026, 3, 1), 52), 1);
      expect(ChallengeMath.dueStep(start, DateTime(2026, 3, 7), 52), 1);
      expect(ChallengeMath.dueStep(start, DateTime(2026, 3, 8), 52), 2);
      expect(ChallengeMath.dueStep(start, DateTime(2030, 1, 1), 10), 10);
    });

    test('streak counts weeks in a row', () {
      expect(ChallengeMath.streak({1, 2, 3}, 3), 3);
      // The current week is not done yet: the streak is kept.
      expect(ChallengeMath.streak({1, 2}, 3), 2);
      // A missed week breaks it.
      expect(ChallengeMath.streak({1, 3, 4}, 4), 2);
      expect(ChallengeMath.streak({1, 3}, 4), 1);
      expect(ChallengeMath.streak({1, 4}, 5), 1);
      expect(ChallengeMath.streak({}, 0), 0);
    });

    test('behind ignores the current week', () {
      expect(ChallengeMath.behind({1, 2}, 3), 0);
      expect(ChallengeMath.behind({1}, 4), 2);
    });

    test('saved so far', () {
      expect(ChallengeMath.savedSoFar('weekly', 100, {1, 3}), 400);
    });
  });

  group('ChallengeRepository', () {
    late AppDatabase db;
    late ChallengeRepository repo;
    late GoalRepository goals;
    late String goalId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = ChallengeRepository(db);
      goals = GoalRepository(db);
      goalId = await goals.addGoal(
        name: 'Trip',
        currency: 'USD',
        targetMinor: 100000,
      );
    });

    tearDown(() => db.close());

    Future<int> saved() async =>
        (await goals.watchGoals().first).single.savedMinor;

    test('a goal has no challenge at first', () async {
      expect(await repo.watchForGoal(goalId).first, isNull);
    });

    test(
      'doing a week adds that week to the goal, undoing removes it',
      () async {
        final id = await repo.start(
          goalId: goalId,
          kind: 'weekly',
          unitMinor: 100,
          steps: 52,
        );
        await repo.toggleStep(id, 3);
        expect(await saved(), 300);
        final c = (await repo.watchForGoal(goalId).first)!;
        expect(c.completedSteps, '3');

        await repo.toggleStep(id, 5);
        expect(await saved(), 800);

        await repo.toggleStep(id, 3);
        expect(await saved(), 500);
        expect((await repo.watchForGoal(goalId).first)!.completedSteps, '5');

        // Doing the week again after undoing it counts once.
        await repo.toggleStep(id, 3);
        expect(await saved(), 800);
      },
    );

    test('stopping the challenge keeps the money', () async {
      final id = await repo.start(
        goalId: goalId,
        kind: 'fixed',
        unitMinor: 500,
        steps: 10,
      );
      await repo.toggleStep(id, 1);
      await repo.delete(id);
      expect(await repo.watchForGoal(goalId).first, isNull);
      expect(await saved(), 500);
    });

    test('the contribution id is the same for the same week', () {
      expect(
        ChallengeRepository.contributionId('a', 2),
        ChallengeRepository.contributionId('a', 2),
      );
      expect(
        ChallengeRepository.contributionId('a', 2),
        isNot(ChallengeRepository.contributionId('a', 3)),
      );
    });
  });
}
