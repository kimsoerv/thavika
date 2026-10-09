import 'dart:math';

/// How a category is doing against its monthly budget.
/// The order matters: a higher index is worse.
enum PaceStatus { onTrack, slightlyAhead, offTrack, over }

/// A budget line, stripped down to what the check needs.
class PlanLine {
  const PlanLine({
    required this.id,
    required this.group,
    required this.name,
    required this.categoryId,
    required this.budgetMinor,
    required this.isFixed,
  });

  final String id;
  final String group;
  final String name;
  final String? categoryId;
  final int budgetMinor;
  final bool isFixed;
}

int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// Compares what was spent with what should have been spent by [today].
///
/// Expected by today = budget x (day of month / days in month).
/// Up to 15% above expected is "slightly ahead", more is "off track",
/// and using the whole budget is "over".
PaceStatus paceStatus({
  required int spent,
  required int budget,
  required DateTime today,
}) {
  if (budget <= 0) return spent > 0 ? PaceStatus.over : PaceStatus.onTrack;
  if (spent >= budget) return PaceStatus.over;
  final expected = budget * today.day / daysInMonth(today);
  if (spent <= expected) return PaceStatus.onTrack;
  return spent / expected <= 1.15
      ? PaceStatus.slightlyAhead
      : PaceStatus.offTrack;
}

class ItemCheck {
  const ItemCheck({
    required this.line,
    required this.spent,
    required this.status,
  });

  final PlanLine line;
  final int spent;
  final PaceStatus status;

  bool get isFixed => line.isFixed;

  /// Share of the budget used so far (can be above 1).
  double get used =>
      line.budgetMinor <= 0 ? (spent > 0 ? 1 : 0) : spent / line.budgetMinor;
}

class PlanCheck {
  const PlanCheck({
    required this.items,
    required this.flexibleBudget,
    required this.flexibleSpent,
    required this.safeToSpend,
    required this.plannedSavings,
    required this.projectedSavings,
    required this.projectionReliable,
    required this.daysLeft,
  });

  /// Lines checked against a category (savings lines are not in here).
  final List<ItemCheck> items;

  /// Budget and spending of categories that are not fixed bills.
  final int flexibleBudget;
  final int flexibleSpent;

  /// What can be spent today without going off plan (never below zero).
  final int safeToSpend;
  final int plannedSavings;
  final int projectedSavings;

  /// False in the first days of the month, when a projection would be noise.
  final bool projectionReliable;

  /// Days left in the month, not counting today.
  final int daysLeft;

  int get offTrackCount => items
      .where(
        (i) => i.status == PaceStatus.offTrack || i.status == PaceStatus.over,
      )
      .length;

  int get slightlyAheadCount =>
      items.where((i) => i.status == PaceStatus.slightlyAhead).length;

  PaceStatus get overall {
    if (offTrackCount > 0) return PaceStatus.offTrack;
    if (slightlyAheadCount > 0) return PaceStatus.slightlyAhead;
    return PaceStatus.onTrack;
  }
}

/// Builds the plan check for the month that contains [today].
///
/// [spentByCategory] is this month's expenses grouped by category id.
PlanCheck computePlanCheck({
  required List<PlanLine> lines,
  required Map<String, int> spentByCategory,
  required DateTime today,
}) {
  final dim = daysInMonth(today);
  final checks = <ItemCheck>[];
  var flexibleBudget = 0;
  var flexibleSpent = 0;
  var plannedSavings = 0;

  for (final line in lines) {
    if (line.group == 'savings') plannedSavings += line.budgetMinor;
    final cat = line.categoryId;
    if (cat == null) continue;

    final spent = spentByCategory[cat] ?? 0;
    final PaceStatus status;
    if (line.isFixed) {
      status = spent > line.budgetMinor ? PaceStatus.over : PaceStatus.onTrack;
    } else {
      status = paceStatus(spent: spent, budget: line.budgetMinor, today: today);
      flexibleBudget += line.budgetMinor;
      flexibleSpent += spent;
    }
    checks.add(ItemCheck(line: line, spent: spent, status: status));
  }

  final daysLeftIncludingToday = dim - today.day + 1;
  final safe = max(
    0,
    (flexibleBudget - flexibleSpent) ~/ daysLeftIncludingToday,
  );

  final projectedSpend = (flexibleSpent * dim / today.day).round();
  final overspend = max(0, projectedSpend - flexibleBudget);

  return PlanCheck(
    items: checks,
    flexibleBudget: flexibleBudget,
    flexibleSpent: flexibleSpent,
    safeToSpend: safe,
    plannedSavings: plannedSavings,
    projectedSavings: max(0, plannedSavings - overspend),
    projectionReliable: today.day >= 3,
    daysLeft: dim - today.day,
  );
}
