import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/services/settings_service.dart';

/// Keeps small secrets (the PIN hash) in the phone's secure storage.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class KeychainSecretStore implements SecretStore {
  const KeychainSecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Fingerprint / face check.
abstract class Biometrics {
  Future<bool> get available;
  Future<bool> authenticate(String reason);
}

class DeviceBiometrics implements Biometrics {
  DeviceBiometrics();

  final _auth = LocalAuthentication();

  @override
  Future<bool> get available async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Result of typing a PIN on the lock screen.
enum PinResult { ok, wrong, waiting }

/// App lock: a PIN, optionally fingerprint or face.
///
/// The PIN is never stored, only a salted hash of it in secure storage.
/// After a few wrong tries the app makes the user wait, longer each time.
class LockService extends GetxService with WidgetsBindingObserver {
  LockService(
    this._settings, {
    SecretStore? store,
    Biometrics? biometrics,
    DateTime Function()? clock,
    this.grace = const Duration(minutes: 1),
  }) : _store = store ?? const KeychainSecretStore(),
       _bio = biometrics ?? DeviceBiometrics(),
       _now = clock ?? DateTime.now;

  final SettingsService _settings;
  final SecretStore _store;
  final Biometrics _bio;
  final DateTime Function() _now;

  /// How long the app can be in the background before it locks again.
  final Duration grace;

  static const pinLength = 4;
  static const freeTries = 5;

  static const _enabledKey = 'lock_enabled';
  static const _bioKey = 'lock_biometric';
  static const _hashKey = 'lock_pin_hash';
  static const _saltKey = 'lock_pin_salt';
  static const _failuresKey = 'lock_failures';
  static const _waitUntilKey = 'lock_wait_until';

  /// A PIN is set.
  final enabled = false.obs;

  /// Fingerprint / face may be used instead of the PIN.
  final biometric = false.obs;

  /// The lock screen is showing.
  final locked = false.obs;

  /// Seconds the user still has to wait, 0 when they can type.
  final waitSeconds = 0.obs;

  int _failures = 0;
  DateTime? _waitUntil;
  DateTime? _pausedAt;

  Future<LockService> init() async {
    enabled.value = await _settings.getString(_enabledKey) == '1';
    biometric.value = await _settings.getString(_bioKey) == '1';
    // Closing the app must not give the guesser a fresh set of tries.
    final failures = await _settings.getString(_failuresKey);
    _failures = int.tryParse(failures ?? '') ?? 0;
    final until = int.tryParse(await _settings.getString(_waitUntilKey) ?? '');
    _waitUntil = until == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(until);
    waitSeconds.value = remainingWait;
    // Opening the app from scratch asks for the PIN.
    locked.value = enabled.value;
    WidgetsBinding.instance.addObserver(this);
    return this;
  }

  Future<bool> get biometricsAvailable => _bio.available;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled.value) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= _now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _pausedAt;
      _pausedAt = null;
      if (since != null && _now().difference(since) >= grace) {
        locked.value = true;
      }
    }
  }

  Future<void> _saveLockout() async {
    await _settings.setString(_failuresKey, '$_failures');
    await _settings.setString(
      _waitUntilKey,
      _waitUntil == null ? '' : '${_waitUntil!.millisecondsSinceEpoch}',
    );
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _newSalt() {
    final rng = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => rng.nextInt(256)));
  }

  /// Turns the lock on, or changes the PIN.
  Future<void> setPin(String pin) async {
    final salt = _newSalt();
    await _store.write(_saltKey, salt);
    await _store.write(_hashKey, _hash(pin, salt));
    await _settings.setString(_enabledKey, '1');
    enabled.value = true;
    _failures = 0;
    _waitUntil = null;
    await _saveLockout();
  }

  Future<void> setBiometric(bool on) async {
    biometric.value = on;
    await _settings.setString(_bioKey, on ? '1' : '0');
  }

  /// Checks a PIN without changing the lock state.
  Future<bool> check(String pin) async {
    final salt = await _store.read(_saltKey);
    final hash = await _store.read(_hashKey);
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  /// Seconds to wait before the next try (0 = can try now).
  int get remainingWait {
    final until = _waitUntil;
    if (until == null) return 0;
    final left = until.difference(_now()).inSeconds + 1;
    return left > 0 ? left : 0;
  }

  /// A PIN typed on the lock screen. Unlocks on success.
  Future<PinResult> unlockWithPin(String pin) async {
    if (remainingWait > 0) {
      waitSeconds.value = remainingWait;
      return PinResult.waiting;
    }
    if (await check(pin)) {
      _failures = 0;
      _waitUntil = null;
      waitSeconds.value = 0;
      await _saveLockout();
      locked.value = false;
      return PinResult.ok;
    }
    _failures++;
    if (_failures >= freeTries) {
      // 30 s, 1 min, 2 min, ... up to 15 min.
      final steps = _failures - freeTries;
      final seconds = min(30 * pow(2, steps).toInt(), 15 * 60);
      _waitUntil = _now().add(Duration(seconds: seconds));
      waitSeconds.value = seconds;
    }
    await _saveLockout();
    return PinResult.wrong;
  }

  Future<bool> unlockWithBiometrics(String reason) async {
    if (!biometric.value || !await _bio.available) return false;
    final ok = await _bio.authenticate(reason);
    if (ok) {
      _failures = 0;
      _waitUntil = null;
      waitSeconds.value = 0;
      await _saveLockout();
      locked.value = false;
    }
    return ok;
  }

  /// Turns the lock off. The caller has already checked the PIN.
  Future<void> disable() async {
    await _store.delete(_hashKey);
    await _store.delete(_saltKey);
    await _settings.setString(_enabledKey, '0');
    await _settings.setString(_bioKey, '0');
    _failures = 0;
    _waitUntil = null;
    waitSeconds.value = 0;
    await _saveLockout();
    enabled.value = false;
    biometric.value = false;
    locked.value = false;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
