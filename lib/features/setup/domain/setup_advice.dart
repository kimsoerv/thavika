import '../../plan/domain/plan_balance.dart';
import '../../plan/domain/plan_templates.dart';

/// Which plan to suggest to someone who has just told us their income, rent
/// and food costs.
class SetupAdvice {
  SetupAdvice._();

  /// Share of income taken by rent and food, in percent (0 when unknown).
  static int needsPercent(int incomeMinor, int rentMinor, int foodMinor) {
    if (incomeMinor <= 0) return 0;
    return ((rentMinor + foodMinor) * 100 / incomeMinor).round();
  }

  /// 'balanced' (50/30/20) while rent and food leave room, 'seventy'
  /// (70/20/10) when they take a big part, 'custom' when they take most.
  static String recommend(int incomeMinor, int rentMinor, int foodMinor) {
    final share = needsPercent(incomeMinor, rentMinor, foodMinor);
    if (share <= 50) return 'balanced';
    if (share <= 65) return 'seventy';
    return 'custom';
  }

  /// Builds the template's lines for [incomeMinor], then puts the known
  /// [rentMinor] and [foodMinor] on housing and food.
  ///
  /// The difference to what the template had is taken from the wants first,
  /// then from the other needs (never from savings). If rent and food are
  /// lower than the template, the extra goes to savings.
  static List<PlanItemDraft> buildPlan({
    required PlanTemplate template,
    required int incomeMinor,
    required String currency,
    int rentMinor = 0,
    int foodMinor = 0,
  }) {
    final items = template.build(incomeMinor, currency);
    final known = <String, int>{
      if (rentMinor > 0) 'cat_housing': rentMinor,
      if (foodMinor > 0) 'cat_food': foodMinor,
    };
    if (known.isEmpty) return items;

    final before = items.fold<int>(0, (s, i) => s + i.amountMinor);
    final locked = <PlanItemDraft>{};
    for (final item in items) {
      final amount = known[item.categoryId];
      if (amount != null) {
        item.amountMinor = amount;
        locked.add(item);
      }
    }
    // A template with no amounts (custom) has nothing to rebalance.
    if (before > 0) {
      PlanBalance.rebalance(
        items,
        targetTotal: before,
        locked: locked,
        currency: currency,
      );
    }
    return items;
  }
}

/// What the setup flow hands to the plan screen so it opens filled in.
class PlanSeed {
  const PlanSeed({
    required this.templateId,
    required this.incomeMinor,
    this.rentMinor = 0,
    this.foodMinor = 0,
  });

  final String templateId;
  final int incomeMinor;
  final int rentMinor;
  final int foodMinor;
}
