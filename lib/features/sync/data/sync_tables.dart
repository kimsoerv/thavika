import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

/// One synced table, seen the same way whatever its columns are.
abstract class SyncTable {
  String get name;

  /// Local rows with these ids, as Drift JSON. Rows that must never leave
  /// the phone (built-in categories) are left out.
  Future<List<Map<String, dynamic>>> rowsByIds(
    AppDatabase db,
    List<String> ids,
  );

  /// Inserts or replaces a row from Drift JSON.
  Future<void> upsert(AppDatabase db, Map<String, dynamic> json);

  /// `updated_at` of the local row, in whole seconds, or null if absent.
  Future<int?> updatedAtSeconds(AppDatabase db, String id);

  /// Marks a row as synced if it was not edited since [updatedAtSeconds].
  Future<void> markSynced(
    AppDatabase db,
    String id,
    int updatedAtSeconds,
    String userId,
  );

  /// Gives every row that has no owner to [userId] and queues it for upload.
  Future<void> adoptAll(AppDatabase db, String userId);

  /// How many rows of this table the user created.
  Future<int> userRowCount(AppDatabase db);
}

class _Table<T extends Table, D extends DataClass> implements SyncTable {
  _Table(
    this.name,
    this.table,
    this.fromJson, {
    this.skipWhere = '',
    this.userRowsWhere = '1 = 1',
  });

  @override
  final String name;
  final TableInfo<T, D> table;
  final D Function(Map<String, dynamic>) fromJson;

  /// SQL condition for rows that are never synced (built-in categories).
  final String skipWhere;
  final String userRowsWhere;

  GeneratedColumn<String> get _id =>
      table.columnsByName['id']! as GeneratedColumn<String>;

  @override
  Future<List<Map<String, dynamic>>> rowsByIds(
    AppDatabase db,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final rows = await (db.select(table)..where((_) => _id.isIn(ids))).get();
    final json = [for (final r in rows) r.toJson()];
    if (name == 'categories') {
      return json.where((j) => j['isDefault'] != true).toList();
    }
    return json;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> json) async {
    final row = fromJson(json) as Insertable<D>;
    await db.into(table).insertOnConflictUpdate(row);
  }

  @override
  Future<int?> updatedAtSeconds(AppDatabase db, String id) async {
    final row = await db
        .customSelect(
          'SELECT updated_at AS u FROM $name WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    return row?.read<int>('u');
  }

  @override
  Future<void> markSynced(
    AppDatabase db,
    String id,
    int updatedAtSeconds,
    String userId,
  ) {
    return db.customStatement(
      "UPDATE $name SET sync_state = 'synced', owner_id = ? "
      'WHERE id = ? AND updated_at = ?',
      [userId, id, updatedAtSeconds],
    );
  }

  @override
  Future<void> adoptAll(AppDatabase db, String userId) async {
    final skip = skipWhere.isEmpty ? '' : ' AND NOT ($skipWhere)';
    await db.customStatement(
      'UPDATE $name SET owner_id = ? WHERE owner_id IS NULL$skip',
      [userId],
    );
    await db.customStatement(
      'INSERT INTO outbox (target_table, row_id, op, created_at, attempts) '
      "SELECT '$name', id, 'upsert', ?, 0 FROM $name WHERE 1 = 1$skip",
      [DateTime.now().millisecondsSinceEpoch ~/ 1000],
    );
  }

  @override
  Future<int> userRowCount(AppDatabase db) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM $name '
          'WHERE deleted_at IS NULL AND ($userRowsWhere)',
        )
        .getSingle();
    return row.read<int>('c');
  }
}

/// All synced tables, parents before children so a pulled row never points
/// at something that has not arrived yet.
List<SyncTable> buildSyncTables(AppDatabase db) => [
  _Table(
    'categories',
    db.categories,
    CategoryRow.fromJson,
    skipWhere: 'is_default = 1',
    userRowsWhere: 'is_default = 0',
  ),
  _Table('wallets', db.wallets, WalletRow.fromJson),
  _Table('tags', db.tags, TagRow.fromJson),
  _Table('goals', db.goals, GoalRow.fromJson),
  _Table('plans', db.plans, PlanRow.fromJson),
  _Table('plan_items', db.planItems, PlanItemRow.fromJson),
  _Table(
    'goal_contributions',
    db.goalContributions,
    GoalContributionRow.fromJson,
  ),
  _Table('challenges', db.challenges, ChallengeRow.fromJson),
  _Table('recurring_rules', db.recurringRules, RecurringRow.fromJson),
  _Table('transactions', db.transactions, TxRow.fromJson),
  _Table('transaction_tags', db.transactionTags, TransactionTagRow.fromJson),
  _Table('transfers', db.transfers, TransferRow.fromJson),
  _Table('debts', db.debts, DebtRow.fromJson),
  _Table('debt_payments', db.debtPayments, DebtPaymentRow.fromJson),
];
