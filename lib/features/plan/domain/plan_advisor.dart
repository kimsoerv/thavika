import 'dart:math';

import '../../../core/money/money.dart';

/// A budget line as the advisor sees it.
class AdviceLine {
  const AdviceLine({
    required this.id,
    required this.categoryId,
    required this.group,
    required this.budgetMinor,
    required this.isFixed,
  });

  final String id;
  final String? categoryId;
  final String group;
  final int budgetMinor;
  final bool isFixed;
}

/// "Move [amountMinor] from one line to another."
class AdviceMove {
  const AdviceMove({
    required this.fromLineId,
    required this.toLineId,
    required this.amountMinor,
  });

  final String fromLineId;
  final String toLineId;
  final int amountMinor;
}

/// Looks at what was really spent in past months and suggests moving budget
/// from lines that keep coming in low to lines that keep running over.
class PlanAdvisor {
  PlanAdvisor._();

  /// A line is "over" when it ran more than 10% over in every month looked at.
  static const overBy = 0.10;

  /// A line is "under" when it used less than 80% of its budget every month.
  static const underBy = 0.20;

  /// [spentByMonth] has one map (category id to spent) per past month,
  /// months without spending already left out. Savings and fixed lines are
  /// never touched.
  static List<AdviceMove> suggest({
    required List<AdviceLine> lines,
    required List<Map<String, int>> spentByMonth,
    required String currency,
  }) {
    if (spentByMonth.isEmpty) return const [];
    final unit = pow(10, Money.decimalsFor(currency)).toInt();

    int spent(AdviceLine l, Map<String, int> month) => month[l.categoryId] ?? 0;

    final raises = <AdviceLine, int>{};
    final donors = <AdviceLine, int>{};

    for (final line in lines) {
      if (line.categoryId == null || line.isFixed) continue;
      if (line.group == 'savings') continue;
      final amounts = [for (final m in spentByMonth) spent(line, m)];
      final average = amounts.fold<int>(0, (s, a) => s + a) / amounts.length;
      final highest = amounts.reduce(max);

      final isOver = amounts.every(
        (a) => a > line.budgetMinor * (1 + overBy) && a > 0,
      );
      if (isOver) {
        final need = (((average - line.budgetMinor) / unit).round()) * unit;
        if (need >= unit) raises[line] = need;
        continue;
      }
      final isUnder =
          line.budgetMinor > 0 && highest < line.budgetMinor * (1 - underBy);
      if (isUnder) {
        final give = (((line.budgetMinor - highest) / unit).floor()) * unit;
        if (give >= unit) donors[line] = give;
      }
    }

    final moves = <AdviceMove>[];
    final raiseOrder = raises.keys.toList()
      ..sort((a, b) => raises[b]!.compareTo(raises[a]!));
    for (final target in raiseOrder) {
      var need = raises[target]!;
      final drawn = <AdviceMove>[];
      final donorOrder = donors.keys.toList()
        ..sort((a, b) => donors[b]!.compareTo(donors[a]!));
      for (final donor in donorOrder) {
        if (need <= 0) break;
        final take = min(need, donors[donor]!);
        if (take <= 0) continue;
        drawn.add(
          AdviceMove(
            fromLineId: donor.id,
            toLineId: target.id,
            amountMinor: take,
          ),
        );
        need -= take;
      }
      final covered = raises[target]! - need;
      // Only suggest a change that covers at least half of what is missing.
      if (covered * 2 < raises[target]!) continue;
      for (final m in drawn) {
        final donor = donors.keys.firstWhere((l) => l.id == m.fromLineId);
        donors[donor] = donors[donor]! - m.amountMinor;
        moves.add(m);
      }
    }
    return moves;
  }
}
