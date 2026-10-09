import 'dart:async';

import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../entry/application/entry_meta_service.dart';
import '../../settings/application/backup_service.dart';
import '../domain/report_math.dart';
import '../../transactions/data/transaction_repository.dart';

class CategoryTotal {
  const CategoryTotal(this.category, this.categoryId, this.amountMinor);

  final CategoryRow? category;
  final String categoryId;
  final int amountMinor;
}

class ReportsController extends GetxController {
  ReportsController(this._repo, this.settings, this.backup, this.meta);

  final TransactionRepository _repo;
  final SettingsService settings;
  final BackupService backup;
  final EntryMetaService meta;

  final month = DateTime(DateTime.now().year, DateTime.now().month).obs;

  /// How many months the trend chart shows.
  static const trendMonths = 6;

  /// Entries of the last [trendMonths] months up to the selected month.
  final window = <TxWithCategory>[].obs;

  StreamSubscription<List<TxWithCategory>>? _sub;

  String get currency => settings.currency.value;

  @override
  void onInit() {
    super.onInit();
    _listen();
    ever(month, (_) => _listen());
  }

  void _listen() {
    final m = month.value;
    _sub?.cancel();
    _sub = _repo
        .watchRange(
          DateTime(m.year, m.month - (trendMonths - 1)),
          DateTime(m.year, m.month + 1),
        )
        .listen(window.assignAll);
  }

  bool _isMonth(TxWithCategory e, DateTime m) =>
      e.tx.occurredOn.year == m.year && e.tx.occurredOn.month == m.month;

  List<TxWithCategory> get current =>
      window.where((e) => _isMonth(e, month.value)).toList();

  List<TxWithCategory> get previous {
    final m = month.value;
    final before = DateTime(m.year, m.month - 1);
    return window.where((e) => _isMonth(e, before)).toList();
  }

  List<ReportTx> get _reportTx => [
    for (final e in window)
      ReportTx(
        id: e.tx.id,
        type: e.tx.type,
        amountMinor: e.tx.amountMinor,
        categoryId: e.tx.categoryId,
        walletId: e.tx.walletId,
        occurredOn: e.tx.occurredOn,
      ),
  ];

  List<int> get dailySpending =>
      ReportMath.dailySpending(_reportTx, month.value);

  List<MonthTotal> get trend =>
      ReportMath.monthlyTotals(_reportTx, month.value, trendMonths);

  /// (wallet name, totals), biggest spending first. Empty with one wallet.
  List<MapEntry<String, InOut>> get walletTotals {
    if (meta.wallets.length < 2) return const [];
    final totals = ReportMath.byWallet(_reportTx, month.value);
    final list = [
      for (final e in totals.entries)
        MapEntry(meta.walletById(e.key)?.name ?? '', e.value),
    ]..sort((a, b) => b.value.spent.compareTo(a.value.spent));
    return list;
  }

  /// (tag name, spent), biggest first.
  List<MapEntry<String, int>> get tagTotals {
    final totals = ReportMath.spendingByTag(
      _reportTx,
      month.value,
      meta.tagLinks,
    );
    final names = {for (final t in meta.tags) t.id: t.name};
    final list = [
      for (final e in totals.entries)
        if (names[e.key] != null) MapEntry(names[e.key]!, e.value),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  void shiftMonth(int delta) {
    month.value = DateTime(month.value.year, month.value.month + delta);
  }

  static int _sum(List<TxWithCategory> list, String type) => list
      .where((e) => e.tx.type == type)
      .fold(0, (sum, e) => sum + e.tx.amountMinor);

  int get income => _sum(current, 'income');
  int get spent => _sum(current, 'expense');
  int get leftOver => income - spent;
  int get previousSpent => _sum(previous, 'expense');
  bool get hasPrevious => previous.isNotEmpty;

  /// Spending per category, biggest first.
  List<CategoryTotal> get byCategory {
    final totals = <String, int>{};
    final cats = <String, CategoryRow?>{};
    for (final e in current) {
      if (e.tx.type != 'expense') continue;
      totals[e.tx.categoryId] =
          (totals[e.tx.categoryId] ?? 0) + e.tx.amountMinor;
      cats[e.tx.categoryId] = e.category;
    }
    final list = [
      for (final e in totals.entries)
        CategoryTotal(cats[e.key], e.key, e.value),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return list;
  }

  /// Path of a CSV with this month's entries, or null when there are none.
  Future<String?> exportMonth() {
    final m = month.value;
    return backup.exportCsvFile(from: m, to: DateTime(m.year, m.month + 1));
  }

  /// Path of an Excel file with this month's entries, or null.
  Future<String?> exportMonthExcel() {
    final m = month.value;
    return backup.exportXlsxFile(from: m, to: DateTime(m.year, m.month + 1));
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
