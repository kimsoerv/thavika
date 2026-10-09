import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';

class TransferRepository {
  TransferRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<TransferRow>> watchRange(DateTime from, DateTime to) {
    final query = _db.select(_db.transfers)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.occurredOn.isBiggerOrEqualValue(from) &
            t.occurredOn.isSmallerThanValue(to),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredOn),
        (t) => OrderingTerm.desc(t.updatedAt),
      ]);
    return query.watch();
  }

  /// The latest transfers, newest first.
  Stream<List<TransferRow>> watchRecent({int limit = 20}) {
    final query = _db.select(_db.transfers)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredOn),
        (t) => OrderingTerm.desc(t.updatedAt),
      ])
      ..limit(limit);
    return query.watch();
  }

  Future<String> add({
    required String fromWalletId,
    required String toWalletId,
    required int amountMinor,
    required String currency,
    required DateTime date,
    String note = '',
  }) async {
    if (fromWalletId == toWalletId) {
      throw ArgumentError('A transfer needs two different wallets.');
    }
    final id = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.transfers)
          .insert(
            TransfersCompanion.insert(
              id: id,
              fromWalletId: fromWalletId,
              toWalletId: toWalletId,
              amountMinor: amountMinor,
              currency: currency,
              occurredOn: DateTime(date.year, date.month, date.day),
              note: Value(note),
              updatedAt: DateTime.now(),
            ),
          );
      await _db.enqueue('transfers', id, 'upsert');
    });
    return id;
  }

  Future<void> update(
    String id, {
    required String fromWalletId,
    required String toWalletId,
    required int amountMinor,
    required DateTime date,
    String note = '',
  }) async {
    if (fromWalletId == toWalletId) {
      throw ArgumentError('A transfer needs two different wallets.');
    }
    await _db.transaction(() async {
      await (_db.update(_db.transfers)..where((t) => t.id.equals(id))).write(
        TransfersCompanion(
          fromWalletId: Value(fromWalletId),
          toWalletId: Value(toWalletId),
          amountMinor: Value(amountMinor),
          occurredOn: Value(DateTime(date.year, date.month, date.day)),
          note: Value(note),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('transfers', id, 'upsert');
    });
  }

  Future<void> softDelete(String id) => _setDeleted(id, true);

  Future<void> restore(String id) => _setDeleted(id, false);

  Future<void> _setDeleted(String id, bool deleted) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.transfers)..where((t) => t.id.equals(id))).write(
        TransfersCompanion(
          deletedAt: Value(deleted ? now : null),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('transfers', id, deleted ? 'delete' : 'upsert');
    });
  }
}
