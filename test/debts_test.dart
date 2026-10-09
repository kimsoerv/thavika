import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/debts/data/debt_repository.dart';
import 'package:thavika/features/debts/domain/debt_math.dart';
import 'package:thavika/features/wallets/data/wallet_repository.dart';

void main() {
  migrationTests();
  group('debt math', () {
    test('outstanding and fraction', () {
      expect(outstanding(10000, 2500), 7500);
      expect(outstanding(10000, 12000), 0);
      expect(paidFraction(10000, 2500), 0.25);
      expect(paidFraction(0, 5), 0);
      expect(paidFraction(100, 500), 1);
    });

    test('totals split by direction and ignore what is paid back', () {
      final t = debtTotals(const [
        DebtLine(direction: 'lent', amountMinor: 10000, paidMinor: 4000),
        DebtLine(direction: 'lent', amountMinor: 500, paidMinor: 500),
        DebtLine(direction: 'borrowed', amountMinor: 20000, paidMinor: 0),
      ]);
      expect(t.owedToMe, 6000);
      expect(t.iOwe, 20000);
    });

    test('net worth', () {
      const n = NetWorth(
        inWallets: 100000,
        inGoals: 20000,
        owedToMe: 6000,
        iOwe: 20000,
      );
      expect(n.total, 106000);
    });
  });

  group('DebtRepository', () {
    late AppDatabase db;
    late DebtRepository repo;
    late WalletRepository wallets;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DebtRepository(db);
      wallets = WalletRepository(db);
    });

    tearDown(() => db.close());

    Future<int> balance() async {
      final id = (await wallets.defaultWalletId())!;
      return (await wallets.watchBalances().first)[id]!;
    }

    Future<String> lend(int amount) => repo.add(
      person: 'Sok',
      direction: 'lent',
      amountMinor: amount,
      currency: 'USD',
      startedOn: DateTime(2026, 3, 1),
    );

    test(
      'lending takes money out of the wallet, paying back returns it',
      () async {
        expect(await balance(), 0);
        final id = await lend(10000);
        expect(await balance(), -10000);
        await repo.addPayment(
          debtId: id,
          amountMinor: 4000,
          date: DateTime(2026, 3, 5),
        );
        expect(await balance(), -6000);
        final item = (await repo.watchAll().first).single;
        expect(item.paidMinor, 4000);
      },
    );

    test('borrowing puts money in, paying back takes it out', () async {
      final id = await repo.add(
        person: 'Bank',
        direction: 'borrowed',
        amountMinor: 50000,
        currency: 'USD',
        startedOn: DateTime(2026, 3, 1),
      );
      expect(await balance(), 50000);
      await repo.addPayment(
        debtId: id,
        amountMinor: 10000,
        date: DateTime(2026, 3, 9),
      );
      expect(await balance(), 40000);
    });

    test('deleting a debt gives the wallet its money back', () async {
      final id = await lend(10000);
      await repo.addPayment(
        debtId: id,
        amountMinor: 1000,
        date: DateTime(2026, 3, 5),
      );
      await repo.delete(id);
      expect(await balance(), 0);
      expect(await repo.watchAll().first, isEmpty);
    });

    test('a removed payment can be brought back', () async {
      final id = await lend(10000);
      final pid = await repo.addPayment(
        debtId: id,
        amountMinor: 1000,
        date: DateTime(2026, 3, 5),
      );
      await repo.deletePayment(pid);
      expect((await repo.watchAll().first).single.paidMinor, 0);
      await repo.restorePayment(pid);
      expect((await repo.watchAll().first).single.paidMinor, 1000);
    });

    test('open debts come before settled ones, soonest due first', () async {
      final settled = await lend(1000);
      await repo.addPayment(
        debtId: settled,
        amountMinor: 1000,
        date: DateTime(2026, 3, 2),
      );
      await repo.add(
        person: 'Later',
        direction: 'lent',
        amountMinor: 100,
        currency: 'USD',
        startedOn: DateTime(2026, 3, 1),
        dueOn: DateTime(2026, 6, 1),
      );
      await repo.add(
        person: 'Sooner',
        direction: 'lent',
        amountMinor: 100,
        currency: 'USD',
        startedOn: DateTime(2026, 3, 1),
        dueOn: DateTime(2026, 4, 1),
      );
      final names = (await repo.watchAll().first).map((e) => e.debt.person);
      expect(names.toList(), ['Sooner', 'Later', 'Sok']);
    });

    test('deleting a wallet moves its debts to the other wallet', () async {
      final other = await wallets.add(name: 'Bank', currency: 'USD');
      final first = (await wallets.defaultWalletId())!;
      await lend(10000);
      await wallets.delete(first, moveTo: other);
      expect((await wallets.watchBalances().first)[other], -10000);
    });

    test('everything is queued for sync', () async {
      final id = await lend(100);
      await repo.addPayment(
        debtId: id,
        amountMinor: 10,
        date: DateTime(2026, 3, 1),
      );
      final queue = await db.select(db.outbox).get();
      expect(queue.where((q) => q.targetTable == 'debts'), hasLength(1));
      expect(
        queue.where((q) => q.targetTable == 'debt_payments'),
        hasLength(1),
      );
    });
  });
}

void migrationTests() {
  test('upgrading from version 4 adds the debt wallet column', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE "debts" ("owner_id" TEXT NULL, "household_id" TEXT NULL, '
          '"updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, '
          '"sync_state" TEXT NOT NULL DEFAULT \'pending\', "id" TEXT NOT NULL, '
          '"person" TEXT NOT NULL, "direction" TEXT NOT NULL, '
          '"amount_minor" INTEGER NOT NULL, "currency" TEXT NOT NULL, '
          '"note" TEXT NOT NULL DEFAULT \'\', "started_on" INTEGER NOT NULL, '
          '"due_on" INTEGER NULL, PRIMARY KEY ("id"))',
        );
        raw.execute(
          "INSERT INTO debts (id, person, direction, amount_minor, currency, "
          "started_on, updated_at) VALUES ('d1', 'Sok', 'lent', 500, 'USD', 1, 1)",
        );
        raw.execute('PRAGMA user_version = 4');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);
    final row = await db.select(db.debts).getSingle();
    expect(row.person, 'Sok');
    expect(row.walletId, isNull);
  });
}
