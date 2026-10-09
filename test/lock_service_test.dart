import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:thavika/core/db/app_database.dart';
import 'package:thavika/core/services/settings_service.dart';
import 'package:thavika/features/lock/application/lock_service.dart';

class _MemoryStore implements SecretStore {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

class _FakeBio implements Biometrics {
  bool ok = true;
  @override
  Future<bool> get available async => true;
  @override
  Future<bool> authenticate(String reason) async => ok;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SettingsService settings;
  late _MemoryStore store;
  late _FakeBio bio;
  late DateTime now;

  Future<LockService> make() => LockService(
    settings,
    store: store,
    biometrics: bio,
    clock: () => now,
  ).init();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    settings = await SettingsService(db).init();
    store = _MemoryStore();
    bio = _FakeBio();
    now = DateTime(2026, 1, 1, 9);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  test('starts unlocked and off', () async {
    final lock = await make();
    expect(lock.enabled.value, isFalse);
    expect(lock.locked.value, isFalse);
  });

  test('the PIN is stored hashed, never as typed', () async {
    final lock = await make();
    await lock.setPin('1234');
    expect(lock.enabled.value, isTrue);
    expect(store.map.values.any((v) => v.contains('1234')), isFalse);
    expect(await lock.check('1234'), isTrue);
    expect(await lock.check('1235'), isFalse);
  });

  test('a restart with the lock on starts locked', () async {
    final lock = await make();
    await lock.setPin('1234');
    final again = await make();
    expect(again.enabled.value, isTrue);
    expect(again.locked.value, isTrue);
  });

  test('the right PIN unlocks, the wrong one does not', () async {
    final lock = await make();
    await lock.setPin('1234');
    lock.locked.value = true;
    expect(await lock.unlockWithPin('0000'), PinResult.wrong);
    expect(lock.locked.value, isTrue);
    expect(await lock.unlockWithPin('1234'), PinResult.ok);
    expect(lock.locked.value, isFalse);
  });

  test('five wrong tries make the user wait, longer each time', () async {
    final lock = await make();
    await lock.setPin('1234');
    lock.locked.value = true;
    for (var i = 0; i < 5; i++) {
      await lock.unlockWithPin('0000');
    }
    expect(lock.waitSeconds.value, 30);
    // Even the right PIN is refused while waiting.
    expect(await lock.unlockWithPin('1234'), PinResult.waiting);
    expect(lock.locked.value, isTrue);

    now = now.add(const Duration(seconds: 31));
    expect(await lock.unlockWithPin('0000'), PinResult.wrong);
    expect(lock.waitSeconds.value, 60);

    now = now.add(const Duration(seconds: 61));
    expect(await lock.unlockWithPin('1234'), PinResult.ok);
  });

  test('locks again after the grace period in the background', () async {
    final lock = await make();
    await lock.setPin('1234');
    lock.locked.value = false;

    lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 20));
    lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(lock.locked.value, isFalse);

    lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(lock.locked.value, isTrue);
  });

  test('fingerprint unlocks only when switched on', () async {
    final lock = await make();
    await lock.setPin('1234');
    lock.locked.value = true;
    expect(await lock.unlockWithBiometrics('x'), isFalse);

    await lock.setBiometric(true);
    bio.ok = false;
    expect(await lock.unlockWithBiometrics('x'), isFalse);
    bio.ok = true;
    expect(await lock.unlockWithBiometrics('x'), isTrue);
    expect(lock.locked.value, isFalse);
  });

  test('turning the lock off forgets the PIN', () async {
    final lock = await make();
    await lock.setPin('1234');
    await lock.disable();
    expect(lock.enabled.value, isFalse);
    expect(store.map, isEmpty);
    final again = await make();
    expect(again.locked.value, isFalse);
  });
}
