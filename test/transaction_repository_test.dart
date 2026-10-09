import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  final from = DateTime(2026, 10);
  final to = DateTime(2026, 11);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TransactionRepository(db);
  });

  tearDown(() => db.close());

  test('default categories are seeded', () async {
    final all = await db.select(db.categories).get();
    expect(all.where((c) => c.kind == 'expense'), isNotEmpty);
    expect(all.where((c) => c.kind == 'income'), isNotEmpty);
  });

  test('add stores the entry and queues it for sync', () async {
    final id = await repo.add(
      type: 'expense',
      amountMinor: 450,
      currency: 'USD',
      categoryId: 'cat_food',
      note: 'coffee',
      date: DateTime(2026, 10, 9),
    );

    final list = await repo.watchRange(from, to).first;
    expect(list, hasLength(1));
    expect(list.first.tx.id, id);
    expect(list.first.tx.amountMinor, 450);
    expect(list.first.category?.id, 'cat_food');

    final queue = await db.select(db.outbox).get();
    expect(queue, hasLength(1));
    expect(queue.first.rowId, id);
    expect(queue.first.op, 'upsert');
  });

  test('entries outside the range are not listed', () async {
    await repo.add(
      type: 'expense',
      amountMinor: 100,
      currency: 'USD',
      categoryId: 'cat_food',
      note: '',
      date: DateTime(2026, 9, 30),
    );
    expect(await repo.watchRange(from, to).first, isEmpty);
  });

  test('update changes the entry', () async {
    final id = await repo.add(
      type: 'expense',
      amountMinor: 100,
      currency: 'USD',
      categoryId: 'cat_food',
      note: '',
      date: DateTime(2026, 10, 9),
    );
    await repo.update(
      id,
      type: 'expense',
      amountMinor: 250,
      currency: 'USD',
      categoryId: 'cat_bills',
      note: 'power',
      date: DateTime(2026, 10, 10),
    );
    final item = (await repo.watchRange(from, to).first).single;
    expect(item.tx.amountMinor, 250);
    expect(item.tx.categoryId, 'cat_bills');
    expect(item.tx.note, 'power');
  });

  test('soft delete hides the entry and restore brings it back', () async {
    final id = await repo.add(
      type: 'expense',
      amountMinor: 100,
      currency: 'USD',
      categoryId: 'cat_food',
      note: '',
      date: DateTime(2026, 10, 9),
    );
    await repo.softDelete(id);
    expect(await repo.watchRange(from, to).first, isEmpty);

    await repo.restore(id);
    expect(await repo.watchRange(from, to).first, hasLength(1));
  });
}
