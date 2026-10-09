import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/core/services/settings_service.dart';
import 'package:thavika/features/plan/data/plan_repository.dart';
import 'package:thavika/features/plan/domain/plan_templates.dart';
import 'package:thavika/features/recurring/data/recurring_repository.dart';
import 'package:thavika/features/settings/application/backup_service.dart';
import 'package:thavika/features/tags/data/tag_repository.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';
import 'package:thavika/features/wallets/data/transfer_repository.dart';
import 'package:thavika/features/wallets/data/wallet_repository.dart';

void main() {
  a2Tests();
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('upgrade from version 3', () {
    test('keeps old data and moves it into one Cash wallet', () async {
      final schema = File(
        'test/fixtures/schema_v3.sql',
      ).readAsStringSync().split(';\n').where((s) => s.trim().isNotEmpty);
      final executor = NativeDatabase.memory(
        setup: (raw) {
          for (final statement in schema) {
            raw.execute(statement);
          }
          raw.execute("INSERT INTO app_settings VALUES ('currency', 'KHR')");
          raw.execute(
            "INSERT INTO categories (id, name, icon, kind, updated_at) "
            "VALUES ('cat_food', 'Food', 'restaurant', 'expense', 1)",
          );
          raw.execute(
            "INSERT INTO transactions (id, type, amount_minor, currency, "
            "category_id, note, occurred_on, updated_at) "
            "VALUES ('t1', 'expense', 4000, 'KHR', 'cat_food', 'rice', 1760000000, 1760000000)",
          );
          raw.execute(
            "INSERT INTO plans (id, template, income_minor, currency, updated_at) "
            "VALUES ('p1', 'balanced', 2000000, 'KHR', 1760000000)",
          );
          raw.execute(
            "INSERT INTO recurring_rules (id, type, amount_minor, currency, "
            "category_id, frequency, start_on, next_run_on, updated_at) "
            "VALUES ('r1', 'expense', 100, 'KHR', 'cat_food', 'monthly', 1760000000, 1760000000, 1760000000)",
          );
          raw.execute('PRAGMA user_version = 3');
        },
      );
      final upgraded = AppDatabase(executor);
      addTearDown(upgraded.close);

      final wallets = await upgraded.select(upgraded.wallets).get();
      expect(wallets, hasLength(1));
      expect(wallets.single.name, 'Cash');
      expect(wallets.single.currency, 'KHR'); // the saved currency is used

      final tx = await upgraded.select(upgraded.transactions).getSingle();
      expect(tx.note, 'rice');
      expect(tx.walletId, wallets.single.id);

      final rule = await upgraded.select(upgraded.recurringRules).getSingle();
      expect(rule.walletId, wallets.single.id);
      expect(rule.isBill, isFalse);
      expect(rule.autoCreate, isTrue);
      expect(rule.remindDaysBefore, 2);

      final plan = await upgraded.select(upgraded.plans).getSingle();
      expect(plan.activeFrom, isNotNull);
      final now = DateTime.now();
      expect(plan.activeFrom, DateTime(now.year, now.month));

      // The new tables work.
      final tags = TagRepository(upgraded);
      final tagId = await tags.add('trip');
      await tags.setTags('t1', {tagId});
      expect((await tags.watchLinks().first)['t1'], [tagId]);
    });
  });

  group('wallets', () {
    test('a new database has one wallet to start with', () async {
      expect(await db.select(db.wallets).get(), hasLength(1));
      expect(await db.defaultWalletId(), isNotNull);
    });

    test('balance = opening + income - spending +/- transfers', () async {
      final wallets = WalletRepository(db);
      final cash = (await db.select(db.wallets).getSingle()).id;
      final bank = await wallets.add(
        name: 'Bank',
        currency: 'USD',
        kind: 'bank',
        openingMinor: 100000,
      );
      final tx = TransactionRepository(db);
      Future<void> add(String type, int amount, String wallet) => tx.add(
        type: type,
        amountMinor: amount,
        currency: 'USD',
        categoryId: 'cat_food',
        note: '',
        date: DateTime(2026, 10, 9),
        walletId: wallet,
      );
      await add('income', 20000, cash);
      await add('expense', 3000, cash);
      await add('expense', 500, bank);
      await TransferRepository(db).add(
        fromWalletId: cash,
        toWalletId: bank,
        amountMinor: 5000,
        currency: 'USD',
        date: DateTime(2026, 10, 9),
      );

      final balances = await wallets.watchBalances().first;
      expect(balances[cash], 20000 - 3000 - 5000);
      expect(balances[bank], 100000 - 500 + 5000);
    });

    test('money moved into a goal leaves the wallet', () async {
      final cash = (await db.select(db.wallets).getSingle()).id;
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'g1',
              name: 'Phone',
              targetMinor: 50000,
              currency: 'USD',
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.goalContributions)
          .insert(
            GoalContributionsCompanion.insert(
              id: 'c1',
              goalId: 'g1',
              amountMinor: 1200,
              occurredOn: DateTime(2026, 10, 9),
              walletId: Value(cash),
              updatedAt: DateTime.now(),
            ),
          );
      final balances = await WalletRepository(db).watchBalances().first;
      expect(balances[cash], -1200);
    });

    test('deleted entries and transfers do not count', () async {
      final wallets = WalletRepository(db);
      final cash = (await db.select(db.wallets).getSingle()).id;
      final tx = TransactionRepository(db);
      final id = await tx.add(
        type: 'expense',
        amountMinor: 700,
        currency: 'USD',
        categoryId: 'cat_food',
        note: '',
        date: DateTime(2026, 10, 9),
      );
      expect((await wallets.watchBalances().first)[cash], -700);
      await tx.softDelete(id);
      expect((await wallets.watchBalances().first)[cash], 0);
    });

    test(
      'deleting a wallet moves its entries and drops pointless transfers',
      () async {
        final wallets = WalletRepository(db);
        final cash = (await db.select(db.wallets).getSingle()).id;
        final bank = await wallets.add(name: 'Bank', currency: 'USD');
        final tx = TransactionRepository(db);
        await tx.add(
          type: 'expense',
          amountMinor: 900,
          currency: 'USD',
          categoryId: 'cat_food',
          note: '',
          date: DateTime(2026, 10, 9),
          walletId: bank,
        );
        final transfers = TransferRepository(db);
        await transfers.add(
          fromWalletId: cash,
          toWalletId: bank,
          amountMinor: 100,
          currency: 'USD',
          date: DateTime(2026, 10, 9),
        );

        await wallets.delete(bank, moveTo: cash);

        final list = await wallets.watchAll().first;
        expect(list.map((w) => w.id), [cash]);
        final entries = await db.select(db.transactions).get();
        expect(entries.single.walletId, cash);
        // The cash -> bank transfer became cash -> cash, so it is gone.
        final moves = await transfers
            .watchRange(DateTime(2026, 10), DateTime(2026, 11))
            .first;
        expect(moves, isEmpty);
        expect((await wallets.watchBalances().first)[cash], -900);
      },
    );

    test('cannot delete a wallet into itself or transfer to itself', () async {
      final cash = (await db.select(db.wallets).getSingle()).id;
      expect(
        () => WalletRepository(db).delete(cash, moveTo: cash),
        throwsArgumentError,
      );
      expect(
        () => TransferRepository(db).add(
          fromWalletId: cash,
          toWalletId: cash,
          amountMinor: 1,
          currency: 'USD',
          date: DateTime(2026, 10, 9),
        ),
        throwsArgumentError,
      );
    });

    test('changing the currency updates the wallets', () async {
      final settings = SettingsService(db);
      await settings.setCurrency('KHR');
      final w = await db.select(db.wallets).getSingle();
      expect(w.currency, 'KHR');
    });
  });

  group('tags', () {
    test('setTags adds, removes and revives links', () async {
      final tx = TransactionRepository(db);
      final tags = TagRepository(db);
      final entry = await tx.add(
        type: 'expense',
        amountMinor: 100,
        currency: 'USD',
        categoryId: 'cat_food',
        note: '',
        date: DateTime(2026, 10, 9),
      );
      final a = await tags.add('trip');
      final b = await tags.add('wedding');

      await tags.setTags(entry, {a, b});
      expect((await tags.watchLinks().first)[entry]!.toSet(), {a, b});

      await tags.setTags(entry, {b});
      expect((await tags.watchLinks().first)[entry], [b]);

      // Adding it back reuses the same link row.
      await tags.setTags(entry, {a, b});
      final links = await db.select(db.transactionTags).get();
      expect(links, hasLength(2));
      expect(links.map((l) => l.id).toSet(), {
        TagRepository.linkId(entry, a),
        TagRepository.linkId(entry, b),
      });
    });

    test('deleting a tag removes it from entries', () async {
      final tx = TransactionRepository(db);
      final tags = TagRepository(db);
      final tag = await tags.add('trip');
      final entry = await tx.add(
        type: 'expense',
        amountMinor: 100,
        currency: 'USD',
        categoryId: 'cat_food',
        note: '',
        date: DateTime(2026, 10, 9),
        tagIds: {tag},
      );
      expect((await tags.watchLinks().first)[entry], [tag]);
      await tags.delete(tag);
      expect(await tags.watchAll().first, isEmpty);
      expect((await tags.watchLinks().first)[entry], isNull);
    });
  });

  group('plan history', () {
    test('a later plan does not change an earlier month', () async {
      final plans = PlanRepository(db);
      await plans.savePlan(
        template: 'balanced',
        incomeMinor: 200000,
        currency: 'USD',
        items: PlanTemplates.balanced.build(200000, 'USD'),
        month: DateTime(2026, 8),
      );
      await plans.savePlan(
        template: 'eighty',
        incomeMinor: 300000,
        currency: 'USD',
        items: PlanTemplates.eighty.build(300000, 'USD'),
        month: DateTime(2026, 10),
      );

      expect(await plans.watchForMonth(DateTime(2026, 7)).first, isNull);
      expect(
        (await plans.watchForMonth(DateTime(2026, 8, 20)).first)!.plan.template,
        'balanced',
      );
      expect(
        (await plans.watchForMonth(DateTime(2026, 9)).first)!.plan.template,
        'balanced',
      );
      expect(
        (await plans.watchForMonth(DateTime(2026, 10)).first)!.plan.template,
        'eighty',
      );
      expect(
        (await plans.watchForMonth(DateTime(2027, 3)).first)!.plan.template,
        'eighty',
      );
    });

    test('saving again in the same month replaces that month only', () async {
      final plans = PlanRepository(db);
      await plans.savePlan(
        template: 'balanced',
        incomeMinor: 200000,
        currency: 'USD',
        items: PlanTemplates.balanced.build(200000, 'USD'),
        month: DateTime(2026, 8),
      );
      await plans.savePlan(
        template: 'seventy',
        incomeMinor: 200000,
        currency: 'USD',
        items: PlanTemplates.seventy.build(200000, 'USD'),
        month: DateTime(2026, 10),
      );
      await plans.savePlan(
        template: 'eighty',
        incomeMinor: 250000,
        currency: 'USD',
        items: PlanTemplates.eighty.build(250000, 'USD'),
        month: DateTime(2026, 10),
        name: 'Tight month',
      );
      final october = (await plans.watchForMonth(DateTime(2026, 10)).first)!;
      expect(october.plan.template, 'eighty');
      expect(october.plan.name, 'Tight month');
      expect(
        (await plans.watchForMonth(DateTime(2026, 9)).first)!.plan.template,
        'balanced',
      );
    });
  });

  group('recurring and entries', () {
    test(
      'recurring entries go to the rule wallet or the default one',
      () async {
        final wallets = WalletRepository(db);
        final cash = (await db.select(db.wallets).getSingle()).id;
        final bank = await wallets.add(name: 'Bank', currency: 'USD');
        final rules = RecurringRepository(db);
        await rules.add(
          type: 'expense',
          amountMinor: 100,
          currency: 'USD',
          categoryId: 'cat_bills',
          note: 'A',
          frequency: 'monthly',
          startOn: DateTime(2026, 10, 1),
        );
        await db
            .into(db.recurringRules)
            .insert(
              RecurringRulesCompanion.insert(
                id: 'rule-bank',
                type: 'expense',
                amountMinor: 200,
                currency: 'USD',
                categoryId: 'cat_bills',
                note: const Value('B'),
                frequency: 'monthly',
                startOn: DateTime(2026, 10, 1),
                nextRunOn: DateTime(2026, 10, 1),
                walletId: Value(bank),
                updatedAt: DateTime.now(),
              ),
            );
        await rules.generateDue(DateTime(2026, 10, 9));
        final list = await db.select(db.transactions).get();
        expect(list.firstWhere((t) => t.note == 'A').walletId, cash);
        expect(list.firstWhere((t) => t.note == 'B').walletId, bank);
      },
    );

    test('update keeps the wallet and receipt unless they are given', () async {
      final tx = TransactionRepository(db);
      final bank = await WalletRepository(
        db,
      ).add(name: 'Bank', currency: 'USD');
      final id = await tx.add(
        type: 'expense',
        amountMinor: 100,
        currency: 'USD',
        categoryId: 'cat_food',
        note: '',
        date: DateTime(2026, 10, 9),
        walletId: bank,
        receiptPath: 'r1.jpg',
      );
      await tx.update(
        id,
        type: 'expense',
        amountMinor: 250,
        currency: 'USD',
        categoryId: 'cat_food',
        note: 'x',
        date: DateTime(2026, 10, 9),
      );
      var row = await db.select(db.transactions).getSingle();
      expect(row.walletId, bank);
      expect(row.receiptPath, 'r1.jpg');
      expect(row.amountMinor, 250);

      await tx.update(
        id,
        type: 'expense',
        amountMinor: 250,
        currency: 'USD',
        categoryId: 'cat_food',
        note: 'x',
        date: DateTime(2026, 10, 9),
        receiptPath: const Value(null),
      );
      row = await db.select(db.transactions).getSingle();
      expect(row.receiptPath, isNull);
    });

    test('split entries share a group', () async {
      final tx = TransactionRepository(db);
      for (final cat in ['cat_food', 'cat_health']) {
        await tx.add(
          type: 'expense',
          amountMinor: 500,
          currency: 'USD',
          categoryId: cat,
          note: 'market',
          date: DateTime(2026, 10, 9),
          splitGroup: 'split-1',
        );
      }
      final rows = await db.select(db.transactions).get();
      expect(rows.map((r) => r.splitGroup).toSet(), {'split-1'});
    });
  });

  group('backup version 2', () {
    test('round trips wallets, transfers, tags and the new columns', () async {
      final wallets = WalletRepository(db);
      final cash = (await db.select(db.wallets).getSingle()).id;
      final bank = await wallets.add(
        name: 'ABA',
        currency: 'USD',
        kind: 'bank',
        openingMinor: 5000,
      );
      final tags = TagRepository(db);
      final tag = await tags.add('trip');
      final tx = TransactionRepository(db);
      await tx.add(
        type: 'expense',
        amountMinor: 450,
        currency: 'USD',
        categoryId: 'cat_food',
        note: 'coffee',
        date: DateTime(2026, 10, 9),
        walletId: bank,
        receiptPath: 'r.jpg',
        splitGroup: 's1',
        tagIds: {tag},
      );
      await TransferRepository(db).add(
        fromWalletId: cash,
        toWalletId: bank,
        amountMinor: 300,
        currency: 'USD',
        date: DateTime(2026, 10, 9),
      );
      await db
          .into(db.debts)
          .insert(
            DebtsCompanion.insert(
              id: 'd1',
              person: 'Sokha',
              direction: 'lent',
              amountMinor: 2000,
              currency: 'USD',
              startedOn: DateTime(2026, 10, 1),
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.challenges)
          .insert(
            ChallengesCompanion.insert(
              id: 'ch1',
              goalId: 'g1',
              kind: 'weekly',
              unitMinor: 100,
              steps: 52,
              startOn: DateTime(2026, 10, 1),
              completedSteps: const Value('1,2'),
              updatedAt: DateTime.now(),
            ),
          );

      final json = await BackupService(
        db,
        SettingsService(db),
      ).buildBackupJson();
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other, SettingsService(other)).restoreFromJson(json);

      final names = (await other.select(other.wallets).get())
          .map((w) => w.name)
          .toSet();
      expect(names, {'Cash', 'ABA'});
      final entry = await other.select(other.transactions).getSingle();
      expect(entry.walletId, bank);
      expect(entry.receiptPath, 'r.jpg');
      expect(entry.splitGroup, 's1');
      expect((await TagRepository(other).watchLinks().first)[entry.id], [tag]);
      expect(await other.select(other.transfers).get(), hasLength(1));
      expect((await other.select(other.debts).getSingle()).person, 'Sokha');
      expect(
        (await other.select(other.challenges).getSingle()).completedSteps,
        '1,2',
      );
      final balances = await WalletRepository(other).watchBalances().first;
      expect(balances[bank], 5000 - 450 + 300);
    });

    test('a version 1 backup is accepted and gets a Cash wallet', () async {
      final old = jsonEncode({
        'app': 'thavika',
        'version': 1,
        'currency': 'KHR',
        'tables': {
          'categories': <Object>[],
          'transactions': [
            {
              'id': 't1',
              'type': 'expense',
              'amountMinor': 4000,
              'currency': 'KHR',
              'categoryId': 'cat_food',
              'note': 'rice',
              'occurredOn': DateTime(2026, 10, 9).millisecondsSinceEpoch,
              'createdBy': null,
              'ownerId': null,
              'householdId': null,
              'updatedAt': DateTime(2026, 10, 9).millisecondsSinceEpoch,
              'deletedAt': null,
              'syncState': 'pending',
            },
          ],
        },
      });
      await BackupService(db, SettingsService(db)).restoreFromJson(old);
      final wallets = await db.select(db.wallets).get();
      expect(wallets, hasLength(1));
      expect(wallets.single.currency, 'KHR');
      final entry = await db.select(db.transactions).getSingle();
      expect(entry.walletId, wallets.single.id);
    });

    test('the csv has wallet and tags', () async {
      final tag = await TagRepository(db).add('trip');
      await TransactionRepository(db).add(
        type: 'expense',
        amountMinor: 450,
        currency: 'USD',
        categoryId: 'cat_food',
        note: 'coffee',
        date: DateTime(2026, 10, 9),
        tagIds: {tag},
      );
      final csv = (await BackupService(db, SettingsService(db)).buildCsv())!;
      final lines = csv.trim().split('\n');
      expect(
        lines.first,
        'date,type,category,amount,currency,wallet,tags,note',
      );
      expect(lines[1], '2026-10-09,expense,Food,4.50,USD,Cash,trip,coffee');
    });
  });
}

void a2Tests() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> add(
    TransactionRepository tx,
    String note,
    String category, {
    int amount = 250,
    String type = 'expense',
    DateTime? date,
  }) => tx.add(
    type: type,
    amountMinor: amount,
    currency: 'USD',
    categoryId: category,
    note: note,
    date: date ?? DateTime(2026, 10, 9),
  );

  group('note suggestions', () {
    test('most used first, matching the start of the note', () async {
      final tx = TransactionRepository(db);
      await add(tx, 'coffee', 'cat_food');
      await add(tx, 'Coffee', 'cat_food');
      await add(tx, 'coffee beans', 'cat_food');
      await add(tx, 'cola', 'cat_food');
      await add(tx, 'bus', 'cat_transport');

      final co = await tx.suggestNotes(type: 'expense', prefix: 'co');
      expect(co.map((s) => s.note.toLowerCase()), [
        'coffee',
        'coffee beans',
        'cola',
      ]);
      expect(co.first.count, 2);

      final all = await tx.suggestNotes(type: 'expense');
      expect(all, hasLength(4));
    });

    test('can be limited to a category and a type', () async {
      final tx = TransactionRepository(db);
      await add(tx, 'grab', 'cat_transport');
      await add(tx, 'grab food', 'cat_food');
      await add(tx, 'pay', 'cat_salary', type: 'income');

      final transport = await tx.suggestNotes(
        type: 'expense',
        categoryId: 'cat_transport',
      );
      expect(transport.map((s) => s.note), ['grab']);
      expect(await tx.suggestNotes(type: 'income'), hasLength(1));
    });

    test('percent and underscore in the typed text are literal', () async {
      final tx = TransactionRepository(db);
      await add(tx, '100% juice', 'cat_food');
      await add(tx, '1000 notes', 'cat_food');
      final r = await tx.suggestNotes(type: 'expense', prefix: '100%');
      expect(r.map((s) => s.note), ['100% juice']);
    });

    test('deleted entries are not suggested', () async {
      final tx = TransactionRepository(db);
      final id = await add(tx, 'secret', 'cat_food');
      await tx.softDelete(id);
      expect(await tx.suggestNotes(type: 'expense'), isEmpty);
    });

    test('knownNotes gives the most used category', () async {
      final tx = TransactionRepository(db);
      await add(tx, 'grab', 'cat_transport');
      await add(tx, 'Grab', 'cat_transport');
      await add(tx, 'grab', 'cat_food');
      final known = await tx.knownNotes('expense');
      expect(known['grab'], 'cat_transport');
    });
  });

  group('repeat and duplicate', () {
    test('recentDistinct skips repeats and keeps newest first', () async {
      final tx = TransactionRepository(db);
      await add(tx, 'coffee', 'cat_food', date: DateTime(2026, 10, 1));
      await add(
        tx,
        'lunch',
        'cat_food',
        amount: 600,
        date: DateTime(2026, 10, 2),
      );
      await add(tx, 'coffee', 'cat_food', date: DateTime(2026, 10, 3));
      await add(
        tx,
        'bus',
        'cat_transport',
        amount: 100,
        date: DateTime(2026, 10, 4),
      );

      final recent = await tx.recentDistinct('expense');
      expect(recent.map((r) => r.note), ['bus', 'coffee', 'lunch']);
    });

    test('duplicate copies the entry to today with wallet and tags', () async {
      final tx = TransactionRepository(db);
      final tags = TagRepository(db);
      final bank = await WalletRepository(
        db,
      ).add(name: 'Bank', currency: 'USD');
      final tag = await tags.add('trip');
      final id = await tx.add(
        type: 'expense',
        amountMinor: 450,
        currency: 'USD',
        categoryId: 'cat_food',
        note: 'coffee',
        date: DateTime(2026, 9, 1),
        walletId: bank,
        receiptPath: 'r.jpg',
        splitGroup: 's',
        tagIds: {tag},
      );

      final copy = await tx.duplicate(id, date: DateTime(2026, 10, 9, 18, 30));
      expect(copy, isNot(id));
      final rows = await db.select(db.transactions).get();
      final row = rows.firstWhere((r) => r.id == copy);
      expect(row.amountMinor, 450);
      expect(row.note, 'coffee');
      expect(row.walletId, bank);
      expect(row.occurredOn, DateTime(2026, 10, 9));
      expect(row.receiptPath, isNull);
      expect(row.splitGroup, isNull);
      expect((await tags.watchLinks().first)[copy], [tag]);
      expect(rows, hasLength(2));
    });
  });
}
