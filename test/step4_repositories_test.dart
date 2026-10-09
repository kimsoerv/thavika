import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/core/services/settings_service.dart';
import 'package:thavika/features/goals/data/goal_repository.dart';
import 'package:thavika/features/plan/data/plan_repository.dart';
import 'package:thavika/features/plan/domain/plan_templates.dart';
import 'package:thavika/features/recurring/data/recurring_repository.dart';
import 'package:thavika/features/recurring/domain/recurrence.dart';
import 'package:thavika/features/settings/application/backup_service.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('goals', () {
    test('saved amount is the sum of contributions', () async {
      final repo = GoalRepository(db);
      final id = await repo.addGoal(
        name: 'New phone',
        targetMinor: 50000,
        currency: 'USD',
      );
      await repo.addContribution(
        goalId: id,
        amountMinor: 10000,
        date: DateTime(2026, 10, 1),
      );
      final second = await repo.addContribution(
        goalId: id,
        amountMinor: 5000,
        date: DateTime(2026, 10, 5),
      );

      var goals = await repo.watchGoals().first;
      expect(goals.single.savedMinor, 15000);

      await repo.deleteContribution(second);
      goals = await repo.watchGoals().first;
      expect(goals.single.savedMinor, 10000);

      await repo.restoreContribution(second);
      goals = await repo.watchGoals().first;
      expect(goals.single.savedMinor, 15000);
    });

    test('a goal with no money has zero saved', () async {
      final repo = GoalRepository(db);
      await repo.addGoal(name: 'Trip', targetMinor: 100000, currency: 'USD');
      expect((await repo.watchGoals().first).single.savedMinor, 0);
    });

    test('deleting a goal hides it and its history', () async {
      final repo = GoalRepository(db);
      final id = await repo.addGoal(
        name: 'Trip',
        targetMinor: 100000,
        currency: 'USD',
      );
      await repo.addContribution(
        goalId: id,
        amountMinor: 100,
        date: DateTime(2026, 10, 1),
      );
      await repo.deleteGoal(id);
      expect(await repo.watchGoals().first, isEmpty);
      expect(await repo.watchContributions(id).first, isEmpty);
    });

    test('editing a goal changes its name, target and date', () async {
      final repo = GoalRepository(db);
      final id = await repo.addGoal(
        name: 'Trip',
        targetMinor: 100000,
        currency: 'USD',
      );
      await repo.updateGoal(
        id,
        name: 'Big trip',
        targetMinor: 200000,
        targetDate: DateTime(2027, 1, 1),
      );
      final goal = (await repo.watchGoals().first).single.goal;
      expect(goal.name, 'Big trip');
      expect(goal.targetMinor, 200000);
      expect(goal.targetDate, DateTime(2027, 1, 1));
    });
  });

  group('recurring', () {
    test('creates the due entries once and moves to the next date', () async {
      final repo = RecurringRepository(db);
      await repo.add(
        type: 'expense',
        amountMinor: 40000,
        currency: 'USD',
        categoryId: 'cat_housing',
        note: 'Rent',
        frequency: 'monthly',
        startOn: DateTime(2026, 8, 1),
      );

      // Today is 9 Oct: 1 Aug, 1 Sep and 1 Oct are due.
      expect(await repo.generateDue(DateTime(2026, 10, 9)), 3);
      // Running again the same day adds nothing.
      expect(await repo.generateDue(DateTime(2026, 10, 9)), 0);

      final tx = TransactionRepository(db);
      final list = await tx
          .watchRange(DateTime(2026, 8), DateTime(2026, 11))
          .first;
      expect(list, hasLength(3));
      expect(list.every((e) => e.tx.note == 'Rent'), isTrue);

      final rule = (await repo.watchAll().first).single.rule;
      expect(rule.nextRunOn, DateTime(2026, 11, 1));

      // A month later one more entry appears.
      expect(await repo.generateDue(DateTime(2026, 11, 2)), 1);
    });

    test('does not duplicate an entry that already exists', () async {
      final repo = RecurringRepository(db);
      final id = await repo.add(
        type: 'income',
        amountMinor: 200000,
        currency: 'USD',
        categoryId: 'cat_salary',
        note: 'Salary',
        frequency: 'monthly',
        startOn: DateTime(2026, 10, 5),
      );
      // Pretend another phone already created this date's entry.
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: recurringEntryId(id, DateTime(2026, 10, 5)),
              type: 'income',
              amountMinor: 200000,
              currency: 'USD',
              categoryId: 'cat_salary',
              occurredOn: DateTime(2026, 10, 5),
              updatedAt: DateTime.now(),
            ),
          );
      expect(await repo.generateDue(DateTime(2026, 10, 9)), 0);
      final all = await db.select(db.transactions).get();
      expect(all, hasLength(1));
    });

    test('paused and deleted rules create nothing', () async {
      final repo = RecurringRepository(db);
      final id = await repo.add(
        type: 'expense',
        amountMinor: 100,
        currency: 'USD',
        categoryId: 'cat_bills',
        note: '',
        frequency: 'weekly',
        startOn: DateTime(2026, 10, 1),
      );
      final rule = (await repo.watchAll().first).single.rule;
      await repo.update(
        rule,
        type: 'expense',
        amountMinor: 100,
        categoryId: 'cat_bills',
        note: '',
        frequency: 'weekly',
        startOn: DateTime(2026, 10, 1),
        isActive: false,
      );
      expect(await repo.generateDue(DateTime(2026, 10, 9)), 0);

      await repo.delete(id);
      expect(await repo.watchAll().first, isEmpty);
    });
  });

  group('category usage', () {
    test('counts entries per category', () async {
      final repo = TransactionRepository(db);
      for (final cat in ['cat_food', 'cat_food', 'cat_bills']) {
        await repo.add(
          type: 'expense',
          amountMinor: 100,
          currency: 'USD',
          categoryId: cat,
          note: '',
          date: DateTime(2026, 10, 1),
        );
      }
      final usage = await repo.categoryUsage('expense');
      expect(usage['cat_food'], 2);
      expect(usage['cat_bills'], 1);
      expect(await repo.categoryUsage('income'), isEmpty);
    });
  });

  group('backup', () {
    Future<void> fill(AppDatabase source) async {
      final tx = TransactionRepository(source);
      await tx.add(
        type: 'expense',
        amountMinor: 450,
        currency: 'USD',
        categoryId: 'cat_food',
        note: 'coffee, "large"',
        date: DateTime(2026, 10, 9),
      );
      await tx.add(
        type: 'income',
        amountMinor: 200000,
        currency: 'USD',
        categoryId: 'cat_salary',
        note: '',
        date: DateTime(2026, 10, 1),
      );
      await PlanRepository(source).savePlan(
        template: 'balanced',
        incomeMinor: 200000,
        currency: 'USD',
        items: PlanTemplates.balanced.build(200000, 'USD'),
      );
      final goals = GoalRepository(source);
      final g = await goals.addGoal(
        name: 'Phone',
        targetMinor: 50000,
        currency: 'USD',
        targetDate: DateTime(2026, 12, 31),
      );
      await goals.addContribution(
        goalId: g,
        amountMinor: 10000,
        date: DateTime(2026, 10, 2),
      );
      await RecurringRepository(source).add(
        type: 'expense',
        amountMinor: 40000,
        currency: 'USD',
        categoryId: 'cat_housing',
        note: 'Rent',
        frequency: 'monthly',
        startOn: DateTime(2026, 11, 1),
      );
    }

    test('a backup restores into an empty database', () async {
      await fill(db);
      final service = BackupService(db, SettingsService(db));
      final json = await service.buildBackupJson();

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final restoreService = BackupService(other, SettingsService(other));
      await restoreService.restoreFromJson(json);

      final tx = await TransactionRepository(
        other,
      ).watchRange(DateTime(2026, 10), DateTime(2026, 11)).first;
      expect(tx, hasLength(2));
      expect(tx.map((e) => e.tx.note), contains('coffee, "large"'));

      final plan = await PlanRepository(other).watchActive().first;
      expect(plan!.items, hasLength(12));

      final goals = await GoalRepository(other).watchGoals().first;
      expect(goals.single.goal.name, 'Phone');
      expect(goals.single.goal.targetDate, DateTime(2026, 12, 31));
      expect(goals.single.savedMinor, 10000);

      expect(await RecurringRepository(other).watchAll().first, hasLength(1));
    });

    test('restoring replaces what was there', () async {
      await fill(db);
      final json = await BackupService(
        db,
        SettingsService(db),
      ).buildBackupJson();

      final tx = TransactionRepository(db);
      await tx.add(
        type: 'expense',
        amountMinor: 999,
        currency: 'USD',
        categoryId: 'cat_fun',
        note: 'extra',
        date: DateTime(2026, 10, 10),
      );
      await BackupService(db, SettingsService(db)).restoreFromJson(json);

      final list = await tx
          .watchRange(DateTime(2026, 10), DateTime(2026, 11))
          .first;
      expect(list, hasLength(2));
      expect(list.any((e) => e.tx.note == 'extra'), isFalse);
    });

    test('everything restored is queued for sync', () async {
      await fill(db);
      final json = await BackupService(
        db,
        SettingsService(db),
      ).buildBackupJson();
      await BackupService(db, SettingsService(db)).restoreFromJson(json);
      final queue = await db.select(db.outbox).get();
      expect(queue.where((q) => q.targetTable == 'transactions'), hasLength(2));
      expect(queue.where((q) => q.targetTable == 'goals'), hasLength(1));
    });

    test(
      'files that are not backups are rejected and change nothing',
      () async {
        await fill(db);
        final service = BackupService(db, SettingsService(db));
        for (final bad in [
          'not json at all',
          '[]',
          jsonEncode({'app': 'other', 'version': 1, 'tables': {}}),
          jsonEncode({'app': 'thavika', 'version': 99, 'tables': {}}),
          jsonEncode({'app': 'thavika', 'version': 1}),
          jsonEncode({
            'app': 'thavika',
            'version': 1,
            'tables': {'transactions': 'oops'},
          }),
        ]) {
          await expectLater(
            service.restoreFromJson(bad),
            throwsA(isA<BackupException>()),
            reason: bad,
          );
        }
        final all = await db.select(db.transactions).get();
        expect(all, hasLength(2));
      },
    );
  });

  group('csv', () {
    test('has a header, quotes cells and respects the range', () async {
      final tx = TransactionRepository(db);
      await tx.add(
        type: 'expense',
        amountMinor: 450,
        currency: 'USD',
        categoryId: 'cat_food',
        note: 'coffee, "large"',
        date: DateTime(2026, 10, 9),
      );
      await tx.add(
        type: 'expense',
        amountMinor: 1000,
        currency: 'USD',
        categoryId: 'cat_bills',
        note: '',
        date: DateTime(2026, 9, 9),
      );
      final service = BackupService(db, SettingsService(db));

      final all = (await service.buildCsv())!.trim().split('\n');
      expect(all.first, 'date,type,category,amount,currency,wallet,tags,note');
      expect(all, hasLength(3));
      expect(all[1], '2026-09-09,expense,Bills,10.00,USD,Cash,,');
      expect(
        all[2],
        '2026-10-09,expense,Food,4.50,USD,Cash,,"coffee, ""large"""',
      );

      final october = await service.buildCsv(
        from: DateTime(2026, 10),
        to: DateTime(2026, 11),
      );
      expect(october!.trim().split('\n'), hasLength(2));

      expect(
        await service.buildCsv(from: DateTime(2027), to: DateTime(2027, 2)),
        isNull,
      );
    });
  });
}
