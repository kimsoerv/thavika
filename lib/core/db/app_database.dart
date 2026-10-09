import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

/// Columns shared by every table that will be synced to Supabase.
mixin SyncColumns on Table {
  TextColumn get ownerId => text().nullable()();
  TextColumn get householdId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
}

@DataClassName('CategoryRow')
class Categories extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();

  /// 'expense' or 'income'
  TextColumn get kind => text()();

  /// 'needs', 'wants', 'savings', 'income' or 'other'
  TextColumn get groupName => text().withDefault(const Constant('other'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// Hidden categories are not offered when adding entries, but old entries keep them.
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TxRow')
class Transactions extends Table with SyncColumns {
  TextColumn get id => text()();

  /// 'expense' or 'income'
  TextColumn get type => text()();

  /// Money in minor units (cents). Never a double.
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredOn => dateTime()();
  TextColumn get createdBy => text().nullable()();

  /// The wallet the money went in or out of.
  TextColumn get walletId => text().nullable()();

  /// File name of a receipt photo kept on this phone.
  TextColumn get receiptPath => text().nullable()();

  /// Entries created by splitting one purchase share this id.
  TextColumn get splitGroup => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get settingKey => text()();
  TextColumn get settingValue => text()();

  @override
  Set<Column> get primaryKey => {settingKey};
}

/// Queue of local changes waiting to be uploaded (used from the sync step on).
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text()();
  TextColumn get rowId => text()();

  /// 'upsert' or 'delete'
  TextColumn get op => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

/// The active spending plan (one at a time; replaced when the user saves a new one).
@DataClassName('PlanRow')
class Plans extends Table with SyncColumns {
  TextColumn get id => text()();

  /// 'balanced', 'seventy', 'eighty' or 'custom'
  TextColumn get template => text()();
  IntColumn get incomeMinor => integer()();
  TextColumn get currency => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Optional name ("Our family plan").
  TextColumn get name => text().nullable()();

  /// First month this plan applies to. Null means it is only saved in the
  /// library. A month uses the latest plan that started on or before it, so
  /// changing the plan never rewrites earlier months.
  DateTimeColumn get activeFrom => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlanItemRow')
class PlanItems extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get planId => text().references(Plans, #id)();

  /// 'needs', 'wants', 'savings', 'giving' or 'spending'
  TextColumn get groupName => text()();

  /// Display name, or a key such as 'emergency_fund' for built-in items.
  TextColumn get name => text()();

  /// Expense category this budget is checked against (null for savings etc.).
  TextColumn get categoryId => text().nullable()();
  IntColumn get amountMinor => integer()();

  /// Fixed bills (rent) are not judged against the daily pace.
  BoolColumn get isFixed => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A savings goal ("New phone", "Emergency fund"). The saved amount is the
/// sum of its contributions.
@DataClassName('GoalRow')
class Goals extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get targetMinor => integer()();
  TextColumn get currency => text()();

  /// Optional date the user wants to reach the target by.
  DateTimeColumn get targetDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GoalContributionRow')
class GoalContributions extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get goalId => text().references(Goals, #id)();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get occurredOn => dateTime()();

  /// If set, the money leaves this wallet when added to the goal.
  TextColumn get walletId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// An entry that repeats by itself (salary, rent, a subscription).
@DataClassName('RecurringRow')
class RecurringRules extends Table with SyncColumns {
  TextColumn get id => text()();

  /// 'expense' or 'income'
  TextColumn get type => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// 'weekly' or 'monthly'
  TextColumn get frequency => text()();

  /// First date; its day of the month (or weekday) is the anchor.
  DateTimeColumn get startOn => dateTime()();

  /// The next date an entry is due.
  DateTimeColumn get nextRunOn => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Shown in the bills tracker with a reminder before it is due.
  BoolColumn get isBill => boolean().withDefault(const Constant(false))();

  /// False for bills whose amount changes: the user marks them paid instead.
  BoolColumn get autoCreate => boolean().withDefault(const Constant(true))();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(2))();
  TextColumn get walletId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Where money is kept: cash, a bank account, an e-wallet.
@DataClassName('WalletRow')
class Wallets extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('wallet'))();

  /// 'cash', 'bank', 'ewallet' or 'other'
  TextColumn get kind => text().withDefault(const Constant('cash'))();

  /// Money in the wallet before the first entry.
  IntColumn get openingMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Money moved between two wallets. Not income or spending.
@DataClassName('TransferRow')
class Transfers extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get fromWalletId => text()();
  TextColumn get toWalletId => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  DateTimeColumn get occurredOn => dateTime()();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Links an entry to a tag. The id is made from both ids, so two phones
/// that add the same tag to the same entry end up with one row.
@DataClassName('TransactionTagRow')
class TransactionTags extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Money lent to someone, or borrowed from someone.
@DataClassName('DebtRow')
class Debts extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get person => text()();

  /// 'lent' (they owe me) or 'borrowed' (I owe them)
  TextColumn get direction => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get startedOn => dateTime()();
  DateTimeColumn get dueOn => dateTime().nullable()();

  /// The wallet the money left from (lent) or came into (borrowed).
  TextColumn get walletId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DebtPaymentRow')
class DebtPayments extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get debtId => text()();
  IntColumn get amountMinor => integer()();
  DateTimeColumn get occurredOn => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A savings challenge (for example 52 weeks) attached to a goal.
@DataClassName('ChallengeRow')
class Challenges extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get goalId => text()();

  /// 'weekly' (step n saves n x unit) or 'fixed' (every step saves the unit)
  TextColumn get kind => text()();
  IntColumn get unitMinor => integer()();
  IntColumn get steps => integer()();
  DateTimeColumn get startOn => dateTime()();

  /// Completed step numbers, comma separated ("1,2,3").
  TextColumn get completedSteps => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class _DefaultCategory {
  const _DefaultCategory(
    this.id,
    this.name,
    this.icon,
    this.kind,
    this.group,
    this.order,
  );

  final String id;
  final String name;
  final String icon;
  final String kind;
  final String group;
  final int order;
}

const _defaultCategories = <_DefaultCategory>[
  _DefaultCategory('cat_housing', 'Housing', 'home', 'expense', 'needs', 10),
  _DefaultCategory('cat_food', 'Food', 'restaurant', 'expense', 'needs', 20),
  _DefaultCategory(
    'cat_transport',
    'Transport',
    'directions_bus',
    'expense',
    'needs',
    30,
  ),
  _DefaultCategory(
    'cat_bills',
    'Bills',
    'receipt_long',
    'expense',
    'needs',
    40,
  ),
  _DefaultCategory('cat_health', 'Health', 'favorite', 'expense', 'needs', 50),
  _DefaultCategory('cat_family', 'Family', 'people', 'expense', 'needs', 60),
  _DefaultCategory(
    'cat_shopping',
    'Shopping',
    'shopping_cart',
    'expense',
    'wants',
    70,
  ),
  _DefaultCategory('cat_fun', 'Fun', 'movie', 'expense', 'wants', 80),
  _DefaultCategory('cat_personal', 'Personal', 'spa', 'expense', 'wants', 90),
  _DefaultCategory('cat_other', 'Other', 'more_horiz', 'expense', 'other', 100),
  _DefaultCategory('cat_salary', 'Salary', 'payments', 'income', 'income', 10),
  _DefaultCategory(
    'cat_bonus',
    'Bonus',
    'card_giftcard',
    'income',
    'income',
    20,
  ),
  _DefaultCategory(
    'cat_other_income',
    'Other income',
    'add_circle',
    'income',
    'income',
    30,
  ),
];

@DriftDatabase(
  tables: [
    Categories,
    Transactions,
    AppSettings,
    Outbox,
    Plans,
    PlanItems,
    Goals,
    GoalContributions,
    RecurringRules,
    Wallets,
    Transfers,
    Tags,
    TransactionTags,
    Debts,
    DebtPayments,
    Challenges,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'thavika'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
      await _createDefaultWallet('USD');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(plans);
        await m.createTable(planItems);
      }
      if (from < 3) {
        await m.createTable(goals);
        await m.createTable(goalContributions);
        await m.createTable(recurringRules);
      }
      if (from < 4) {
        await m.addColumn(categories, categories.isHidden);
        await m.addColumn(transactions, transactions.walletId);
        await m.addColumn(transactions, transactions.receiptPath);
        await m.addColumn(transactions, transactions.splitGroup);
        await m.addColumn(plans, plans.name);
        await m.addColumn(plans, plans.activeFrom);
        await m.addColumn(recurringRules, recurringRules.isBill);
        await m.addColumn(recurringRules, recurringRules.autoCreate);
        await m.addColumn(recurringRules, recurringRules.remindDaysBefore);
        await m.addColumn(recurringRules, recurringRules.walletId);
        await m.addColumn(goalContributions, goalContributions.walletId);
        await m.createTable(wallets);
        await m.createTable(transfers);
        await m.createTable(tags);
        await m.createTable(transactionTags);
        await m.createTable(debts);
        await m.createTable(debtPayments);
        await m.createTable(challenges);
        await _moveExistingDataToWallet();
      }
      if (from >= 4 && from < 5) {
        await m.addColumn(debts, debts.walletId);
      }
    },
  );

  /// Version 4 added wallets: everything entered before belongs to one
  /// "Cash" wallet, and the current plan becomes the plan of this month.
  Future<void> _moveExistingDataToWallet() async {
    final saved = await (select(
      appSettings,
    )..where((s) => s.settingKey.equals('currency'))).getSingleOrNull();
    final walletId = await _createDefaultWallet(saved?.settingValue ?? 'USD');

    await (update(transactions)..where((t) => t.walletId.isNull())).write(
      TransactionsCompanion(walletId: Value(walletId)),
    );
    await (update(recurringRules)..where((r) => r.walletId.isNull())).write(
      RecurringRulesCompanion(walletId: Value(walletId)),
    );

    final now = DateTime.now();
    await (update(plans)..where(
          (p) =>
              p.activeFrom.isNull() &
              p.deletedAt.isNull() &
              p.isActive.equals(true),
        ))
        .write(
          PlansCompanion(activeFrom: Value(DateTime(now.year, now.month))),
        );
  }

  Future<String> _createDefaultWallet(String currency) async {
    final id = const Uuid().v4();
    await into(wallets).insert(
      WalletsCompanion.insert(
        id: id,
        name: 'Cash',
        currency: currency,
        updatedAt: DateTime.now(),
      ),
    );
    return id;
  }

  /// The wallet used when none is chosen: the first one that is not archived.
  Future<String?> defaultWalletId() async {
    final row =
        await (select(wallets)
              ..where((w) => w.deletedAt.isNull() & w.isArchived.equals(false))
              ..orderBy([
                (w) => OrderingTerm.asc(w.sortOrder),
                (w) => OrderingTerm.asc(w.updatedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  Future<void> _seedCategories() async {
    final now = DateTime.now();
    await batch((b) {
      b.insertAll(
        categories,
        _defaultCategories.map(
          (c) => CategoriesCompanion.insert(
            id: c.id,
            name: c.name,
            icon: c.icon,
            kind: c.kind,
            groupName: Value(c.group),
            sortOrder: Value(c.order),
            isDefault: const Value(true),
            updatedAt: now,
          ),
        ),
      );
    });
  }

  /// Adds a change to the outbox. Call it inside the same database
  /// transaction that writes the row.
  Future<void> enqueue(String table, String rowId, String op) {
    return into(outbox).insert(
      OutboxCompanion.insert(
        targetTable: table,
        rowId: rowId,
        op: op,
        createdAt: DateTime.now(),
      ),
    );
  }
}
