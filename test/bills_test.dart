import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/recurring/data/recurring_repository.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late RecurringRepository repo;
  late TransactionRepository tx;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RecurringRepository(db);
    tx = TransactionRepository(db);
  });

  tearDown(() => db.close());

  Future<String> addBill({required bool auto}) => repo.add(
    type: 'expense',
    amountMinor: 3000,
    currency: 'USD',
    categoryId: 'cat_bills',
    note: 'Electricity',
    frequency: 'monthly',
    startOn: DateTime(2026, 10, 5),
    isBill: true,
    autoCreate: auto,
  );

  test('a bill that changes is not created by itself', () async {
    await addBill(auto: false);
    expect(await repo.generateDue(DateTime(2026, 10, 9)), 0);
    final rule = (await repo.watchAll().first).single.rule;
    // Still waiting on 5 Oct, so the app can show it as overdue.
    expect(rule.nextRunOn, DateTime(2026, 10, 5));
    expect(rule.autoCreate, isFalse);
  });

  test('an automatic bill still is', () async {
    await addBill(auto: true);
    expect(await repo.generateDue(DateTime(2026, 10, 9)), 1);
  });

  test('marking paid creates the entry with the real amount', () async {
    final id = await addBill(auto: false);
    await repo.markPaid(id, amountMinor: 4250, paidOn: DateTime(2026, 10, 9));

    final list = await tx
        .watchRange(DateTime(2026, 10), DateTime(2026, 11))
        .first;
    expect(list, hasLength(1));
    expect(list.single.tx.amountMinor, 4250);
    expect(list.single.tx.occurredOn, DateTime(2026, 10, 9));
    expect(list.single.tx.note, 'Electricity');

    final rule = (await repo.watchAll().first).single.rule;
    expect(rule.nextRunOn, DateTime(2026, 11, 5));
  });

  test('paying twice pays this and then the next due date', () async {
    final id = await addBill(auto: false);
    await repo.markPaid(id, amountMinor: 1000, paidOn: DateTime(2026, 10, 9));
    await repo.markPaid(id, amountMinor: 1100, paidOn: DateTime(2026, 10, 9));
    final list = await tx
        .watchRange(DateTime(2026, 10), DateTime(2026, 11))
        .first;
    expect(list, hasLength(2));
    expect(
      (await repo.watchAll().first).single.rule.nextRunOn,
      DateTime(2026, 12, 5),
    );
  });
}
