import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../tags/data/tag_repository.dart';
import '../domain/household.dart';

/// Everything about households that happens on the phone: remembering the
/// household, and what to do with the data when the person is no longer in it.
class HouseholdLocal {
  HouseholdLocal(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// The household as last seen from the server, kept so the screens can show
  /// it without internet. Cleared when another account signs in.
  static const cacheKey = 'household_cache';

  /// The tables that carry `household_id`, as named in the database.
  static const _tableNames = [
    'transaction_tags',
    'transactions',
    'transfers',
    'goal_contributions',
    'challenges',
    'goals',
    'plan_items',
    'plans',
    'recurring_rules',
    'debt_payments',
    'debts',
    'tags',
    'wallets',
    'categories',
  ];

  // ---- the remembered household ----

  Future<HouseholdInfo?> cached() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.settingKey.equals(cacheKey))).getSingleOrNull();
    return HouseholdInfo.decode(row?.settingValue);
  }

  Future<void> saveCache(HouseholdInfo info) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          settingKey: cacheKey,
          settingValue: info.encode(),
        ),
      );

  Future<void> clearCache() => (_db.delete(
    _db.appSettings,
  )..where((s) => s.settingKey.equals(cacheKey))).go();

  // ---- when the household ended with this person as its last member ----

  /// Everything the household had is now [me]'s own. The server has done the
  /// same, so nothing needs uploading.
  Future<void> becomePersonal(String me) async {
    await _db.transaction(() async {
      for (final t in _tableNames) {
        await _db.customStatement(
          'UPDATE $t SET household_id = NULL, owner_id = ? '
          'WHERE household_id IS NOT NULL',
          [me],
        );
      }
    });
  }

  // ---- when this person leaves, or is removed ----

  /// The household keeps what is in it. On this phone that means: make a
  /// personal copy of what [me] added (their entries, and the plan in use),
  /// then remove the household's rows. The copies are queued for upload.
  ///
  /// [currency] is used if the phone is left without a wallet.
  Future<void> detach(
    String me, {
    required bool copyMine,
    required String currency,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    await _db.transaction(() async {
      if (copyMine) await _copyMine(me, stamp);
      await _purge();
      await _db.ensureDefaultWallet(currency);
    });
  }

  Future<void> _copyMine(String me, DateTime stamp) async {
    final categoryIds = <String, String>{};
    final walletIds = <String, String?>{};
    final tagIds = <String, String?>{};
    final splitGroups = <String, String>{};

    Future<String> mapCategory(String id) async {
      final known = categoryIds[id];
      if (known != null) return known;
      final row = await (_db.select(
        _db.categories,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      // Built-in and personal categories are the same on every phone.
      if (row == null || row.isDefault || row.householdId == null) {
        return categoryIds[id] = id;
      }
      final copy = _uuid.v4();
      await _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: copy,
              name: row.name,
              icon: row.icon,
              kind: row.kind,
              groupName: Value(row.groupName),
              sortOrder: Value(row.sortOrder),
              isHidden: Value(row.isHidden),
              ownerId: Value(me),
              updatedAt: stamp,
            ),
          );
      await _db.enqueue('categories', copy, 'upsert');
      return categoryIds[id] = copy;
    }

    Future<String?> mapWallet(String? id) async {
      if (id == null) return null;
      if (walletIds.containsKey(id)) return walletIds[id];
      final row = await (_db.select(
        _db.wallets,
      )..where((w) => w.id.equals(id))).getSingleOrNull();
      if (row == null || row.deletedAt != null) return walletIds[id] = null;
      if (row.householdId == null) return walletIds[id] = id;
      final copy = _uuid.v4();
      await _db
          .into(_db.wallets)
          .insert(
            WalletsCompanion.insert(
              id: copy,
              name: row.name,
              currency: row.currency,
              icon: Value(row.icon),
              kind: Value(row.kind),
              // Only the leaver's own wallets bring their opening balance;
              // a partner's wallet would count the same money twice.
              openingMinor: Value(row.ownerId == me ? row.openingMinor : 0),
              sortOrder: Value(row.sortOrder),
              isArchived: Value(row.isArchived),
              ownerId: Value(me),
              updatedAt: stamp,
            ),
          );
      await _db.enqueue('wallets', copy, 'upsert');
      return walletIds[id] = copy;
    }

    Future<String?> mapTag(String id) async {
      if (tagIds.containsKey(id)) return tagIds[id];
      final row = await (_db.select(
        _db.tags,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null || row.deletedAt != null) return tagIds[id] = null;
      if (row.householdId == null) return tagIds[id] = id;
      final copy = _uuid.v4();
      await _db
          .into(_db.tags)
          .insert(
            TagsCompanion.insert(
              id: copy,
              name: row.name,
              colorIndex: Value(row.colorIndex),
              ownerId: Value(me),
              updatedAt: stamp,
            ),
          );
      await _db.enqueue('tags', copy, 'upsert');
      return tagIds[id] = copy;
    }

    // The entries this person added.
    final mine =
        await (_db.select(_db.transactions)..where(
              (t) =>
                  t.householdId.isNotNull() &
                  t.ownerId.equals(me) &
                  t.deletedAt.isNull(),
            ))
            .get();
    for (final tx in mine) {
      final copy = _uuid.v4();
      final group = tx.splitGroup;
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: copy,
              type: tx.type,
              amountMinor: tx.amountMinor,
              currency: tx.currency,
              categoryId: await mapCategory(tx.categoryId),
              occurredOn: tx.occurredOn,
              note: Value(tx.note),
              createdBy: Value(tx.createdBy),
              walletId: Value(await mapWallet(tx.walletId)),
              receiptPath: Value(tx.receiptPath),
              splitGroup: Value(
                group == null ? null : splitGroups.putIfAbsent(group, _uuid.v4),
              ),
              ownerId: Value(me),
              updatedAt: stamp,
            ),
          );
      await _db.enqueue('transactions', copy, 'upsert');

      final links =
          await (_db.select(_db.transactionTags)..where(
                (l) => l.transactionId.equals(tx.id) & l.deletedAt.isNull(),
              ))
              .get();
      for (final link in links) {
        final tag = await mapTag(link.tagId);
        if (tag == null) continue;
        final linkId = TagRepository.linkId(copy, tag);
        await _db
            .into(_db.transactionTags)
            .insert(
              TransactionTagsCompanion.insert(
                id: linkId,
                transactionId: copy,
                tagId: tag,
                ownerId: Value(me),
                updatedAt: stamp,
              ),
            );
        await _db.enqueue('transaction_tags', linkId, 'upsert');
      }
    }

    // The plan the household uses this month, as a personal plan.
    final first = DateTime(stamp.year, stamp.month);
    final plan =
        await (_db.select(_db.plans)
              ..where(
                (p) =>
                    p.householdId.isNotNull() &
                    p.deletedAt.isNull() &
                    p.activeFrom.isNotNull() &
                    p.activeFrom.isSmallerOrEqualValue(first),
              )
              ..orderBy([
                (p) => OrderingTerm.desc(p.activeFrom),
                (p) => OrderingTerm.desc(p.updatedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (plan != null) {
      final copy = _uuid.v4();
      await _db
          .into(_db.plans)
          .insert(
            PlansCompanion.insert(
              id: copy,
              template: plan.template,
              incomeMinor: plan.incomeMinor,
              currency: plan.currency,
              isActive: Value(plan.isActive),
              name: Value(plan.name),
              activeFrom: Value(plan.activeFrom),
              ownerId: Value(me),
              updatedAt: stamp,
            ),
          );
      await _db.enqueue('plans', copy, 'upsert');

      final items = await (_db.select(
        _db.planItems,
      )..where((i) => i.planId.equals(plan.id) & i.deletedAt.isNull())).get();
      for (final item in items) {
        final itemCopy = _uuid.v4();
        final category = item.categoryId;
        await _db
            .into(_db.planItems)
            .insert(
              PlanItemsCompanion.insert(
                id: itemCopy,
                planId: copy,
                groupName: item.groupName,
                name: item.name,
                categoryId: Value(
                  category == null ? null : await mapCategory(category),
                ),
                amountMinor: item.amountMinor,
                isFixed: Value(item.isFixed),
                sortOrder: Value(item.sortOrder),
                ownerId: Value(me),
                updatedAt: stamp,
              ),
            );
        await _db.enqueue('plan_items', itemCopy, 'upsert');
      }
    }
  }

  /// Removes everything that belongs to the household from this phone, and
  /// the uploads still waiting for it.
  Future<void> _purge() async {
    for (final t in _tableNames) {
      if (t == 'categories') {
        await _db.customStatement(
          'DELETE FROM $t WHERE household_id IS NOT NULL AND is_default = 0',
        );
      } else {
        await _db.customStatement(
          'DELETE FROM $t WHERE household_id IS NOT NULL',
        );
      }
      await _db.customStatement(
        'DELETE FROM outbox WHERE target_table = ? '
        'AND row_id NOT IN (SELECT id FROM $t)',
        [t],
      );
    }
  }
}
