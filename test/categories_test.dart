import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/entry/data/category_repository.dart';
import 'package:thavika/features/plan/data/plan_repository.dart';
import 'package:thavika/features/plan/domain/plan_templates.dart';
import 'package:thavika/features/recurring/data/recurring_repository.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CategoryRepository(db);
  });
  tearDown(() => db.close());

  Future<String> custom(String name, {String kind = 'expense'}) =>
      repo.add(name: name, icon: 'coffee', kind: kind);

  test('a custom category can be renamed and given another icon', () async {
    final id = await custom('Coffee');
    await repo.update(id, name: 'Cafe', icon: 'wifi');
    final row = (await repo.watchManage('expense').first).firstWhere(
      (c) => c.id == id,
    );
    expect(row.name, 'Cafe');
    expect(row.icon, 'wifi');
  });

  test('hidden categories leave the add list but stay in manage', () async {
    await repo.setHidden('cat_fun', true);
    expect(
      (await repo.watch('expense').first).map((c) => c.id),
      isNot(contains('cat_fun')),
    );
    final manage = await repo.watchManage('expense').first;
    expect(manage.firstWhere((c) => c.id == 'cat_fun').isHidden, isTrue);
    expect(
      (await repo.watchAllVisible().first).map((c) => c.id),
      isNot(contains('cat_fun')),
    );

    await repo.setHidden('cat_fun', false);
    expect(
      (await repo.watch('expense').first).map((c) => c.id),
      contains('cat_fun'),
    );
  });

  test(
    'hiding a built-in category is not queued for sync, a custom one is',
    () async {
      await repo.setHidden('cat_fun', true);
      expect(await db.select(db.outbox).get(), isEmpty);
      final id = await custom('Pets');
      await db.delete(db.outbox).go();
      await repo.setHidden(id, true);
      expect((await db.select(db.outbox).get()).single.rowId, id);
    },
  );

  test('isInUse looks at entries, recurring entries and plan lines', () async {
    final a = await custom('A');
    final b = await custom('B');
    final c = await custom('C');
    expect(await repo.isInUse(a), isFalse);

    await TransactionRepository(db).add(
      type: 'expense',
      amountMinor: 100,
      currency: 'USD',
      categoryId: a,
      note: '',
      date: DateTime(2026, 10, 9),
    );
    await RecurringRepository(db).add(
      type: 'expense',
      amountMinor: 100,
      currency: 'USD',
      categoryId: b,
      note: '',
      frequency: 'monthly',
      startOn: DateTime(2026, 11, 1),
    );
    await PlanRepository(db).savePlan(
      template: 'custom',
      incomeMinor: 100000,
      currency: 'USD',
      items: [
        PlanItemDraft(
          group: 'wants',
          name: 'C',
          categoryId: c,
          amountMinor: 100,
        ),
      ],
    );
    expect(await repo.isInUse(a), isTrue);
    expect(await repo.isInUse(b), isTrue);
    expect(await repo.isInUse(c), isTrue);
  });

  test('deleting moves entries, recurring entries and plan lines', () async {
    final pets = await custom('Pets');
    final tx = TransactionRepository(db);
    final entry = await tx.add(
      type: 'expense',
      amountMinor: 700,
      currency: 'USD',
      categoryId: pets,
      note: 'food for the cat',
      date: DateTime(2026, 10, 9),
    );
    await RecurringRepository(db).add(
      type: 'expense',
      amountMinor: 100,
      currency: 'USD',
      categoryId: pets,
      note: '',
      frequency: 'monthly',
      startOn: DateTime(2026, 11, 1),
    );
    await PlanRepository(db).savePlan(
      template: 'custom',
      incomeMinor: 100000,
      currency: 'USD',
      items: [
        PlanItemDraft(
          group: 'wants',
          name: 'Pets',
          categoryId: pets,
          amountMinor: 500,
        ),
      ],
    );

    await repo.delete(pets, moveTo: 'cat_personal');

    expect(
      (await db.select(db.transactions).get())
          .firstWhere((t) => t.id == entry)
          .categoryId,
      'cat_personal',
    );
    expect(
      (await db.select(db.recurringRules).getSingle()).categoryId,
      'cat_personal',
    );
    final line = await db.select(db.planItems).getSingle();
    expect(line.categoryId, 'cat_personal');
    expect(line.name, 'cat_personal'); // built-in target stores its key

    expect(
      (await repo.watchManage('expense').first).map((c) => c.id),
      isNot(contains(pets)),
    );
    expect(await repo.isInUse(pets), isFalse);
  });

  test('moving into a custom category uses its name on plan lines', () async {
    final a = await custom('Pets');
    final b = await custom('Garden');
    await PlanRepository(db).savePlan(
      template: 'custom',
      incomeMinor: 100000,
      currency: 'USD',
      items: [
        PlanItemDraft(
          group: 'wants',
          name: 'Pets',
          categoryId: a,
          amountMinor: 500,
        ),
      ],
    );
    await repo.delete(a, moveTo: b);
    final line = await db.select(db.planItems).getSingle();
    expect(line.categoryId, b);
    expect(line.name, 'Garden');
  });

  test('rules: not built-in, not itself, same kind only', () async {
    final a = await custom('A');
    final income = await custom('Tips', kind: 'income');
    expect(
      () => repo.delete('cat_food', moveTo: 'cat_fun'),
      throwsArgumentError,
    );
    expect(() => repo.delete(a, moveTo: a), throwsArgumentError);
    expect(() => repo.delete(a, moveTo: income), throwsArgumentError);
  });

  test('usage counts entries per category', () async {
    final tx = TransactionRepository(db);
    for (final cat in ['cat_food', 'cat_food', 'cat_bills']) {
      await tx.add(
        type: 'expense',
        amountMinor: 100,
        currency: 'USD',
        categoryId: cat,
        note: '',
        date: DateTime(2026, 10, 9),
      );
    }
    final usage = await repo.watchUsage().first;
    expect(usage['cat_food'], 2);
    expect(usage['cat_bills'], 1);
  });
}
