import 'dart:async';

import 'package:get/get.dart';

import '../../../core/services/settings_service.dart';
import '../../auth/application/auth_service.dart';
import '../../sync/application/sync_service.dart';
import '../data/household_local.dart';
import '../data/household_remote.dart';
import '../domain/household.dart';

/// The household the signed-in person belongs to, and the actions on it.
///
/// Everything shared travels through the normal sync; this service only
/// knows who is in the household and what to do on this phone when the
/// person joins, leaves or is removed.
class HouseholdService extends GetxService {
  HouseholdService(
    this._auth,
    this._sync,
    this._local,
    this._settings, {
    HouseholdRemote? remote,
  }) : _remote = remote;

  final AuthService _auth;
  final SyncService _sync;
  final HouseholdLocal _local;
  final SettingsService _settings;
  HouseholdRemote? _remote;

  /// The household, or null when the person is not in one.
  final info = Rxn<HouseholdInfo>();

  /// An action is running.
  final busy = false.obs;

  /// Set when the owner removed this person: the household's name, so the
  /// screen can say so once.
  final removedFrom = RxnString();

  var _refreshing = false;
  Worker? _syncWorker;
  Worker? _userWorker;
  Worker? _liveWorker;

  HouseholdRemote? get _server {
    final existing = _remote;
    if (existing != null) return existing;
    final client = _sync.client;
    if (client == null) return null;
    return _remote = PostgrestHouseholdRemote(client);
  }

  String? get _me => _auth.user.value?.id;

  bool get inHousehold => info.value != null;
  bool get isOwner => info.value?.isOwner(_me) ?? false;

  Future<HouseholdService> init() async {
    if (_auth.isSignedIn) info.value = await _local.cached();
    // After every sync, check that the membership is still what we think.
    _syncWorker = ever(_sync.lastSyncedAt, (_) => refresh());
    _userWorker = ever(_auth.user, (user) async {
      info.value = user == null ? null : await _local.cached();
    });
    // Live updates only matter when someone else is in the household.
    _liveWorker = ever(info, (household) {
      _sync.listenForChanges(
        household != null && household.hasOthers,
        onMembers: refresh,
      );
    });
    return this;
  }

  /// Who added an entry, for showing under it. Null when it should not be
  /// shown: not in a household, nobody else in it, or it was the person's own.
  String? addedBy(String? ownerId) {
    final household = info.value;
    if (household == null || !household.hasOthers) return null;
    if (ownerId == null || ownerId == _me) return null;
    return household.nameOf(ownerId);
  }

  /// A name to show for the person who added an entry, or null when it is
  /// the signed-in person.
  String? nameOfMember(String? userId) => info.value?.nameOf(userId);

  /// Reads the household from the server. Notices when this person has been
  /// removed, and puts their own copy of the data in place.
  Future<void> refresh() async {
    final server = _server;
    if (_refreshing || busy.value || server == null || !_auth.isSignedIn) {
      return;
    }
    _refreshing = true;
    try {
      final remote = await server.fetch();
      final cached = await _local.cached();
      if (cached != null && (remote == null || remote.id != cached.id)) {
        await _removed(cached);
      }
      if (remote != null) {
        await _local.saveCache(remote);
        info.value = remote;
      } else {
        info.value = null;
      }
    } catch (_) {
      // Offline or a server problem: keep showing what we know.
    } finally {
      _refreshing = false;
    }
  }

  /// This person is no longer a member and did not leave on this phone.
  Future<void> _removed(HouseholdInfo was) async {
    final me = _me;
    if (me == null) return;
    await _local.detach(me, copyMine: true, currency: _settings.currency.value);
    await _local.clearCache();
    removedFrom.value = was.name;
    unawaited(_sync.syncNow());
  }

  // ---- actions (they throw HouseholdException) ----

  Future<T> _act<T>(Future<T> Function(HouseholdRemote server) action) async {
    final server = _server;
    if (server == null) throw HouseholdException(HouseholdProblem.other);
    busy.value = true;
    try {
      return await action(server);
    } finally {
      busy.value = false;
    }
  }

  /// A name for this person in the member list.
  String? get _displayName {
    final user = _auth.user.value;
    final meta = user?.userMetadata;
    final name = (meta?['full_name'] ?? meta?['name']) as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = user?.email;
    return email?.split('@').first;
  }

  /// Everything already uploaded is now in the household, and so is what is
  /// uploaded from here on. Pulls the shared data.
  Future<void> _afterJoining(HouseholdRemote server) async {
    final fresh = await server.fetch();
    if (fresh != null) {
      await _local.saveCache(fresh);
      info.value = fresh;
    }
    await _sync.syncNow();
  }

  Future<void> create(String name) => _act((server) async {
    await _sync.syncNow();
    await server.create(name.trim(), _displayName);
    await _afterJoining(server);
  });

  Future<void> join(String code) => _act((server) async {
    await _sync.syncNow();
    await server.join(code.trim(), _displayName);
    await _afterJoining(server);
  });

  /// A new invite code (owner only).
  Future<String> invite() => _act((server) => server.createInvite());

  Future<void> rename(String name) => _act((server) async {
    await server.rename(name.trim());
    final fresh = await server.fetch();
    if (fresh != null) {
      await _local.saveCache(fresh);
      info.value = fresh;
    }
  });

  Future<void> removeMember(String userId) => _act((server) async {
    await server.removeMember(userId);
    final fresh = await server.fetch();
    if (fresh != null) {
      await _local.saveCache(fresh);
      info.value = fresh;
    }
  });

  /// Leaves the household. What this person added is copied to their own
  /// data, along with the plan; the household keeps everything.
  Future<LeaveResult> leave() => _act((server) async {
    final me = _me;
    // Upload what is waiting first, so nothing made just now is lost.
    await _sync.syncNow();
    final result = await server.leave();
    if (me != null) {
      if (result == LeaveResult.dissolved) {
        await _local.becomePersonal(me);
      } else {
        await _local.detach(
          me,
          copyMine: true,
          currency: _settings.currency.value,
        );
      }
    }
    await _local.clearCache();
    info.value = null;
    await _sync.syncNow();
    return result;
  });

  @override
  void onClose() {
    _syncWorker?.dispose();
    _userWorker?.dispose();
    _liveWorker?.dispose();
    super.onClose();
  }
}
