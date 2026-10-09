import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../auth/application/auth_service.dart';
import '../data/postgrest_client.dart';
import '../data/sync_engine.dart';

enum SyncState { off, signedOut, idle, syncing, offline, error }

/// Decides when to sync and tells the screens how it is going.
///
/// It runs the [SyncEngine] when: the user signs in, the app opens or comes
/// back, the phone gets internet, changes are waiting (a few seconds after
/// the last one), and every few minutes while the app is open.
class SyncService extends GetxService with WidgetsBindingObserver {
  SyncService(this._db, this._settings, this._auth);

  final AppDatabase _db;
  final SettingsService _settings;
  final AuthService _auth;

  SyncEngine? _engine;
  PostgrestClient? _client;

  final state = SyncState.off.obs;
  final pending = 0.obs;
  final lastSyncedAt = Rxn<DateTime>();
  final lastError = RxnString();

  StreamSubscription<int>? _pendingSub;
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  Worker? _userWorker;
  Timer? _debounce;
  Timer? _periodic;
  var _running = false;

  bool get isConfigured => _auth.isConfigured;

  Future<SyncService> init() async {
    if (!isConfigured) return this;
    _client = PostgrestClient(
      dio: Dio(),
      baseUrl: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      accessToken: () => _auth.accessToken,
    );
    _engine = SyncEngine(_db, _client!);
    _pendingSub = _engine!.watchPending().listen((n) {
      pending.value = n;
      if (n > 0) _schedule();
    });
    _netSub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) _schedule();
    });
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => _schedule());
    WidgetsBinding.instance.addObserver(this);

    _userWorker = ever(_auth.user, (user) {
      if (user == null) {
        state.value = SyncState.signedOut;
      } else {
        _schedule();
      }
    });
    state.value = _auth.isSignedIn ? SyncState.idle : SyncState.signedOut;
    if (_auth.isSignedIn) _schedule();
    return this;
  }

  // ---- signing in ----

  /// What signing in as the current user would do to this phone's data.
  Future<AccountCheck> checkAccount() async {
    final id = _auth.user.value?.id;
    if (id == null || _engine == null) return AccountCheck.fine;
    return _engine!.checkAccount(id);
  }

  /// Links this phone to the signed-in account and runs the first sync.
  Future<void> start() async {
    final id = _auth.user.value?.id;
    final engine = _engine;
    if (id == null || engine == null) return;
    final wasEmpty = await engine.attach(
      id,
      currency: _settings.currency.value,
    );
    await syncNow();
    if (wasEmpty && state.value == SyncState.idle) {
      // The account's wallets are here now. Use their currency, and keep at
      // least one wallet for a brand-new account.
      final wallets = await _db.select(_db.wallets).get();
      final currency = wallets.isEmpty ? null : wallets.first.currency;
      if (currency != null && currency != _settings.currency.value) {
        await _settings.setCurrency(currency);
      }
      await engine.ensureWallet(_settings.currency.value);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state.value = SyncState.signedOut;
  }

  /// Deletes the account and its cloud data. Data on the phone stays.
  Future<bool> deleteAccount() async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.rpc('delete_my_account');
    } on RemoteFailure catch (e) {
      lastError.value = e.message;
      return false;
    }
    await _engine?.forgetAccount();
    await signOut();
    return true;
  }

  // ---- running ----

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), syncNow);
  }

  Future<void> syncNow() async {
    final engine = _engine;
    if (engine == null || !_auth.isSignedIn || _running) return;
    // Not linked to this account yet (the sign-in flow does that).
    if (await engine.lastUserId() != _auth.user.value?.id) return;

    _running = true;
    state.value = SyncState.syncing;
    try {
      await engine.run();
      lastSyncedAt.value = DateTime.now();
      lastError.value = null;
      state.value = SyncState.idle;
    } on RemoteFailure catch (e) {
      if (e.offline) {
        state.value = SyncState.offline;
      } else {
        lastError.value = e.unauthorized ? 'Please sign in again' : e.message;
        state.value = SyncState.error;
      }
    } catch (e) {
      lastError.value = '$e';
      state.value = SyncState.error;
    } finally {
      _running = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _auth.isSignedIn) _schedule();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _periodic?.cancel();
    _pendingSub?.cancel();
    _netSub?.cancel();
    _userWorker?.dispose();
    super.onClose();
  }
}
