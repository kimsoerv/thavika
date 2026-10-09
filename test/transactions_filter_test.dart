import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/features/entry/application/entry_meta_service.dart';
import 'package:thavika/features/tags/data/tag_repository.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';
import 'package:thavika/features/transactions/presentation/transactions_controller.dart';
import 'package:thavika/features/wallets/data/wallet_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late EntryMetaService meta;
  late TransactionsController controller;
  late String cash;
  late String bank;
  late String trip;

  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 50));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TransactionRepository(db);
    final wallets = WalletRepository(db);
    final tags = TagRepository(db);
    cash = (await db.select(db.wallets).getSingle()).id;
    bank = await wallets.add(name: 'Bank', currency: 'USD');
    trip = await tags.add('trip');

    Future<void> add(
      String note,
      int amount,
      String wallet, {
      Set<String> tagIds = const {},
      String category = 'cat_food',
    }) => repo.add(
      type: 'expense',
      amountMinor: amount,
      currency: 'USD',
      categoryId: category,
      note: note,
      date: DateTime(2026, 10, 9),
      walletId: wallet,
      tagIds: tagIds,
    );

    await add('coffee', 450, cash);
    await add('lunch', 1250, bank, tagIds: {trip});
    await add('bus', 100, cash, category: 'cat_transport');

    meta = await EntryMetaService(wallets, tags).init();
    controller = TransactionsController(repo, meta)
      ..items.assignAll(
        await repo.watchRange(DateTime(2026, 10), DateTime(2026, 11)).first,
      );
    await pump();
  });

  tearDown(() async {
    meta.onClose();
    await db.close();
  });

  List<String> notes() =>
      controller.filtered.map((e) => e.tx.note).toList()..sort();

  test('shows everything without filters', () {
    expect(notes(), ['bus', 'coffee', 'lunch']);
  });

  test('wallet filter', () {
    controller.walletFilter.value = bank;
    expect(notes(), ['lunch']);
    controller.walletFilter.value = cash;
    expect(notes(), ['bus', 'coffee']);
  });

  test('tag filter', () {
    controller.tagFilter.value = trip;
    expect(notes(), ['lunch']);
  });

  test('filters combine', () {
    controller.walletFilter.value = cash;
    controller.tagFilter.value = trip;
    expect(notes(), isEmpty);
  });

  test('search by note, category, tag and amount', () {
    controller.query.value = 'cof';
    expect(notes(), ['coffee']);

    controller.query.value = 'transport';
    expect(notes(), ['bus']);

    controller.query.value = '#trip';
    expect(notes(), ['lunch']);

    controller.query.value = '12.5';
    expect(notes(), ['lunch']);

    controller.query.value = r'$4.5';
    expect(notes(), ['coffee']);
  });

  test('text without digits does not match every amount', () {
    controller.query.value = 'zzz';
    expect(notes(), isEmpty);
  });

  test('extra text shows the wallet and tags', () {
    final lunch = controller.items.firstWhere((e) => e.tx.note == 'lunch');
    expect(controller.extraFor(lunch), 'Bank · #trip');
    final bus = controller.items.firstWhere((e) => e.tx.note == 'bus');
    expect(controller.extraFor(bus), 'Cash');
  });

  test('duplicate copies the entry', () async {
    final coffee = controller.items.firstWhere((e) => e.tx.note == 'coffee');
    final copy = await controller.duplicate(coffee.tx.id);
    final rows = await db.select(db.transactions).get();
    expect(rows.where((r) => r.note == 'coffee'), hasLength(2));
    expect(rows.any((r) => r.id == copy), isTrue);
  });
}
