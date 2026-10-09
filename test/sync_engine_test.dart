import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/entry/data/category_repository.dart';
import 'package:thavika/features/goals/data/goal_repository.dart';
import 'package:thavika/features/sync/data/postgrest_client.dart';
import 'package:thavika/features/sync/data/sync_engine.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';
import 'package:thavika/features/wallets/data/wallet_repository.dart';

import 'support/fake_postgrest.dart';

/// One simulated phone.
class Phone {
  Phone(FakeServer server, {int pageSize = 500})
    : db = AppDatabase(NativeDatabase.memory()) {
    engine = SyncEngine(db, server.client(), pageSize: pageSize);
    tx = TransactionRepository(db);
  }

  final AppDatabase db;
  late final SyncEngine engine;
  late final TransactionRepository tx;

  Future<String> addExpense(int minor, {DateTime? on, String note = ''}) =>
      tx.add(
        type: 'expense',
        amountMinor: minor,
        currency: 'USD',
        categoryId: 'cat_food',
        note: note,
        date: on ?? DateTime(2026, 3, 9),
      );

  Future<List<TxRow>> entries() => (db.select(
    db.transactions,
  )..orderBy([(t) => OrderingTerm.asc(t.amountMinor)])).get();

  Future<int> outboxCount() async => (await db.select(db.outbox).get()).length;
}

void main() {
  late FakeServer server;
  late Phone a;

  setUp(() async {
    server = FakeServer();
    a = Phone(server);
    await a.engine.attach('user-1', currency: 'USD');
  });

  tearDown(() => a.db.close());

  group('push', () {
    test(
      'uploads a new entry, marks it synced and empties the queue',
      () async {
        final id = await a.addExpense(450, note: 'coffee');
        expect(await a.outboxCount(), greaterThan(0));

        final report = await a.engine.run();

        expect(report.failed, 0);
        final remote = server.rows('transactions').single;
        expect(remote['id'], id);
        expect(remote['amount_minor'], 450);
        expect(remote['owner_id'], 'user-1');
        expect(remote['occurred_on'], '2026-03-09');
        expect(remote['note'], 'coffee');
        expect(await a.outboxCount(), 0);
        final local = (await a.entries()).single;
        expect(local.syncState, 'synced');
        expect(local.ownerId, 'user-1');
      },
    );

    test('an edit and a delete reach the server', () async {
      final id = await a.addExpense(450);
      await a.engine.run();

      await a.tx.update(
        id,
        type: 'expense',
        currency: 'USD',
        amountMinor: 900,
        categoryId: 'cat_food',
        note: 'edited',
        date: DateTime(2026, 3, 9),
      );
      await a.engine.run();
      expect(server.rows('transactions').single['amount_minor'], 900);

      await a.tx.softDelete(id);
      await a.engine.run();
      expect(server.rows('transactions').single['deleted_at'], isNotNull);
    });

    test('several edits in a row send only the latest version once', () async {
      final id = await a.addExpense(100);
      for (var i = 2; i <= 5; i++) {
        await a.tx.update(
          id,
          type: 'expense',
          currency: 'USD',
          amountMinor: i * 100,
          categoryId: 'cat_food',
          note: '',
          date: DateTime(2026, 3, 9),
        );
      }
      await a.engine.run();
      expect(server.rows('transactions').single['amount_minor'], 500);
      expect(await a.outboxCount(), 0);
    });

    test('offline: nothing is lost and the queue is kept', () async {
      await a.addExpense(450);
      server.offline = true;
      await expectLater(
        a.engine.run(),
        throwsA(isA<RemoteFailure>().having((e) => e.offline, 'offline', true)),
      );
      expect(await a.outboxCount(), greaterThan(0));
      expect((await a.entries()).single.syncState, 'pending');

      server.offline = false;
      await a.engine.run();
      expect(server.rows('transactions'), hasLength(1));
      expect(await a.outboxCount(), 0);
    });

    test('built-in categories stay on the phone, custom ones go up', () async {
      final cats = CategoryRepository(a.db);
      await cats.add(kind: 'expense', name: 'Pets', icon: 'pets');
      await a.engine.run();
      final names = server.rows('categories').map((r) => r['name']).toList();
      expect(names, ['Pets']);
    });

    test(
      'a refused row is counted, kept queued and does not block the rest',
      () async {
        await a.addExpense(450);
        await GoalRepository(
          a.db,
        ).addGoal(name: 'Trip', currency: 'USD', targetMinor: 1000);
        server.rejected.add('transactions');

        final report = await a.engine.run();

        expect(report.failed, 1);
        expect(server.rows('goals'), hasLength(1));
        final stuck = await (a.db.select(
          a.db.outbox,
        )..where((o) => o.targetTable.equals('transactions'))).get();
        expect(stuck.single.attempts, 1);
        expect(stuck.single.lastError, contains('check violation'));
      },
    );

    test('a row refused too often is no longer retried', () async {
      await a.addExpense(450);
      server.rejected.add('transactions');
      for (var i = 0; i < SyncEngine.maxAttempts + 3; i++) {
        await a.engine.run();
      }
      final stuck = await (a.db.select(
        a.db.outbox,
      )..where((o) => o.targetTable.equals('transactions'))).getSingle();
      expect(stuck.attempts, SyncEngine.maxAttempts);
    });
  });

  group('two phones', () {
    late Phone b;

    setUp(() async {
      b = Phone(server);
      await b.engine.attach('user-1', currency: 'USD');
    });

    tearDown(() => b.db.close());

    test('an entry made on one phone appears on the other', () async {
      await a.addExpense(450, note: 'coffee');
      await a.engine.run();

      final report = await b.engine.run();

      expect(report.pulled, greaterThan(0));
      final got = (await b.entries()).single;
      expect(got.amountMinor, 450);
      expect(got.note, 'coffee');
      expect(got.occurredOn, DateTime(2026, 3, 9));
      expect(got.syncState, 'synced');
      // What came from the server is not sent back.
      expect(await b.outboxCount(), 0);
    });

    test('the second run pulls nothing new', () async {
      await a.addExpense(450);
      await a.engine.run();
      await b.engine.run();
      final again = await b.engine.run();
      expect(again.pulled, 0);
    });

    test('edits and deletes travel both ways', () async {
      final id = await a.addExpense(450);
      await a.engine.run();
      await b.engine.run();

      await b.tx.update(
        id,
        type: 'expense',
        currency: 'USD',
        amountMinor: 700,
        categoryId: 'cat_food',
        note: 'from b',
        date: DateTime(2026, 3, 9),
      );
      await b.engine.run();
      await a.engine.run();
      expect((await a.entries()).single.amountMinor, 700);
      expect((await a.entries()).single.note, 'from b');

      await a.tx.softDelete(id);
      await a.engine.run();
      await b.engine.run();
      expect((await b.entries()).single.deletedAt, isNotNull);
    });

    test(
      'a newer edit waiting on this phone is not overwritten by a pull',
      () async {
        final id = await a.addExpense(450);
        await a.engine.run();
        await b.engine.run();

        // B changes the entry on the server first...
        await b.tx.update(
          id,
          type: 'expense',
          currency: 'USD',
          amountMinor: 700,
          categoryId: 'cat_food',
          note: 'b',
          date: DateTime(2026, 3, 9),
        );
        await b.engine.run();

        // ...then A edits (later, offline) and syncs: A's push wins on the
        // server, because it is newer, and A keeps its own value after pulling.
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await a.tx.update(
          id,
          type: 'expense',
          currency: 'USD',
          amountMinor: 999,
          categoryId: 'cat_food',
          note: 'a',
          date: DateTime(2026, 3, 9),
        );
        await a.engine.run();

        expect((await a.entries()).single.amountMinor, 999);
        expect(server.rows('transactions').single['amount_minor'], 999);
        await b.engine.run();
        expect((await b.entries()).single.amountMinor, 999);
      },
    );

    test('an older edit never replaces a newer one on the server', () async {
      final id = await a.addExpense(450);
      await a.engine.run();
      await b.engine.run();

      // A edits now but stays offline for a while.
      await a.tx.update(
        id,
        type: 'expense',
        currency: 'USD',
        amountMinor: 111,
        categoryId: 'cat_food',
        note: 'old',
        date: DateTime(2026, 3, 9),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await b.tx.update(
        id,
        type: 'expense',
        currency: 'USD',
        amountMinor: 222,
        categoryId: 'cat_food',
        note: 'new',
        date: DateTime(2026, 3, 9),
      );
      await b.engine.run();

      await a.engine.run();
      expect(server.rows('transactions').single['amount_minor'], 222);
      // And A catches up with the newer value.
      expect((await a.entries()).single.amountMinor, 222);
    });

    test('wallets, goals and money moved to goals all sync', () async {
      final wallet = await WalletRepository(
        a.db,
      ).add(name: 'Bank', currency: 'USD', openingMinor: 5000);
      final goals = GoalRepository(a.db);
      final goal = await goals.addGoal(
        name: 'Phone',
        currency: 'USD',
        targetMinor: 50000,
        targetDate: DateTime(2026, 12, 1),
      );
      await goals.addContribution(
        goalId: goal,
        amountMinor: 1500,
        date: DateTime(2026, 3, 5),
      );
      await a.engine.run();
      await b.engine.run();

      final wallets = await WalletRepository(b.db).watchAll().first;
      expect(wallets.map((w) => w.id), contains(wallet));
      final g = (await GoalRepository(b.db).watchGoals().first).single;
      expect(g.goal.name, 'Phone');
      expect(g.goal.targetDate, DateTime(2026, 12, 1));
      expect(g.savedMinor, 1500);
    });

    test('paging pulls every row when there are more than one page', () async {
      final small = Phone(server, pageSize: 7);
      addTearDown(small.db.close);
      await small.engine.attach('user-1', currency: 'USD');
      for (var i = 1; i <= 25; i++) {
        await a.addExpense(i);
      }
      await a.engine.run();

      await small.engine.run();
      expect(await small.entries(), hasLength(25));
    });
  });

  group('signing in', () {
    test('guest entries are adopted and uploaded on first sign-in', () async {
      final server = FakeServer();
      final phone = Phone(server);
      addTearDown(phone.db.close);
      await phone.addExpense(450);
      await phone.addExpense(900);

      expect(
        await phone.engine.checkAccount('u1'),
        AccountCheck.adoptGuestData,
      );
      await phone.engine.attach('u1', currency: 'USD');
      await phone.engine.run();

      expect(server.rows('transactions'), hasLength(2));
      expect(server.rows('wallets'), hasLength(1));
      expect(server.rows('categories'), isEmpty);
      expect(await phone.engine.checkAccount('u1'), AccountCheck.fine);
    });

    test(
      'an empty phone takes the account data and drops its placeholder wallet',
      () async {
        final server = FakeServer();
        final first = Phone(server);
        addTearDown(first.db.close);
        await first.addExpense(450);
        await first.engine.attach('u1', currency: 'USD');
        await first.engine.run();

        final fresh = Phone(server);
        addTearDown(fresh.db.close);
        expect(await fresh.engine.checkAccount('u1'), AccountCheck.fine);
        final wasEmpty = await fresh.engine.attach('u1', currency: 'USD');
        expect(wasEmpty, isTrue);
        await fresh.engine.run();

        final wallets = await fresh.db.select(fresh.db.wallets).get();
        expect(wallets, hasLength(1));
        expect(await fresh.entries(), hasLength(1));
      },
    );

    test(
      'a new account on an empty phone gets one empty wallet back',
      () async {
        final server = FakeServer();
        final fresh = Phone(server);
        addTearDown(fresh.db.close);
        await fresh.engine.attach('brand-new', currency: 'KHR');
        await fresh.engine.run();
        await fresh.engine.ensureWallet('KHR');
        expect(await fresh.db.select(fresh.db.wallets).get(), hasLength(1));
      },
    );

    test(
      "another account's data needs a decision, then starts clean",
      () async {
        final server = FakeServer();
        final phone = Phone(server);
        addTearDown(phone.db.close);
        await phone.engine.attach('u1', currency: 'USD');
        await phone.addExpense(450);
        await phone.engine.run();

        expect(
          await phone.engine.checkAccount('u2'),
          AccountCheck.otherAccountData,
        );
        await phone.engine.attach('u2', currency: 'USD');
        expect(await phone.entries(), isEmpty);
        expect(await phone.engine.lastUserId(), 'u2');
        // The first account's data is still safe on the server.
        expect(server.rows('transactions'), hasLength(1));
      },
    );

    test('signing back in as the same account needs no decision', () async {
      final server = FakeServer();
      final phone = Phone(server);
      addTearDown(phone.db.close);
      await phone.engine.attach('u1', currency: 'USD');
      await phone.addExpense(450);
      expect(await phone.engine.checkAccount('u1'), AccountCheck.fine);
    });
  });
}
