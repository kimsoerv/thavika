import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/core/services/settings_service.dart';
import 'package:thavika/core/theme/app_theme.dart';
import 'package:thavika/features/entry/application/entry_meta_service.dart';
import 'package:thavika/features/entry/application/voice_input.dart';
import 'package:thavika/features/entry/data/category_repository.dart';
import 'package:thavika/features/entry/presentation/entry_controller.dart';
import 'package:thavika/features/entry/presentation/entry_page.dart';
import 'package:thavika/features/receipts/receipt_service.dart';
import 'package:thavika/features/tags/data/tag_repository.dart';
import 'package:thavika/features/transactions/data/transaction_repository.dart';
import 'package:thavika/features/wallets/data/wallet_repository.dart';
import 'package:thavika/l10n/gen/app_localizations.dart';

class _NoVoice implements VoiceInput {
  @override
  bool get isListening => false;

  @override
  Future<bool> start(
    void Function(String text, bool isFinal) onText, {
    String? localeId,
  }) async => false;

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that lands on something else (for example a button hidden behind
  // the keypad on a small phone) must fail the test.
  WidgetController.hitTestWarningShouldBeFatal = true;

  late AppDatabase db;

  // Each test ends by closing the screen and the database inside real async,
  // so no timers are left behind for the test framework to complain about.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    Get.reset();
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> show(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    late EntryController controller;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      final settings = SettingsService(db);
      final meta = await EntryMetaService(
        WalletRepository(db),
        TagRepository(db),
      ).init();
      controller = EntryController(
        TransactionRepository(db),
        CategoryRepository(db),
        settings,
        TagRepository(db),
        meta,
        ReceiptService(),
        _NoVoice(),
      );
      controller.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    Get.put(controller);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EntryPage(),
      ),
    );
    await tester.pump();
  }

  testWidgets('add screen fits a small phone, extras are behind Details', (
    tester,
  ) async {
    await show(tester, const Size(360, 640));

    // The type toggle is in the bar and the save button names what it saves.
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Save expense'), findsOneWidget);
    // Tags, receipt and split are not on the screen until Details is opened.
    expect(find.text('Tags'), findsNothing);
    expect(find.text('Split'), findsNothing);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Split'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('switching to income changes the save button', (tester) async {
    await show(tester, const Size(360, 640));
    await tester.tap(find.text('Income'));
    // Income has its own categories, loaded from the database.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.text('Save income'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('split opens from Details and can be cancelled', (tester) async {
    await show(tester, const Size(360, 640));

    await tester.tap(find.widgetWithIcon(IconButton, Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();
    expect(find.text('Split between categories'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Split between categories'), findsNothing);
    await finish(tester);
  });
}
