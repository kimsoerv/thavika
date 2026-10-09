import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/core/services/settings_service.dart';
import 'package:thavika/features/entry/application/entry_meta_service.dart';
import 'package:thavika/features/entry/application/voice_input.dart';
import 'package:thavika/features/entry/data/category_repository.dart';
import 'package:thavika/features/entry/domain/quick_line.dart';
import 'package:thavika/features/entry/presentation/entry_controller.dart';
import 'package:thavika/features/receipts/receipt_service.dart';
import 'package:thavika/features/tags/data/tag_repository.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';
import 'package:thavika/features/wallets/data/wallet_repository.dart';

class FakeVoice implements VoiceInput {
  bool available = true;
  bool listeningNow = false;
  void Function(String text, bool isFinal)? onText;

  @override
  bool get isListening => listeningNow;

  @override
  Future<bool> start(
    void Function(String text, bool isFinal) onText, {
    String? localeId,
  }) async {
    if (!available) return false;
    this.onText = onText;
    listeningNow = true;
    return true;
  }

  @override
  Future<void> stop() async => listeningNow = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TransactionRepository tx;
  late TagRepository tags;
  late WalletRepository wallets;
  late EntryMetaService meta;
  late SettingsService settings;
  late EntryController c;
  late FakeVoice voice;

  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 80));

  Future<EntryController> build() async {
    final controller = EntryController(
      tx,
      CategoryRepository(db),
      settings,
      tags,
      meta,
      ReceiptService(),
      voice,
    );
    controller.onInit();
    await pump();
    return controller;
  }

  setUp(() async {
    voice = FakeVoice();
    db = AppDatabase(NativeDatabase.memory());
    tx = TransactionRepository(db);
    tags = TagRepository(db);
    wallets = WalletRepository(db);
    settings = SettingsService(db);
    meta = await EntryMetaService(wallets, tags).init();
    await pump();
    c = await build();
  });

  tearDown(() async {
    c.onClose();
    meta.onClose();
    await db.close();
  });

  void type(String amount) {
    for (final ch in amount.split('')) {
      c.press(ch);
    }
  }

  Future<List<TxRow>> entries() => db.select(db.transactions).get();

  test('starts on the default wallet', () async {
    expect(c.walletId.value, meta.wallets.first.id);
    expect(c.categories, isNotEmpty);
  });

  test('saving needs an amount and a category', () async {
    expect(await c.save(), isNull);
    expect(c.error.value, EntryError.amountRequired);
    type('4.5');
    expect(c.error.value, isNull);
    expect(await c.save(), isNull);
    expect(c.error.value, EntryError.categoryRequired);
    c.selectCategory('cat_food');
    expect(await c.save(), isNotNull);
    final rows = await entries();
    expect(rows.single.amountMinor, 450);
    expect(rows.single.walletId, meta.wallets.first.id);
  });

  test('keypad rules', () {
    c.press('.');
    expect(c.amountText.value, '0.');
    c.press('5');
    c.press('5');
    c.press('5'); // only two decimals
    expect(c.amountText.value, '0.55');
    c.press('back');
    expect(c.amountText.value, '0.5');
    c.press('clear');
    expect(c.amountText.value, '');
    c.press('0');
    c.press('7');
    expect(c.amountText.value, '7'); // no leading zero
  });

  test(
    'tags are saved with the entry and the last wallet is remembered',
    () async {
      final bank = await wallets.add(name: 'Bank', currency: 'USD');
      await pump();
      final tag = await tags.add('trip');
      await pump();
      c.setWallet(bank);
      c.toggleTag(tag);
      type('10');
      c.selectCategory('cat_food');
      final id = await c.save();
      final row = (await entries()).single;
      expect(row.walletId, bank);
      expect((await tags.watchLinks().first)[id], [tag]);
      expect(await settings.getString('last_wallet_id'), bank);

      // The next entry starts on the remembered wallet.
      final next = await build();
      expect(next.walletId.value, bank);
      next.onClose();
    },
  );

  test('creating a tag selects it', () async {
    await c.createTag('wedding');
    await pump();
    expect(c.tagIds, hasLength(1));
    expect(meta.tags.single.name, 'wedding');
  });

  group('split', () {
    test('needs a total, two complete parts and a matching sum', () async {
      c.toggleSplit();
      expect(c.splitMode.value, isTrue);
      expect(c.splits, hasLength(2));

      expect(await c.save(), isNull);
      expect(c.error.value, EntryError.splitNeedAmount);

      type('10');
      expect(await c.save(), isNull);
      expect(c.error.value, EntryError.splitIncomplete);

      c.splits[0].categoryId.value = 'cat_food';
      c.splits[1].categoryId.value = 'cat_health';
      c.setPartAmount(c.splits[0], '6');
      c.setPartAmount(c.splits[1], '3');
      expect(c.splitAssigned, 900);
      expect(await c.save(), isNull);
      expect(c.error.value, EntryError.splitMismatch);
      expect(await entries(), isEmpty);
    });

    test('saves one entry per part with a shared group', () async {
      type('10');
      c.noteCtrl.text = 'market';
      c.toggleSplit();
      c.splits[0].categoryId.value = 'cat_food';
      c.splits[1].categoryId.value = 'cat_health';
      c.setPartAmount(c.splits[0], '6.50');
      c.setPartAmount(c.splits[1], '3.50');
      expect(await c.save(), isNotNull);

      final rows = await entries();
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.amountMinor).toSet(), {650, 350});
      expect(rows.map((r) => r.note).toSet(), {'market'});
      expect(rows.map((r) => r.splitGroup).toSet().length, 1);
      expect(rows.first.splitGroup, isNotNull);
    });

    test('parts can be added and removed, never below two', () {
      c.toggleSplit();
      c.addPart();
      expect(c.splits, hasLength(3));
      c.removePart(c.splits.last);
      expect(c.splits, hasLength(2));
      c.removePart(c.splits.last);
      expect(c.splits, hasLength(2));
    });

    test('turning split off clears the parts', () {
      c.toggleSplit();
      c.toggleSplit();
      expect(c.splitMode.value, isFalse);
      expect(c.splits, isEmpty);
    });

    test('the first part takes the category already picked', () {
      c.selectCategory('cat_food');
      c.toggleSplit();
      expect(c.splits.first.categoryId.value, 'cat_food');
    });
  });

  group('typed line, suggestions and repeat', () {
    const hints = [
      CategoryHint(id: 'cat_food', name: 'Food', isIncome: false),
      CategoryHint(id: 'cat_salary', name: 'Salary', isIncome: true),
    ];

    test('fills the form from a typed line', () async {
      c.quickCtrl.text = 'lunch food 6.5';
      c.applyQuickLine(hints);
      expect(c.amountText.value, '6.5');
      expect(c.noteCtrl.text, 'lunch food');
      expect(c.categoryId.value, 'cat_food');
      expect(c.quickCtrl.text, isEmpty);
    });

    test('an income word switches to income', () async {
      c.quickCtrl.text = 'salary 2000';
      c.applyQuickLine(hints);
      await pump();
      expect(c.type.value, 'income');
      expect(c.amountText.value, '2000');
      expect(c.categoryId.value, 'cat_salary');
    });

    test('a note used before brings its category back', () async {
      await tx.add(
        type: 'expense',
        amountMinor: 250,
        currency: 'USD',
        categoryId: 'cat_transport',
        note: 'grab',
        date: DateTime(2026, 10, 1),
      );
      final fresh = await build();
      fresh.quickCtrl.text = 'grab 3';
      fresh.applyQuickLine(hints);
      expect(fresh.categoryId.value, 'cat_transport');
      expect(fresh.amountText.value, '3');
      fresh.onClose();
    });

    test('suggestions follow the typed note', () async {
      await tx.add(
        type: 'expense',
        amountMinor: 250,
        currency: 'USD',
        categoryId: 'cat_food',
        note: 'coffee',
        date: DateTime(2026, 10, 1),
      );
      c.noteCtrl.text = 'co';
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(c.suggestions.map((s) => s.note), ['coffee']);

      c.useSuggestion(c.suggestions.first);
      expect(c.noteCtrl.text, 'coffee');
      expect(c.categoryId.value, 'cat_food');
      expect(c.suggestions, isEmpty);
    });

    test('repeat fills the form from an earlier entry', () async {
      final tag = await tags.add('trip');
      await pump();
      await tx.add(
        type: 'expense',
        amountMinor: 1250,
        currency: 'USD',
        categoryId: 'cat_food',
        note: 'lunch',
        date: DateTime(2026, 10, 1),
        tagIds: {tag},
      );
      await pump();
      final fresh = await build();
      expect(fresh.recents, hasLength(1));
      fresh.useRecent(fresh.recents.first);
      expect(fresh.amountText.value, '12.5');
      expect(fresh.categoryId.value, 'cat_food');
      expect(fresh.noteCtrl.text, 'lunch');
      expect(fresh.tagIds, {tag});
      fresh.onClose();
    });
  });

  group('voice', () {
    const hints = [CategoryHint(id: 'cat_food', name: 'Food', isIncome: false)];

    test('the spoken line fills the form when the phrase ends', () async {
      await c.toggleVoice(hints);
      expect(c.listening.value, isTrue);

      voice.onText!('lunch food', false);
      expect(c.quickCtrl.text, 'lunch food');
      expect(c.amountText.value, isEmpty);

      voice.onText!('lunch food 6.5', true);
      expect(c.listening.value, isFalse);
      expect(c.amountText.value, '6.5');
      expect(c.categoryId.value, 'cat_food');
      expect(c.noteCtrl.text, 'lunch food');
    });

    test('tapping again stops listening', () async {
      await c.toggleVoice(hints);
      await c.toggleVoice(hints);
      expect(c.listening.value, isFalse);
      expect(voice.listeningNow, isFalse);
    });

    test('a phone without speech shows the message', () async {
      voice.available = false;
      await c.toggleVoice(hints);
      expect(c.listening.value, isFalse);
      expect(c.voiceUnavailable.value, isTrue);
    });
  });

  test('editing keeps the wallet and updates the entry', () async {
    final id = await tx.add(
      type: 'expense',
      amountMinor: 450,
      currency: 'USD',
      categoryId: 'cat_food',
      note: 'coffee',
      date: DateTime(2026, 10, 9),
    );
    final item =
        (await tx.watchRange(DateTime(2026, 10), DateTime(2026, 11)).first)
            .single;
    // Controller built for editing: arguments come from Get, so set the
    // state the same way onInit would.
    final edit = await build();
    edit.editing = item;
    edit.amountText.value = '9';
    edit.categoryId.value = 'cat_bills';
    edit.walletId.value = item.tx.walletId;
    expect(await edit.save(), id);
    final row = (await entries()).single;
    expect(row.amountMinor, 900);
    expect(row.categoryId, 'cat_bills');
    edit.onClose();
  });
}
