import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../household/data/household_local.dart';
import '../domain/row_codec.dart';
import 'postgrest_client.dart';
import 'sync_tables.dart';

/// What one sync run did.
class SyncReport {
  const SyncReport({this.pushed = 0, this.pulled = 0, this.failed = 0});

  final int pushed;
  final int pulled;

  /// Rows the server refused (they stay queued and are retried later).
  final int failed;
}

/// Why signing in needs a decision from the user.
enum AccountCheck {
  /// Nothing on this phone, or the phone's data already belongs to the account.
  fine,

  /// The phone holds entries made as a guest: they will be added to the account.
  adoptGuestData,

  /// The phone holds another account's data.
  otherAccountData,
}

/// Sends local changes to the server and brings server changes back.
///
/// The phone's database is the source of truth: every change is written there
/// first and queued in the outbox. The engine knows nothing about screens;
/// [SyncService] decides when to run it.
class SyncEngine {
  SyncEngine(
    this._db,
    this._client, {
    List<SyncTable>? tables,
    this.pageSize = 500,
  }) : _tables = tables ?? buildSyncTables(_db);

  final AppDatabase _db;
  final PostgrestClient _client;
  final List<SyncTable> _tables;

  /// The tables that sync, in the order they are synced.
  List<String> get tableNames => [for (final t in _tables) t.name];

  static const batchSize = 100;

  /// Rows asked from the server at a time.
  final int pageSize;

  /// A queued row that the server keeps refusing stops being retried here.
  static const maxAttempts = 8;

  static const syncUserKey = 'sync_user_id';
  static String cursorKey(String table) => 'sync_cursor_$table';

  // ---- settings helpers (the engine owns these keys) ----

  Future<String?> _get(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.settingKey.equals(key))).getSingleOrNull();
    return row?.settingValue;
  }

  Future<void> _set(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(settingKey: key, settingValue: value),
      );

  Future<void> _remove(String key) => (_db.delete(
    _db.appSettings,
  )..where((s) => s.settingKey.equals(key))).go();

  /// The account that last synced on this phone, if any.
  Future<String?> lastUserId() => _get(syncUserKey);

  // ---- signing in ----

  /// True when the phone has nothing the user made, except the empty wallet
  /// every phone starts with.
  Future<bool> isPristine() async {
    for (final t in _tables) {
      final n = await t.userRowCount(_db);
      if (t.name == 'wallets') {
        if (n > 1) return false;
      } else if (n > 0) {
        return false;
      }
    }
    return true;
  }

  Future<AccountCheck> checkAccount(String userId) async {
    final last = await lastUserId();
    if (last == userId) return AccountCheck.fine;
    if (await isPristine()) return AccountCheck.fine;
    return last == null
        ? AccountCheck.adoptGuestData
        : AccountCheck.otherAccountData;
  }

  /// Prepares the phone for [userId]: erases another account's data when
  /// asked, makes guest data the account's, and queues everything to upload.
  /// Returns true when the phone was empty, so the account's data should
  /// replace the empty starting wallet.
  Future<bool> attach(String userId, {required String currency}) async {
    final last = await lastUserId();
    if (last == userId) return false;

    if (last != null) {
      // Another account's data: start clean.
      await _db.resetData(currency);
      for (final t in _tables) {
        await _remove(cursorKey(t.name));
      }
      // The other account's household is not this account's.
      await _remove(HouseholdLocal.cacheKey);
    }

    final pristine = await isPristine();
    await _db.transaction(() async {
      if (pristine) {
        // The starting wallet is only a placeholder; the account's own
        // wallets arrive with the first pull.
        await _db.delete(_db.wallets).go();
      } else {
        for (final t in _tables) {
          await t.adoptAll(_db, userId);
        }
      }
      await _set(syncUserKey, userId);
    });
    return pristine;
  }

  /// Puts back an empty wallet if the account brought none.
  Future<void> ensureWallet(String currency) =>
      _db.ensureDefaultWallet(currency);

  // ---- running ----

  Future<SyncReport> run() async {
    final pushed = await _push();
    final pulled = await _pull();
    return SyncReport(
      pushed: pushed.sent,
      pulled: pulled,
      failed: pushed.failed,
    );
  }

  Future<({int sent, int failed})> _push() async {
    final queue = await (_db.select(
      _db.outbox,
    )..orderBy([(o) => OrderingTerm.asc(o.id)])).get();
    if (queue.isEmpty) return (sent: 0, failed: 0);

    final userId = await lastUserId();
    if (userId == null) return (sent: 0, failed: 0);

    // Per table: row id -> highest outbox id seen for it.
    final byTable = <String, Map<String, int>>{};
    final attempts = <String, int>{};
    for (final o in queue) {
      if (o.attempts >= maxAttempts) continue;
      final rows = byTable.putIfAbsent(o.targetTable, () => {});
      if ((rows[o.rowId] ?? 0) < o.id) rows[o.rowId] = o.id;
      attempts['${o.targetTable}/${o.rowId}'] = o.attempts;
    }

    var sent = 0;
    var failed = 0;
    for (final table in _tables) {
      final ids = byTable[table.name];
      if (ids == null) continue;
      final all = ids.keys.toList();
      for (var i = 0; i < all.length; i += batchSize) {
        final chunk = all.sublist(i, (i + batchSize).clamp(0, all.length));
        final rows = await table.rowsByIds(_db, chunk);
        final found = {for (final r in rows) r['id'] as String};

        try {
          await _client.upsert(table.name, [
            for (final r in rows) RowCodec.toRemote(r, userId),
          ]);
        } on RemoteFailure catch (e) {
          if (e.offline || e.unauthorized) rethrow;
          failed += chunk.length;
          for (final id in chunk) {
            await _recordFailure(table.name, id, ids[id]!, e.message);
          }
          continue;
        }

        for (final r in rows) {
          final id = r['id'] as String;
          final seconds = (r['updatedAt'] as int) ~/ 1000;
          await table.markSynced(_db, id, seconds, userId);
        }
        // Rows that no longer exist (or never sync) need no upload.
        for (final id in chunk) {
          await (_db.delete(_db.outbox)..where(
                (o) =>
                    o.targetTable.equals(table.name) &
                    o.rowId.equals(id) &
                    o.id.isSmallerOrEqualValue(ids[id]!),
              ))
              .go();
        }
        sent += found.length;
      }
    }
    return (sent: sent, failed: failed);
  }

  Future<void> _recordFailure(
    String table,
    String id,
    int upToOutboxId,
    String message,
  ) async {
    await (_db.update(_db.outbox)..where(
          (o) =>
              o.targetTable.equals(table) &
              o.rowId.equals(id) &
              o.id.isSmallerOrEqualValue(upToOutboxId),
        ))
        .write(
          OutboxCompanion.custom(
            attempts: _db.outbox.attempts + const Constant(1),
            lastError: Variable<String>(
              message.length > 300 ? message.substring(0, 300) : message,
            ),
          ),
        );
  }

  Future<int> _pull() async {
    var total = 0;
    for (final table in _tables) {
      while (true) {
        final saved = await _get(cursorKey(table.name));
        String? ts;
        String? id;
        if (saved != null) {
          final cut = saved.lastIndexOf('|');
          ts = saved.substring(0, cut);
          id = saved.substring(cut + 1);
        }
        final page = await _client.changes(
          table.name,
          cursorTs: ts,
          cursorId: id,
          limit: pageSize,
        );
        if (page.isEmpty) break;

        await _db.transaction(() async {
          for (final remote in page) {
            final local = await table.updatedAtSeconds(
              _db,
              remote['id'] as String,
            );
            final json = RowCodec.fromRemote(remote);
            final remoteSeconds = (json['updatedAt'] as int) ~/ 1000;
            // A newer local edit is still waiting in the outbox: keep it.
            if (local != null && local > remoteSeconds) continue;
            await table.upsert(_db, json);
            total++;
          }
        });

        final last = page.last;
        await _set(
          cursorKey(table.name),
          '${last['server_updated_at']}|${last['id']}',
        );
        if (page.length < pageSize) break;
      }
    }
    return total;
  }

  /// Number of changes waiting to be sent.
  Stream<int> watchPending() {
    final count = _db.outbox.id.count();
    final query = _db.selectOnly(_db.outbox)..addColumns([count]);
    return query.watchSingle().map((r) => r.read(count) ?? 0);
  }

  /// Forgets the account: cursors and the "last account" mark. The data on
  /// the phone stays.
  Future<void> forgetAccount() async {
    for (final t in _tables) {
      await _remove(cursorKey(t.name));
    }
    await _remove(HouseholdLocal.cacheKey);
    await _remove(syncUserKey);
  }
}
