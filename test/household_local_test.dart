import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/household/data/household_local.dart';
import 'package:thavika/features/household/domain/household.dart';
import 'package:thavika/features/tags/data/tag_repository.dart';

const me = 'user-me';
const partner = 'user-partner';
const hid = 'household-1';

void main() {
  late AppDatabase db;
  late HouseholdLocal local;
  final day = DateTime(2026, 10, 15);
  final stamp = DateTime(2026, 10, 20, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    local = HouseholdLocal(db);

    // A household's worth of data, as it looks on a phone after syncing.
    Future<void> category(String id, String name) => db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            icon: 'pets',
            kind: 'expense',
            ownerId: const Value(partner),
            householdId: const Value(hid),
            updatedAt: stamp,
          ),
        );
    await category('cat-pets', 'Pets');

    await db.delete(db.wallets).go();
    Future<void> wallet(String id, String owner, int opening) => db
        .into(db.wallets)
        .insert(
          WalletsCompanion.insert(
            id: id,
            name: 'wallet $id',
            currency: 'USD',
            openingMinor: Value(opening),
            ownerId: Value(owner),
            householdId: const Value(hid),
            updatedAt: stamp,
          ),
        );
    await wallet('w-mine', me, 5000);
    await wallet('w-partner', partner, 9000);

    Future<void> tx(
      String id,
      String owner,
      int amount, {
      String category = 'cat_food',
      String? walletId,
      String? split,
    }) => db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: id,
            type: 'expense',
            amountMinor: amount,
            currency: 'USD',
            categoryId: category,
            occurredOn: day,
            walletId: Value(walletId),
            splitGroup: Value(split),
            ownerId: Value(owner),
            householdId: const Value(hid),
            updatedAt: stamp,
          ),
        );
    await tx('t-mine-1', me, 100, walletId: 'w-mine');
    await tx(
      't-mine-2',
      me,
      200,
      category: 'cat-pets',
      walletId: 'w-partner',
      split: 'split-a',
    );
    await tx('t-mine-3', me, 300, split: 'split-a');
    await tx('t-partner-1', partner, 900, walletId: 'w-partner');

    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'tag-trip',
            name: 'trip',
            ownerId: const Value(partner),
            householdId: const Value(hid),
            updatedAt: stamp,
          ),
        );
    await db
        .into(db.transactionTags)
        .insert(
          TransactionTagsCompanion.insert(
            id: 'link-1',
            transactionId: 't-mine-1',
            tagId: 'tag-trip',
            ownerId: const Value(me),
            householdId: const Value(hid),
            updatedAt: stamp,
          ),
        );

    await db
        .into(db.plans)
        .insert(
          PlansCompanion.insert(
            id: 'plan-h',
            template: 'balanced',
            incomeMinor: 400000,
            currency: 'USD',
            name: const Value('Our plan'),
            activeFrom: Value(DateTime(2026, 10)),
            ownerId: const Value(partner),
            householdId: const Value(hid),
            updatedAt: stamp,
          ),
        );
    await db
        .into(db.planItems)
        .insert(
          PlanItemsCompanion.insert(
            id: 'item-pets',
            planId: 'plan-h',
            groupName: 'wants',
            name: 'Pets',
            categoryId: const Value('cat-pets'),
            amountMinor: 5000,
            ownerId: const Value(partner),
            householdId: const Value(hid),
            updatedAt: stamp,
          ),
        );

    // Uploads still waiting for household rows.
    await db.enqueue('transactions', 't-mine-1', 'upsert');
    await db.enqueue('transactions', 't-partner-1', 'upsert');
  });

  tearDown(() => db.close());

  Future<List<TxRow>> personalTx() =>
      (db.select(db.transactions)..where((t) => t.householdId.isNull())).get();

  test('leaving keeps a personal copy of what I added, and the plan', () async {
    await local.detach(me, copyMine: true, currency: 'USD', now: stamp);

    // The household's rows are gone from this phone.
    for (final id in ['t-mine-1', 't-mine-2', 't-mine-3', 't-partner-1']) {
      expect(
        await (db.select(db.transactions)..where((t) => t.id.equals(id))).get(),
        isEmpty,
        reason: id,
      );
    }
    expect(
      await (db.select(
        db.transactions,
      )..where((t) => t.householdId.isNotNull())).get(),
      isEmpty,
    );

    // Copies of my three entries, not the partner's.
    final copies = await personalTx();
    expect(copies.map((t) => t.amountMinor).toList()..sort(), [100, 200, 300]);
    for (final c in copies) {
      expect(c.ownerId, me);
      expect(c.householdId, isNull);
      expect(c.syncState, 'pending');
      expect(c.id, isNot(startsWith('t-')));
    }

    // Each copy is queued for upload; the purged rows are not.
    final queued = await db.select(db.outbox).get();
    final queuedIds = {
      for (final o in queued)
        if (o.targetTable == 'transactions') o.rowId,
    };
    expect(queuedIds, {for (final c in copies) c.id});
    expect(queuedIds, isNot(contains('t-partner-1')));
  });

  test(
    'the copies keep their category, wallet, tag and split together',
    () async {
      await local.detach(me, copyMine: true, currency: 'USD', now: stamp);
      final copies = {for (final t in await personalTx()) t.amountMinor: t};

      // A household category became a personal one with the same name.
      final petsCopy = await (db.select(
        db.categories,
      )..where((c) => c.id.equals(copies[200]!.categoryId))).getSingle();
      expect(petsCopy.name, 'Pets');
      expect(petsCopy.householdId, isNull);
      expect(petsCopy.ownerId, me);
      // Built-in categories are shared by every phone and stay as they are.
      expect(copies[100]!.categoryId, 'cat_food');

      // Wallets: mine keeps its opening balance, the partner's starts at zero
      // so the same money is not counted twice.
      Future<WalletRow> walletOf(TxRow t) => (db.select(
        db.wallets,
      )..where((w) => w.id.equals(t.walletId!))).getSingle();
      expect((await walletOf(copies[100]!)).openingMinor, 5000);
      expect((await walletOf(copies[200]!)).openingMinor, 0);
      expect((await walletOf(copies[100]!)).householdId, isNull);

      // The tag and its link followed the entry.
      final links = await db.select(db.transactionTags).get();
      expect(links, hasLength(1));
      expect(links.single.transactionId, copies[100]!.id);
      final tag = await (db.select(
        db.tags,
      )..where((t) => t.id.equals(links.single.tagId))).getSingle();
      expect(tag.name, 'trip');
      expect(tag.householdId, isNull);
      expect(links.single.id, TagRepository.linkId(copies[100]!.id, tag.id));

      // The two halves of a split are still one split, under a new name.
      expect(copies[200]!.splitGroup, isNotNull);
      expect(copies[200]!.splitGroup, copies[300]!.splitGroup);
      expect(copies[200]!.splitGroup, isNot('split-a'));
      expect(copies[100]!.splitGroup, isNull);
    },
  );

  test('the plan in use becomes a personal plan with its lines', () async {
    await local.detach(me, copyMine: true, currency: 'USD', now: stamp);

    final plans = await db.select(db.plans).get();
    expect(plans, hasLength(1));
    final plan = plans.single;
    expect(plan.id, isNot('plan-h'));
    expect(plan.name, 'Our plan');
    expect(plan.incomeMinor, 400000);
    expect(plan.activeFrom, DateTime(2026, 10));
    expect(plan.ownerId, me);
    expect(plan.householdId, isNull);

    final items = await db.select(db.planItems).get();
    expect(items, hasLength(1));
    expect(items.single.planId, plan.id);
    expect(items.single.amountMinor, 5000);
    // Its budget points at the personal copy of the category.
    final cat = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(items.single.categoryId!))).getSingle();
    expect(cat.name, 'Pets');
    expect(cat.householdId, isNull);

    final queued = {
      for (final o in await db.select(db.outbox).get())
        '${o.targetTable}/${o.rowId}',
    };
    expect(queued, contains('plans/${plan.id}'));
    expect(queued, contains('plan_items/${items.single.id}'));
  });

  test(
    'leaving with nothing to take leaves a clean phone with one wallet',
    () async {
      await local.detach(me, copyMine: false, currency: 'USD', now: stamp);

      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.plans).get(), isEmpty);
      expect(await db.select(db.tags).get(), isEmpty);
      expect(await db.select(db.outbox).get(), isEmpty);
      final wallets = await db.select(db.wallets).get();
      expect(wallets, hasLength(1));
      expect(wallets.single.householdId, isNull);
      // Built-in categories are still there.
      final cats = await db.select(db.categories).get();
      expect(cats.any((c) => c.id == 'cat_food'), isTrue);
      expect(cats.any((c) => c.id == 'cat-pets'), isFalse);
    },
  );

  test('when the household ended, everything becomes mine', () async {
    await local.becomePersonal(me);

    final all = await db.select(db.transactions).get();
    expect(all, hasLength(4));
    for (final t in all) {
      expect(t.ownerId, me);
      expect(t.householdId, isNull);
    }
    expect(
      (await db.select(db.wallets).get()).every((w) => w.householdId == null),
      isTrue,
    );
    expect((await db.select(db.plans).get()).single.ownerId, me);
  });

  test('the household is remembered for offline use', () async {
    expect(await local.cached(), isNull);
    await local.saveCache(
      const HouseholdInfo(
        id: hid,
        name: 'Home',
        ownerId: me,
        members: [
          HouseholdMember(userId: me, role: 'owner', displayName: 'Me'),
          HouseholdMember(userId: partner, role: 'member'),
        ],
      ),
    );
    final back = await local.cached();
    expect(back!.name, 'Home');
    expect(back.members, hasLength(2));
    expect(back.nameOf(me), 'Me');
    expect(back.nameOf(partner), isNull);
    expect(back.isOwner(me), isTrue);
    expect(back.hasOthers, isTrue);

    await local.clearCache();
    expect(await local.cached(), isNull);
  });
}
