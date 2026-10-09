import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';

class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One entry of an export, with names instead of ids.
class ExportRow {
  const ExportRow({
    required this.date,
    required this.type,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.wallet,
    required this.tags,
    required this.note,
  });

  final DateTime date;
  final String type;
  final String category;
  final int amountMinor;
  final String currency;
  final String wallet;
  final String tags;
  final String note;

  double get amount =>
      amountMinor / pow(10, Money.decimalsFor(currency)).toDouble();

  String get amountText => amount.toStringAsFixed(Money.decimalsFor(currency));
}

/// Exports entries as CSV and Excel and backs up / restores the whole database as JSON.
class BackupService {
  BackupService(this._db, this._settings);

  final AppDatabase _db;
  final SettingsService _settings;

  static const backupApp = 'thavika';

  /// 1: first version. 2: adds wallets, transfers, tags, debts, challenges
  /// and the new columns. Older backups are still accepted.
  static const backupVersion = 2;

  /// The entries with `from <= date < to` (all when omitted), with names
  /// instead of ids, oldest first. Empty when there are none.
  Future<List<ExportRow>> _exportRows({DateTime? from, DateTime? to}) async {
    final t = _db.transactions;
    final query = _db.select(t)..where((e) => e.deletedAt.isNull());
    if (from != null) {
      query.where((e) => e.occurredOn.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((e) => e.occurredOn.isSmallerThanValue(to));
    }
    query.orderBy([(e) => OrderingTerm.asc(e.occurredOn)]);
    final rows = await query.get();
    if (rows.isEmpty) return const [];

    final categories = {
      for (final c in await _db.select(_db.categories).get()) c.id: c.name,
    };
    final wallets = {
      for (final w in await _db.select(_db.wallets).get()) w.id: w.name,
    };
    final tagNames = {
      for (final t in await _db.select(_db.tags).get()) t.id: t.name,
    };
    final tagsByEntry = <String, List<String>>{};
    for (final l in await (_db.select(
      _db.transactionTags,
    )..where((l) => l.deletedAt.isNull())).get()) {
      final name = tagNames[l.tagId];
      if (name != null) (tagsByEntry[l.transactionId] ??= []).add(name);
    }

    return [
      for (final r in rows)
        ExportRow(
          date: r.occurredOn,
          type: r.type,
          category: categories[r.categoryId] ?? '',
          amountMinor: r.amountMinor,
          currency: r.currency,
          wallet: wallets[r.walletId] ?? '',
          tags: (tagsByEntry[r.id] ?? const []).join(' '),
          note: r.note,
        ),
    ];
  }

  /// CSV of the entries with `from <= date < to` (all entries when omitted).
  /// Returns null when there is nothing to export.
  Future<String?> buildCsv({DateTime? from, DateTime? to}) async {
    final rows = await _exportRows(from: from, to: to);
    if (rows.isEmpty) return null;

    final day = DateFormat('yyyy-MM-dd');
    final buffer = StringBuffer(
      'date,type,category,amount,currency,wallet,tags,note\n',
    );
    for (final r in rows) {
      buffer.writeln(
        [
          day.format(r.date),
          r.type,
          _csvCell(r.category),
          r.amountText,
          r.currency,
          _csvCell(r.wallet),
          _csvCell(r.tags),
          _csvCell(r.note),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  /// An Excel workbook of the entries with `from <= date < to`: one sheet
  /// with every entry (amounts are real numbers, so sums and charts work)
  /// and one with the totals per category. Null when there is nothing.
  Future<List<int>?> buildXlsx({DateTime? from, DateTime? to}) async {
    final rows = await _exportRows(from: from, to: to);
    if (rows.isEmpty) return null;

    final book = Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();
    final entries = book['Entries'];
    entries.appendRow([
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Currency'),
      TextCellValue('Wallet'),
      TextCellValue('Tags'),
      TextCellValue('Note'),
    ]);
    final totals = <String, double>{};
    for (final r in rows) {
      entries.appendRow([
        DateCellValue(year: r.date.year, month: r.date.month, day: r.date.day),
        TextCellValue(r.type),
        TextCellValue(r.category),
        DoubleCellValue(r.amount),
        TextCellValue(r.currency),
        TextCellValue(r.wallet),
        TextCellValue(r.tags),
        TextCellValue(r.note),
      ]);
      final key = '${r.type}\u0000${r.category}\u0000${r.currency}';
      totals[key] = (totals[key] ?? 0) + r.amount;
    }

    final summary = book['By category'];
    summary.appendRow([
      TextCellValue('Type'),
      TextCellValue('Category'),
      TextCellValue('Total'),
      TextCellValue('Currency'),
    ]);
    final keys = totals.keys.toList()..sort();
    for (final key in keys) {
      final parts = key.split('\u0000');
      summary.appendRow([
        TextCellValue(parts[0]),
        TextCellValue(parts[1]),
        DoubleCellValue(double.parse(totals[key]!.toStringAsFixed(2))),
        TextCellValue(parts[2]),
      ]);
    }

    if (defaultSheet != null && defaultSheet != 'Entries') {
      book.delete(defaultSheet);
    }
    book.setDefaultSheet('Entries');
    return book.save();
  }

  Future<String?> exportXlsxFile({DateTime? from, DateTime? to}) async {
    final bytes = await buildXlsx(from: from, to: to);
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/thavika-entries-${_stamp()}.xlsx');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Writes the CSV to a temporary file and returns its path (null if empty).
  Future<String?> exportCsvFile({DateTime? from, DateTime? to}) async {
    final csv = await buildCsv(from: from, to: to);
    if (csv == null) return null;
    return _writeTemp('thavika-entries-${_stamp()}.csv', csv);
  }

  /// The whole database as a JSON string.
  Future<String> buildBackupJson() async {
    Future<List<Map<String, dynamic>>>
    rows<T extends Table, D extends DataClass>(TableInfo<T, D> table) async {
      final data = await _db.select(table).get();
      return [for (final r in data) r.toJson()];
    }

    final backup = {
      'app': backupApp,
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'currency': _settings.currency.value,
      'tables': {
        'categories': await rows(_db.categories),
        'wallets': await rows(_db.wallets),
        'transactions': await rows(_db.transactions),
        'transfers': await rows(_db.transfers),
        'tags': await rows(_db.tags),
        'transactionTags': await rows(_db.transactionTags),
        'plans': await rows(_db.plans),
        'planItems': await rows(_db.planItems),
        'goals': await rows(_db.goals),
        'goalContributions': await rows(_db.goalContributions),
        'challenges': await rows(_db.challenges),
        'recurringRules': await rows(_db.recurringRules),
        'debts': await rows(_db.debts),
        'debtPayments': await rows(_db.debtPayments),
      },
    };
    return const JsonEncoder.withIndent(' ').convert(backup);
  }

  Future<String> exportBackupFile() async {
    final json = await buildBackupJson();
    return _writeTemp('thavika-backup-${_stamp()}.json', json);
  }

  /// Replaces everything on this phone with the backup in [json].
  /// Throws [BackupException] when the text is not a Thavika backup.
  Future<void> restoreFromJson(String json) async {
    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      data = decoded;
    } on FormatException {
      throw BackupException('Not a backup file.');
    }
    if (data['app'] != backupApp) {
      throw BackupException('Not a Thavika backup.');
    }
    final version = data['version'];
    if (version is! int || version > backupVersion) {
      throw BackupException('This backup was made by a newer version.');
    }
    final tables = data['tables'];
    if (tables is! Map<String, dynamic>) {
      throw BackupException('The backup has no data.');
    }

    List<Map<String, dynamic>> list(String name) {
      final raw = tables[name];
      if (raw == null) return const [];
      if (raw is! List) throw BackupException('The backup is damaged.');
      return raw.cast<Map<String, dynamic>>();
    }

    // Parse everything first, so a damaged file changes nothing.
    final currency = data['currency'];
    final categories = list('categories').map(CategoryRow.fromJson).toList();
    var wallets = list('wallets').map(WalletRow.fromJson).toList();
    var transactions = list('transactions').map(TxRow.fromJson).toList();
    final transfers = list('transfers').map(TransferRow.fromJson).toList();
    final tags = list('tags').map(TagRow.fromJson).toList();
    final transactionTags = list(
      'transactionTags',
    ).map(TransactionTagRow.fromJson).toList();
    final plans = list('plans').map(PlanRow.fromJson).toList();
    final planItems = list('planItems').map(PlanItemRow.fromJson).toList();
    final goals = list('goals').map(GoalRow.fromJson).toList();
    final contributions = list(
      'goalContributions',
    ).map(GoalContributionRow.fromJson).toList();
    final challenges = list('challenges').map(ChallengeRow.fromJson).toList();
    var rules = list('recurringRules').map(RecurringRow.fromJson).toList();
    final debts = list('debts').map(DebtRow.fromJson).toList();
    final debtPayments = list(
      'debtPayments',
    ).map(DebtPaymentRow.fromJson).toList();

    // A version 1 backup has no wallets: everything goes into one "Cash".
    if (wallets.isEmpty) {
      final cash = WalletRow(
        id: const Uuid().v4(),
        name: 'Cash',
        icon: 'wallet',
        kind: 'cash',
        openingMinor: 0,
        currency: currency is String && currency.isNotEmpty ? currency : 'USD',
        sortOrder: 0,
        isArchived: false,
        updatedAt: DateTime.now(),
        syncState: 'pending',
      );
      wallets = [cash];
      transactions = [
        for (final t in transactions)
          t.walletId == null ? t.copyWith(walletId: Value(cash.id)) : t,
      ];
      rules = [
        for (final r in rules)
          r.walletId == null ? r.copyWith(walletId: Value(cash.id)) : r,
      ];
    }

    await _db.transaction(() async {
      // Children first, then parents.
      await _db.delete(_db.outbox).go();
      await _db.delete(_db.debtPayments).go();
      await _db.delete(_db.debts).go();
      await _db.delete(_db.challenges).go();
      await _db.delete(_db.goalContributions).go();
      await _db.delete(_db.planItems).go();
      await _db.delete(_db.transactionTags).go();
      await _db.delete(_db.recurringRules).go();
      await _db.delete(_db.transfers).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.tags).go();
      await _db.delete(_db.goals).go();
      await _db.delete(_db.plans).go();
      await _db.delete(_db.wallets).go();
      await _db.delete(_db.categories).go();

      await _db.batch((b) {
        b.insertAll(_db.categories, categories);
        b.insertAll(_db.wallets, wallets);
        b.insertAll(_db.plans, plans);
        b.insertAll(_db.goals, goals);
        b.insertAll(_db.tags, tags);
        b.insertAll(_db.debts, debts);
        b.insertAll(_db.transactions, transactions);
        b.insertAll(_db.transfers, transfers);
        b.insertAll(_db.transactionTags, transactionTags);
        b.insertAll(_db.planItems, planItems);
        b.insertAll(_db.goalContributions, contributions);
        b.insertAll(_db.challenges, challenges);
        b.insertAll(_db.recurringRules, rules);
        b.insertAll(_db.debtPayments, debtPayments);
      });

      // Queue everything so a later sync uploads the restored data.
      Future<void> queue(String table, Iterable<String> ids) async {
        for (final id in ids) {
          await _db.enqueue(table, id, 'upsert');
        }
      }

      await queue('categories', categories.map((r) => r.id));
      await queue('wallets', wallets.map((r) => r.id));
      await queue('plans', plans.map((r) => r.id));
      await queue('goals', goals.map((r) => r.id));
      await queue('tags', tags.map((r) => r.id));
      await queue('debts', debts.map((r) => r.id));
      await queue('transactions', transactions.map((r) => r.id));
      await queue('transfers', transfers.map((r) => r.id));
      await queue('transaction_tags', transactionTags.map((r) => r.id));
      await queue('plan_items', planItems.map((r) => r.id));
      await queue('goal_contributions', contributions.map((r) => r.id));
      await queue('challenges', challenges.map((r) => r.id));
      await queue('recurring_rules', rules.map((r) => r.id));
      await queue('debt_payments', debtPayments.map((r) => r.id));
    });

    if (currency is String && currency.isNotEmpty) {
      await _settings.setCurrency(currency);
    }
  }

  Future<String> _writeTemp(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    return file.path;
  }

  String _stamp() => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

  /// Quotes a cell when it has a comma, quote, or line break.
  static String _csvCell(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
