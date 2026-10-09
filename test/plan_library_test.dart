import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/plan/data/plan_repository.dart';
import 'package:thavika/features/plan/domain/plan_templates.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late PlanRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PlanRepository(db);
  });

  tearDown(() => db.close());

  Future<void> savePlan(String template, int income, {String? name}) =>
      repo.savePlan(
        template: template,
        incomeMinor: income,
        currency: 'USD',
        items: PlanTemplates.balanced.build(income, 'USD'),
        name: name,
      );

  test(
    'a plan can be saved by name without changing the active plan',
    () async {
      await savePlan('balanced', 200000);
      final active = (await repo.watchActive().first)!;

      await repo.saveToLibrary(active.plan.id, 'Family plan');

      final library = await repo.watchLibrary().first;
      expect(library, hasLength(1));
      expect(library.first.name, 'Family plan');
      expect(library.first.activeFrom, isNull);

      // The active plan is still the same one, and the copy is not "active".
      final again = (await repo.watchActive().first)!;
      expect(again.plan.id, active.plan.id);
    },
  );

  test('the copy has the same lines', () async {
    await savePlan('balanced', 200000);
    final active = (await repo.watchActive().first)!;
    final copyId = await repo.saveToLibrary(active.plan.id, 'Copy');
    final lines = await (db.select(
      db.planItems,
    )..where((i) => i.planId.equals(copyId))).get();
    expect(lines, hasLength(active.items.length));
    expect(
      lines.fold<int>(0, (s, i) => s + i.amountMinor),
      active.items.fold<int>(0, (s, i) => s + i.amountMinor),
    );
  });

  test(
    'applying a saved plan switches the active plan and keeps the saved one',
    () async {
      await savePlan('balanced', 200000, name: 'Normal');
      final first = (await repo.watchActive().first)!;
      await repo.saveToLibrary(first.plan.id, 'Normal');

      // Change the active plan to something else.
      await savePlan('balanced', 300000, name: 'Raise');
      expect((await repo.watchActive().first)!.plan.incomeMinor, 300000);

      final saved = (await repo.watchLibrary().first).single;
      await repo.applyFromLibrary(saved.id);

      final now = (await repo.watchActive().first)!;
      expect(now.plan.incomeMinor, 200000);
      expect(now.plan.name, 'Normal');
      expect(now.plan.id, isNot(saved.id));
      expect(await repo.watchLibrary().first, hasLength(1));
    },
  );

  test(
    'earlier months keep their plan when a saved plan is applied later',
    () async {
      final lastMonth = DateTime(DateTime.now().year, DateTime.now().month - 1);
      await repo.savePlan(
        template: 'balanced',
        incomeMinor: 100000,
        currency: 'USD',
        items: PlanTemplates.balanced.build(100000, 'USD'),
        month: lastMonth,
      );
      await savePlan('balanced', 200000);
      final active = (await repo.watchActive().first)!;
      final id = await repo.saveToLibrary(active.plan.id, 'X');
      await repo.applyFromLibrary(id);

      expect(
        (await repo.watchForMonth(lastMonth).first)!.plan.incomeMinor,
        100000,
      );
    },
  );

  test('deleting a saved plan removes it from the library only', () async {
    await savePlan('balanced', 200000);
    final active = (await repo.watchActive().first)!;
    final id = await repo.saveToLibrary(active.plan.id, 'Temp');
    await repo.deleteFromLibrary(id);
    expect(await repo.watchLibrary().first, isEmpty);
    expect(await repo.watchActive().first, isNotNull);
  });

  test('expenseByCategory sums only expenses in the range', () async {
    final tx = TransactionRepository(db);
    final d = DateTime(2026, 3, 10);
    await tx.add(
      type: 'expense',
      amountMinor: 1000,
      currency: 'USD',
      categoryId: 'cat_food',
      note: '',
      date: d,
    );
    await tx.add(
      type: 'expense',
      amountMinor: 500,
      currency: 'USD',
      categoryId: 'cat_food',
      note: '',
      date: d,
    );
    await tx.add(
      type: 'income',
      amountMinor: 9999,
      currency: 'USD',
      categoryId: 'cat_salary',
      note: '',
      date: d,
    );
    await tx.add(
      type: 'expense',
      amountMinor: 700,
      currency: 'USD',
      categoryId: 'cat_food',
      note: '',
      date: DateTime(2026, 4, 1),
    );
    final map = await tx.expenseByCategory(
      DateTime(2026, 3),
      DateTime(2026, 4),
    );
    expect(map, {'cat_food': 1500});
  });
}
