import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/core/services/settings_service.dart';
import 'package:thavika/core/theme/app_theme.dart';
import 'package:thavika/features/auth/application/auth_service.dart';
import 'package:thavika/features/household/application/household_service.dart';
import 'package:thavika/features/household/data/household_local.dart';
import 'package:thavika/features/household/domain/household.dart';
import 'package:thavika/features/household/presentation/household_page.dart';
import 'package:thavika/features/sync/application/sync_service.dart';
import 'package:thavika/l10n/gen/app_localizations.dart';

import 'support/fake_household_remote.dart';

const _user = User(
  id: me,
  appMetadata: {},
  userMetadata: {'full_name': 'Kim Soer'},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
  email: 'kim@example.com',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A tap that lands on something else must fail the test.
  WidgetController.hitTestWarningShouldBeFatal = true;

  late AppDatabase db;
  late FakeRemote remote;
  late AuthService auth;
  late HouseholdService service;

  Future<void> show(
    WidgetTester tester, {
    bool signedIn = true,
    HouseholdInfo? household,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      final settings = await SettingsService(db).init();
      auth = Get.put(AuthService());
      if (signedIn) auth.user.value = _user;
      remote = FakeRemote()..household = household;
      service = Get.put(
        HouseholdService(
          auth,
          SyncService(db, settings, auth),
          HouseholdLocal(db),
          settings,
          remote: remote,
        ),
      );
      await service.refresh();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HouseholdPage(),
      ),
    );
    await tester.pump();
  }

  /// Lets the service finish its database work, which needs real time.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    Get.reset();
    await tester.runAsync(
      () => db.close().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('signed out, it asks to sign in first', (tester) async {
    await show(tester, signedIn: false);
    expect(find.text('Sign in to share with someone else.'), findsOneWidget);
    expect(find.text('Start a household'), findsNothing);
    await finish(tester);
  });

  testWidgets('with no household, it offers to start or join', (tester) async {
    await show(tester);
    expect(find.text('Start a household'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
    expect(find.text('Leave household'), findsNothing);
    await finish(tester);
  });

  testWidgets('starting asks for a name, warns, then shows the household', (
    tester,
  ) async {
    await show(tester);

    await tester.tap(find.text('Start a household'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Our home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The warning says what sharing means before anything happens.
    expect(find.textContaining('shares all your entries'), findsOneWidget);
    expect(remote.calls, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await settle(tester);

    expect(remote.calls, ['create Our home']);
    expect(find.text('Our home'), findsOneWidget);
    expect(find.text('Kim Soer'), findsOneWidget);
    expect(find.text('Owner · You'), findsOneWidget);
    expect(find.text('Invite someone'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('cancelling the warning starts nothing', (tester) async {
    await show(tester);
    await tester.tap(find.text('Start a household'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Our home');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(remote.calls, isEmpty);
    expect(find.text('Start a household'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a wrong code is explained and nothing changes', (tester) async {
    await show(tester);
    remote.failWith = HouseholdException(HouseholdProblem.badCode);

    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NOPE');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Join this household?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await settle(tester);

    expect(find.text('That code is wrong or has expired.'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('joining with a code shows the household', (tester) async {
    await show(tester);

    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abcd1234');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await settle(tester);

    expect(remote.calls, ['join abcd1234']);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
    // Not the owner: no invite button, and no way to remove people.
    expect(find.text('Invite someone'), findsNothing);
    expect(find.byTooltip('Remove'), findsNothing);
    expect(find.text('Leave household'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the owner can invite and sees the code', (tester) async {
    await show(tester, household: twoPeople(ownerId: me));

    await tester.tap(find.text('Invite someone'));
    await settle(tester);
    expect(find.text('ABCD1234'), findsOneWidget);
    expect(find.textContaining('7 days'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await finish(tester);
  });

  testWidgets('the owner removes a member after a warning', (tester) async {
    await show(tester, household: twoPeople(ownerId: me));

    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.person_remove_outlined),
    );
    await tester.pumpAndSettle();
    expect(find.text('Remove Partner?'), findsOneWidget);
    expect(remote.calls, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await settle(tester);
    expect(remote.calls, ['remove $partner']);
    await finish(tester);
  });

  testWidgets('leaving asks first, then goes back to start and join', (
    tester,
  ) async {
    await show(tester, household: twoPeople());

    await tester.ensureVisible(find.text('Leave household'));
    await tester.tap(find.text('Leave household'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Home?'), findsOneWidget);
    expect(find.textContaining('You keep a copy'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Leave household'));
    await settle(tester);

    expect(remote.calls, ['leave']);
    expect(find.text('Start a household'), findsOneWidget);
    await finish(tester);
  });
}
