import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';

class WalletRepository {
  WalletRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<WalletRow>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.wallets)
      ..where(
        (w) =>
            w.deletedAt.isNull() &
            (includeArchived
                ? const Constant(true)
                : w.isArchived.equals(false)),
      )
      ..orderBy([
        (w) => OrderingTerm.asc(w.sortOrder),
        (w) => OrderingTerm.asc(w.updatedAt),
      ]);
    return query.watch();
  }

  Future<String?> defaultWalletId() => _db.defaultWalletId();

  /// Current money in each wallet: the opening amount, plus income, minus
  /// spending, plus transfers in, minus transfers out, minus money moved
  /// into goals from the wallet.
  Stream<Map<String, int>> watchBalances() {
    return _db
        .customSelect(
          '''
SELECT w.id AS id,
  w.opening_minor
  + COALESCE((SELECT SUM(CASE t.type WHEN 'income' THEN t.amount_minor ELSE -t.amount_minor END)
              FROM transactions t WHERE t.wallet_id = w.id AND t.deleted_at IS NULL), 0)
  + COALESCE((SELECT SUM(x.amount_minor) FROM transfers x
              WHERE x.to_wallet_id = w.id AND x.deleted_at IS NULL), 0)
  - COALESCE((SELECT SUM(x.amount_minor) FROM transfers x
              WHERE x.from_wallet_id = w.id AND x.deleted_at IS NULL), 0)
  - COALESCE((SELECT SUM(g.amount_minor) FROM goal_contributions g
              WHERE g.wallet_id = w.id AND g.deleted_at IS NULL), 0)
  - COALESCE((SELECT SUM(d.amount_minor) FROM debts d
              WHERE d.wallet_id = w.id AND d.direction = 'lent' AND d.deleted_at IS NULL), 0)
  + COALESCE((SELECT SUM(d.amount_minor) FROM debts d
              WHERE d.wallet_id = w.id AND d.direction = 'borrowed' AND d.deleted_at IS NULL), 0)
  + COALESCE((SELECT SUM(CASE d.direction WHEN 'lent' THEN p.amount_minor ELSE -p.amount_minor END)
              FROM debt_payments p JOIN debts d ON d.id = p.debt_id
              WHERE d.wallet_id = w.id AND d.deleted_at IS NULL AND p.deleted_at IS NULL), 0) AS balance
FROM wallets w
WHERE w.deleted_at IS NULL
''',
          readsFrom: {
            _db.wallets,
            _db.transactions,
            _db.transfers,
            _db.goalContributions,
            _db.debts,
            _db.debtPayments,
          },
        )
        .watch()
        .map(
          (rows) => {
            for (final r in rows) r.read<String>('id'): r.read<int>('balance'),
          },
        );
  }

  Future<String> add({
    required String name,
    required String currency,
    String kind = 'cash',
    String icon = 'wallet',
    int openingMinor = 0,
  }) async {
    final id = _uuid.v4();
    await _db.transaction(() async {
      final count = await (_db.select(_db.wallets)).get();
      await _db
          .into(_db.wallets)
          .insert(
            WalletsCompanion.insert(
              id: id,
              name: name,
              currency: currency,
              kind: Value(kind),
              icon: Value(icon),
              openingMinor: Value(openingMinor),
              sortOrder: Value(count.length),
              updatedAt: DateTime.now(),
            ),
          );
      await _db.enqueue('wallets', id, 'upsert');
    });
    return id;
  }

  Future<void> update(
    String id, {
    required String name,
    required String kind,
    required String icon,
    required int openingMinor,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.wallets)..where((w) => w.id.equals(id))).write(
        WalletsCompanion(
          name: Value(name),
          kind: Value(kind),
          icon: Value(icon),
          openingMinor: Value(openingMinor),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('wallets', id, 'upsert');
    });
  }

  /// An archived wallet is hidden from pickers but keeps its history.
  Future<void> setArchived(String id, bool archived) async {
    await _db.transaction(() async {
      await (_db.update(_db.wallets)..where((w) => w.id.equals(id))).write(
        WalletsCompanion(
          isArchived: Value(archived),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('wallets', id, 'upsert');
    });
  }

  /// Deletes a wallet. Its entries, recurring entries, goal money and
  /// transfers move to [moveTo]. A transfer that ends up between a wallet
  /// and itself is removed.
  Future<void> delete(String id, {required String moveTo}) async {
    if (id == moveTo) {
      throw ArgumentError('Pick a different wallet to move to.');
    }
    final now = DateTime.now();
    await _db.transaction(() async {
      final txs = await (_db.select(
        _db.transactions,
      )..where((t) => t.walletId.equals(id))).get();
      for (final t in txs) {
        await (_db.update(
          _db.transactions,
        )..where((x) => x.id.equals(t.id))).write(
          TransactionsCompanion(
            walletId: Value(moveTo),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('transactions', t.id, 'upsert');
      }

      final rules = await (_db.select(
        _db.recurringRules,
      )..where((r) => r.walletId.equals(id))).get();
      for (final r in rules) {
        await (_db.update(
          _db.recurringRules,
        )..where((x) => x.id.equals(r.id))).write(
          RecurringRulesCompanion(
            walletId: Value(moveTo),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('recurring_rules', r.id, 'upsert');
      }

      final goals = await (_db.select(
        _db.goalContributions,
      )..where((g) => g.walletId.equals(id))).get();
      for (final g in goals) {
        await (_db.update(
          _db.goalContributions,
        )..where((x) => x.id.equals(g.id))).write(
          GoalContributionsCompanion(
            walletId: Value(moveTo),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('goal_contributions', g.id, 'upsert');
      }

      final debtRows = await (_db.select(
        _db.debts,
      )..where((d) => d.walletId.equals(id))).get();
      for (final d in debtRows) {
        await (_db.update(_db.debts)..where((x) => x.id.equals(d.id))).write(
          DebtsCompanion(
            walletId: Value(moveTo),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('debts', d.id, 'upsert');
      }

      final moves =
          await (_db.select(_db.transfers)..where(
                (t) =>
                    (t.fromWalletId.equals(id) | t.toWalletId.equals(id)) &
                    t.deletedAt.isNull(),
              ))
              .get();
      for (final t in moves) {
        final from = t.fromWalletId == id ? moveTo : t.fromWalletId;
        final to = t.toWalletId == id ? moveTo : t.toWalletId;
        final pointless = from == to;
        await (_db.update(
          _db.transfers,
        )..where((x) => x.id.equals(t.id))).write(
          TransfersCompanion(
            fromWalletId: Value(from),
            toWalletId: Value(to),
            deletedAt: pointless ? Value(now) : const Value.absent(),
            updatedAt: Value(now),
            syncState: const Value('pending'),
          ),
        );
        await _db.enqueue('transfers', t.id, 'upsert');
      }

      await (_db.update(_db.wallets)..where((w) => w.id.equals(id))).write(
        WalletsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('wallets', id, 'delete');
    });
  }
}
