import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../entry/application/entry_meta_service.dart';
import '../../household/application/household_service.dart';
import '../../plan/application/budget_service.dart';
import '../../plan/domain/plan_check.dart';
import '../../transactions/data/transaction_repository.dart';

class CategorySlice {
  const CategorySlice(this.category, this.amountMinor);

  final CategoryRow? category;
  final int amountMinor;
}

class HomeController extends GetxController {
  HomeController(this.budget, this.settings, this.meta);

  final BudgetService budget;
  final SettingsService settings;
  final EntryMetaService meta;

  RxList<TxWithCategory> get monthTx => budget.monthTx;
  DateTime get month => budget.month.value;
  String get currency => settings.currency.value;

  /// Null until the user has made a plan.
  PlanCheck? get check => budget.check.value;

  int _sum(String type) => monthTx
      .where((e) => e.tx.type == type)
      .fold(0, (sum, e) => sum + e.tx.amountMinor);

  int get income => _sum('income');
  int get spent => _sum('expense');
  int get balance => income - spent;

  /// Wallet (when there is more than one) and tags, for the tile.
  String extraFor(TxWithCategory e) {
    final parts = <String>[];
    if (meta.wallets.length > 1) {
      final name = meta.walletById(e.tx.walletId)?.name;
      if (name != null) parts.add(name);
    }
    final tags = meta.tagLabel(e.tx.id);
    if (tags.isNotEmpty) parts.add(tags);
    // In a household, entries made by someone else show their name.
    final by = Get.isRegistered<HouseholdService>()
        ? Get.find<HouseholdService>().addedBy(e.tx.ownerId)
        : null;
    if (by != null) parts.add(by);
    return parts.join(' · ');
  }

  List<TxWithCategory> get recent => monthTx.take(5).toList();

  /// Biggest spending categories this month (top 4, the rest grouped).
  List<CategorySlice> get breakdown {
    final totals = <String, int>{};
    final byId = <String, CategoryRow?>{};
    for (final e in monthTx) {
      if (e.tx.type != 'expense') continue;
      final id = e.tx.categoryId;
      totals[id] = (totals[id] ?? 0) + e.tx.amountMinor;
      byId[id] = e.category;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final slices = <CategorySlice>[
      for (final e in sorted.take(4)) CategorySlice(byId[e.key], e.value),
    ];
    final rest = sorted.skip(4).fold<int>(0, (s, e) => s + e.value);
    if (rest > 0) slices.add(CategorySlice(null, rest));
    return slices;
  }
}
