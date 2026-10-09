import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../tags/data/tag_repository.dart';

/// A transaction together with its category (null if the category is gone).
class TxWithCategory {
  const TxWithCategory(this.tx, this.category);

  final TxRow tx;
  final CategoryRow? category;
}

/// A note the user wrote before, with the category it was used for.
class NoteSuggestion {
  const NoteSuggestion(this.note, this.categoryId, this.count);

  final String note;
  final String categoryId;
  final int count;
}

class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Live list of entries with `from <= date < to`, newest first.
  Stream<List<TxWithCategory>> watchRange(DateTime from, DateTime to) {
    final t = _db.transactions;
    final c = _db.categories;
    final query =
        _db.select(t).join([leftOuterJoin(c, c.id.equalsExp(t.categoryId))])
          ..where(
            t.deletedAt.isNull() &
                t.occurredOn.isBiggerOrEqualValue(from) &
                t.occurredOn.isSmallerThanValue(to),
          )
          ..orderBy([
            OrderingTerm.desc(t.occurredOn),
            OrderingTerm.desc(t.updatedAt),
          ]);
    return query.watch().map(
      (rows) => rows
          .map((r) => TxWithCategory(r.readTable(t), r.readTableOrNull(c)))
          .toList(),
    );
  }

  /// Spending per category for entries with `from <= date < to`.
  Future<Map<String, int>> expenseByCategory(DateTime from, DateTime to) async {
    final t = _db.transactions;
    final sum = t.amountMinor.sum();
    final query = _db.selectOnly(t)
      ..addColumns([t.categoryId, sum])
      ..where(
        t.type.equals('expense') &
            t.deletedAt.isNull() &
            t.occurredOn.isBiggerOrEqualValue(from) &
            t.occurredOn.isSmallerThanValue(to),
      )
      ..groupBy([t.categoryId]);
    final rows = await query.get();
    return {for (final r in rows) r.read(t.categoryId)!: r.read(sum) ?? 0};
  }

  /// How many times each category was used for entries of [type].
  /// Used to show the most-used categories first when adding an entry.
  Future<Map<String, int>> categoryUsage(String type) async {
    final t = _db.transactions;
    final count = t.id.count();
    final query = _db.selectOnly(t)
      ..addColumns([t.categoryId, count])
      ..where(t.type.equals(type) & t.deletedAt.isNull())
      ..groupBy([t.categoryId]);
    final rows = await query.get();
    return {for (final r in rows) r.read(t.categoryId)!: r.read(count) ?? 0};
  }

  /// Adds an entry. Without [walletId] the default wallet is used.
  Future<String> add({
    required String type,
    required int amountMinor,
    required String currency,
    required String categoryId,
    required String note,
    required DateTime date,
    String? walletId,
    String? receiptPath,
    String? splitGroup,
    Set<String> tagIds = const {},
    String? id,
  }) async {
    final entryId = id ?? _uuid.v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      final wallet = walletId ?? await _db.defaultWalletId();
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: entryId,
              type: type,
              amountMinor: amountMinor,
              currency: currency,
              categoryId: categoryId,
              note: Value(note),
              occurredOn: date,
              walletId: Value(wallet),
              receiptPath: Value(receiptPath),
              splitGroup: Value(splitGroup),
              updatedAt: now,
            ),
          );
      await _db.enqueue('transactions', entryId, 'upsert');
      if (tagIds.isNotEmpty) {
        await TagRepository(_db).setTags(entryId, tagIds);
      }
    });
    return entryId;
  }

  /// Changes an entry. Wallet, receipt and tags stay as they are unless given.
  Future<void> update(
    String id, {
    required String type,
    required int amountMinor,
    required String currency,
    required String categoryId,
    required String note,
    required DateTime date,
    String? walletId,
    Value<String?> receiptPath = const Value.absent(),
    Set<String>? tagIds,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          type: Value(type),
          amountMinor: Value(amountMinor),
          currency: Value(currency),
          categoryId: Value(categoryId),
          note: Value(note),
          occurredOn: Value(date),
          walletId: walletId == null ? const Value.absent() : Value(walletId),
          receiptPath: receiptPath,
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('transactions', id, 'upsert');
      if (tagIds != null) await TagRepository(_db).setTags(id, tagIds);
    });
  }

  /// Notes used before that start with [prefix], most used first.
  /// With [categoryId] only notes used for that category are returned.
  Future<List<NoteSuggestion>> suggestNotes({
    required String type,
    String prefix = '',
    String? categoryId,
    int limit = 5,
  }) async {
    final escaped = prefix
        .toLowerCase()
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await _db
        .customSelect(
          'SELECT note, category_id, COUNT(*) AS c, MAX(occurred_on) AS last '
          'FROM transactions '
          "WHERE deleted_at IS NULL AND type = ? AND note <> '' "
          "AND lower(note) LIKE ? ESCAPE '\\' "
          '${categoryId == null ? '' : 'AND category_id = ? '}'
          'GROUP BY lower(note), category_id '
          'ORDER BY c DESC, last DESC, lower(note) '
          'LIMIT ?',
          variables: [
            Variable.withString(type),
            Variable.withString('$escaped%'),
            if (categoryId != null) Variable.withString(categoryId),
            Variable.withInt(limit * 3),
          ],
          readsFrom: {_db.transactions},
        )
        .get();
    final seen = <String>{};
    final result = <NoteSuggestion>[];
    for (final r in rows) {
      final note = r.read<String>('note');
      if (!seen.add(note.toLowerCase())) continue;
      result.add(
        NoteSuggestion(note, r.read<String>('category_id'), r.read<int>('c')),
      );
      if (result.length == limit) break;
    }
    return result;
  }

  /// Lower-case note -> the category it was used for most often.
  Future<Map<String, String>> knownNotes(String type) async {
    final rows = await _db
        .customSelect(
          'SELECT lower(note) AS n, category_id, COUNT(*) AS c '
          'FROM transactions '
          "WHERE deleted_at IS NULL AND type = ? AND note <> '' "
          'GROUP BY lower(note), category_id ORDER BY c DESC',
          variables: [Variable.withString(type)],
          readsFrom: {_db.transactions},
        )
        .get();
    final map = <String, String>{};
    for (final r in rows) {
      map.putIfAbsent(r.read<String>('n'), () => r.read<String>('category_id'));
    }
    return map;
  }

  /// The last few different entries of [type], newest first, so "repeat"
  /// can offer them again.
  Future<List<TxRow>> recentDistinct(String type, {int limit = 3}) async {
    final rows =
        await (_db.select(_db.transactions)
              ..where((t) => t.type.equals(type) & t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.desc(t.occurredOn),
                (t) => OrderingTerm.desc(t.updatedAt),
              ])
              ..limit(40))
            .get();
    final seen = <String>{};
    final result = <TxRow>[];
    for (final r in rows) {
      final key = '${r.note.toLowerCase()}|${r.categoryId}|${r.amountMinor}';
      if (!seen.add(key)) continue;
      result.add(r);
      if (result.length == limit) break;
    }
    return result;
  }

  /// Copies an entry (with its wallet and tags) to [date], today by default.
  /// The receipt photo and split group are not copied. Returns the new id.
  Future<String> duplicate(String id, {DateTime? date}) async {
    final source = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
    final links = await (_db.select(
      _db.transactionTags,
    )..where((l) => l.transactionId.equals(id) & l.deletedAt.isNull())).get();
    final now = date ?? DateTime.now();
    return add(
      type: source.type,
      amountMinor: source.amountMinor,
      currency: source.currency,
      categoryId: source.categoryId,
      note: source.note,
      date: DateTime(now.year, now.month, now.day),
      walletId: source.walletId,
      tagIds: {for (final l in links) l.tagId},
    );
  }

  /// Deletes are soft, so they can be undone and later synced.
  Future<void> softDelete(String id) => _setDeleted(id, DateTime.now());

  Future<void> restore(String id) => _setDeleted(id, null);

  Future<void> _setDeleted(String id, DateTime? at) async {
    await _db.transaction(() async {
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          deletedAt: Value(at),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('transactions', id, at == null ? 'upsert' : 'delete');
    });
  }
}
