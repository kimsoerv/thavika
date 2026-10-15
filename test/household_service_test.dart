import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/core/services/settings_service.dart';
import 'package:thavika/features/auth/application/auth_service.dart';
import 'package:thavika/features/household/application/household_service.dart';
import 'package:thavika/features/household/data/household_local.dart';
import 'package:thavika/features/household/domain/household.dart';
import 'package:thavika/features/sync/application/sync_service.dart';

import 'support/fake_household_remote.dart';

void main() {
  late AppDatabase db;
  late HouseholdLocal local;
  late FakeRemote remote;
  late AuthService auth;
  late HouseholdService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    local = HouseholdLocal(db);
    remote = FakeRemote();
    final settings = await SettingsService(db).init();
    auth = AuthService();
    auth.user.value = const User(
      id: me,
      appMetadata: {},
      userMetadata: {'full_name': 'Kim Soer'},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: 'kim@example.com',
    );
    // A sync service that was never started: syncing does nothing here.
    final sync = SyncService(db, settings, auth);
    service = HouseholdService(auth, sync, local, settings, remote: remote);
  });

  tearDown(() => db.close());

  Future<void> addEntry(String id, String owner, {String? household}) => db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: id,
          type: 'expense',
          amountMinor: 100,
          currency: 'USD',
          categoryId: 'cat_food',
          occurredOn: DateTime(2026, 10, 15),
          ownerId: Value(owner),
          householdId: Value(household),
          updatedAt: DateTime(2026, 10, 15),
        ),
      );

  group('knowing the household', () {
    test('it is read from the server and remembered', () async {
      remote.household = twoPeople();
      await service.refresh();

      expect(service.info.value!.name, 'Home');
      expect(service.inHousehold, isTrue);
      expect((await local.cached())!.id, hid);
    });

    test('offline, what is known stays', () async {
      remote.household = twoPeople();
      await service.refresh();

      remote.failWith = HouseholdException(HouseholdProblem.offline);
      await service.refresh();
      expect(service.info.value!.name, 'Home');
      expect(await local.cached(), isNotNull);
    });

    test('someone who is in no household has none', () async {
      await service.refresh();
      expect(service.info.value, isNull);
      expect(service.inHousehold, isFalse);
    });

    test('who added an entry is shown only for other people', () async {
      remote.household = twoPeople();
      await service.refresh();

      expect(service.addedBy(partner), 'Partner');
      expect(service.addedBy(me), isNull);
      expect(service.addedBy(null), isNull);
      expect(service.addedBy('someone-unknown'), isNull);
    });

    test('a household of one shows no names', () async {
      remote.household = HouseholdInfo(
        id: hid,
        name: 'Home',
        ownerId: me,
        members: const [
          HouseholdMember(userId: me, role: 'owner', displayName: 'Me'),
        ],
      );
      await service.refresh();
      expect(service.addedBy(partner), isNull);
    });
  });

  group('starting and joining', () {
    test(
      'creating uses the person\'s name and ends up in the household',
      () async {
        await service.create('  Our home ');

        expect(remote.calls, ['create Our home']);
        expect(remote.lastDisplayName, 'Kim Soer');
        expect(service.info.value!.name, 'Our home');
        expect(service.isOwner, isTrue);
        expect(service.busy.value, isFalse);
      },
    );

    test('the name falls back to the start of the email', () async {
      auth.user.value = const User(
        id: me,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
        email: 'kim@example.com',
      );
      await service.create('Home');
      expect(remote.lastDisplayName, 'kim');
    });

    test('joining with a code', () async {
      await service.join(' ABCD1234 ');

      expect(remote.calls, ['join ABCD1234']);
      expect(service.info.value!.members, hasLength(2));
      expect(service.isOwner, isFalse);
    });

    test('a wrong code says so and changes nothing', () async {
      remote.failWith = HouseholdException(HouseholdProblem.badCode);

      await expectLater(
        service.join('NOPE'),
        throwsA(
          isA<HouseholdException>().having(
            (e) => e.problem,
            'problem',
            HouseholdProblem.badCode,
          ),
        ),
      );
      expect(service.info.value, isNull);
      expect(service.busy.value, isFalse);
    });

    test('only the owner gets a code', () async {
      remote.household = twoPeople();
      await service.refresh();
      expect(await service.invite(), 'ABCD1234');
    });
  });

  group('leaving', () {
    test('what I added is copied and the household\'s data goes', () async {
      remote.household = twoPeople();
      await service.refresh();
      await addEntry('mine', me, household: hid);
      await addEntry('theirs', partner, household: hid);

      final result = await service.leave();

      expect(result, LeaveResult.left);
      expect(remote.calls, ['leave']);
      expect(service.info.value, isNull);
      expect(await local.cached(), isNull);

      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(1));
      expect(rows.single.ownerId, me);
      expect(rows.single.householdId, isNull);
      expect(rows.single.id, isNot('mine'));
    });

    test('when the household ended, everything stays and is mine', () async {
      remote.household = twoPeople();
      await service.refresh();
      remote.leaveResult = LeaveResult.dissolved;
      await addEntry('mine', me, household: hid);
      await addEntry('theirs', partner, household: hid);

      final result = await service.leave();

      expect(result, LeaveResult.dissolved);
      final rows = await db.select(db.transactions).get();
      expect(rows.map((r) => r.id).toSet(), {'mine', 'theirs'});
      expect(
        rows.every((r) => r.ownerId == me && r.householdId == null),
        isTrue,
      );
    });

    test('a failed leave changes nothing on the phone', () async {
      remote.household = twoPeople();
      await service.refresh();
      await addEntry('mine', me, household: hid);

      remote.failWith = HouseholdException(HouseholdProblem.offline);
      await expectLater(service.leave(), throwsA(isA<HouseholdException>()));

      expect(service.info.value, isNotNull);
      expect(await local.cached(), isNotNull);
      final rows = await db.select(db.transactions).get();
      expect(rows.single.id, 'mine');
      expect(rows.single.householdId, hid);
    });
  });

  group('being removed', () {
    test('the next look at the server notices, and keeps a copy', () async {
      remote.household = twoPeople();
      await service.refresh();
      await addEntry('mine', me, household: hid);
      await addEntry('theirs', partner, household: hid);

      // The owner removed this person on another phone.
      remote.household = null;
      await service.refresh();

      expect(service.info.value, isNull);
      expect(service.removedFrom.value, 'Home');
      expect(await local.cached(), isNull);
      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(1));
      expect(rows.single.ownerId, me);
      expect(rows.single.householdId, isNull);
      expect(rows.single.id, isNot('mine'));
    });

    test('nothing happens to someone who was never in a household', () async {
      await addEntry('mine', me);
      await service.refresh();
      expect(service.removedFrom.value, isNull);
      expect((await db.select(db.transactions).get()).single.id, 'mine');
    });
  });

  group('managing', () {
    test('the owner renames and removes', () async {
      remote.household = twoPeople(ownerId: me);
      await service.refresh();

      await service.rename(' Family ');
      await service.removeMember(partner);
      expect(remote.calls, ['rename Family', 'remove $partner']);
    });

    test('a refused action reports why', () async {
      remote.household = twoPeople();
      await service.refresh();
      remote.failWith = HouseholdException(HouseholdProblem.notOwner);

      await expectLater(
        service.removeMember(partner),
        throwsA(
          isA<HouseholdException>().having(
            (e) => e.problem,
            'problem',
            HouseholdProblem.notOwner,
          ),
        ),
      );
      expect(service.busy.value, isFalse);
    });
  });
}
