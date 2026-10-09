import 'dart:math';

import '../../../core/money/money.dart';
import 'plan_templates.dart';

/// Keeps a plan adding up after some lines were set by hand.
class PlanBalance {
  PlanBalance._();

  /// Makes [items] add up to [targetTotal] again.
  ///
  /// Lines in [locked] are left alone. When the lines add up to more than
  /// the target, the difference is taken from the wants first, then from the
  /// other needs; savings are never touched. When they add up to less, the
  /// extra goes to savings (the 'goals' line when it can change).
  static void rebalance(
    List<PlanItemDraft> items, {
    required int targetTotal,
    required Set<PlanItemDraft> locked,
    required String currency,
  }) {
    final unit = pow(10, Money.decimalsFor(currency)).toInt();
    var over = items.fold<int>(0, (s, i) => s + i.amountMinor) - targetTotal;

    if (over > 0) {
      for (final group in ['wants', 'needs']) {
        final pool = items
            .where((i) => i.group == group && !locked.contains(i))
            .toList();
        over -= _shrink(pool, over, unit);
        if (over <= 0) break;
      }
    } else if (over < 0) {
      final free = items.where((i) => !locked.contains(i)).toList();
      final savings = free.where((i) => i.group == 'savings').toList();
      PlanItemDraft? sink;
      if (savings.isNotEmpty) {
        sink = savings.firstWhere(
          (i) => i.name == 'goals',
          orElse: () => savings.first,
        );
      } else if (free.isNotEmpty) {
        sink = free.reduce((a, b) => a.amountMinor >= b.amountMinor ? a : b);
      }
      sink?.amountMinor += -over;
    }
  }

  /// Takes up to [take] from [pool] in proportion to each line.
  /// Returns how much was taken.
  static int _shrink(List<PlanItemDraft> pool, int take, int unit) {
    final total = pool.fold<int>(0, (s, i) => s + i.amountMinor);
    if (total <= 0) return 0;
    final amount = min(take, total);
    var taken = 0;
    for (final item in pool) {
      final cut = ((amount * item.amountMinor / total) / unit).floor() * unit;
      item.amountMinor -= cut;
      taken += cut;
    }
    // Whatever rounding left over comes off the biggest lines.
    while (taken < amount) {
      pool.sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
      final biggest = pool.first;
      if (biggest.amountMinor <= 0) break;
      final cut = min(amount - taken, biggest.amountMinor);
      biggest.amountMinor -= cut;
      taken += cut;
    }
    return taken;
  }

  /// A plan where the 'goals' saving is what the user's goals need each
  /// month, and the other lines make room for it.
  static List<PlanItemDraft> fitToGoals({
    required PlanTemplate template,
    required int incomeMinor,
    required String currency,
    required int goalsMonthlyMinor,
  }) {
    final items = template.build(incomeMinor, currency);
    final before = items.fold<int>(0, (s, i) => s + i.amountMinor);
    final goals = items.where((i) => i.name == 'goals').firstOrNull;
    // A template without a goals line (custom) gets one in savings.
    final line =
        goals ?? PlanItemDraft(group: 'savings', name: 'goals', amountMinor: 0);
    if (goals == null) items.add(line);
    line.amountMinor = max(0, goalsMonthlyMinor);
    // Custom starts with nothing, so there is nothing to make room from.
    if (before > 0) {
      rebalance(items, targetTotal: before, locked: {line}, currency: currency);
    }
    return items;
  }

  /// What share of income the goals need, in percent.
  static int percentOfIncome(int amountMinor, int incomeMinor) =>
      incomeMinor <= 0 ? 0 : (amountMinor * 100 / incomeMinor).round();
}
