import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/plan/data/plan_repository.dart';
import 'package:thavika/features/plan/domain/plan_templates.dart';

void main() {
  late AppDatabase db;
  late PlanRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PlanRepository(db);
  });

  tearDown(() => db.close());

  test('there is no plan at first', () async {
    expect(await repo.watchActive().first, isNull);
  });

  test('saving a plan stores its lines and queues them for sync', () async {
    await repo.savePlan(
      template: 'balanced',
      incomeMinor: 200000,
      currency: 'USD',
      items: PlanTemplates.balanced.build(200000, 'USD'),
    );

    final active = await repo.watchActive().first;
    expect(active, isNotNull);
    expect(active!.plan.incomeMinor, 200000);
    expect(active.plan.template, 'balanced');
    expect(active.items, hasLength(12));
    expect(active.items.fold<int>(0, (s, i) => s + i.amountMinor), 200000);
    expect(active.items.first.sortOrder, 0);

    final queue = await db.select(db.outbox).get();
    // One plan and twelve lines.
    expect(queue.where((q) => q.targetTable == 'plans'), hasLength(1));
    expect(queue.where((q) => q.targetTable == 'plan_items'), hasLength(12));
  });

  test('a new plan replaces the old one', () async {
    await repo.savePlan(
      template: 'balanced',
      incomeMinor: 200000,
      currency: 'USD',
      items: PlanTemplates.balanced.build(200000, 'USD'),
    );
    final first = (await repo.watchActive().first)!;

    await repo.savePlan(
      template: 'eighty',
      incomeMinor: 300000,
      currency: 'USD',
      items: PlanTemplates.eighty.build(300000, 'USD'),
    );
    final second = (await repo.watchActive().first)!;

    expect(second.plan.id, isNot(first.plan.id));
    expect(second.plan.template, 'eighty');
    expect(second.items, hasLength(12));

    // The old plan is kept as a soft-deleted row so the change can sync.
    final all = await db.select(db.plans).get();
    expect(all, hasLength(2));
    final old = all.firstWhere((p) => p.id == first.plan.id);
    expect(old.deletedAt, isNotNull);
    expect(old.isActive, isFalse);
  });

  test('custom lines without a category are kept', () async {
    await repo.savePlan(
      template: 'custom',
      incomeMinor: 100000,
      currency: 'USD',
      items: [
        PlanItemDraft(group: 'savings', name: 'Car fund', amountMinor: 10000),
      ],
    );
    final active = (await repo.watchActive().first)!;
    expect(active.items.single.name, 'Car fund');
    expect(active.items.single.categoryId, isNull);
  });
}
