import 'dart:math';

import '../../../core/money/money.dart';

/// How much to set aside when money comes in: the share of the planned
/// saving that this income stands for, never more than what is still left
/// to save this month. Zero when there is nothing to set aside.
int suggestSetAside({
  required int plannedSavingsMinor,
  required int planIncomeMinor,
  required int movedThisMonthMinor,
  required int incomeEntryMinor,
  required String currency,
}) {
  if (plannedSavingsMinor <= 0 || incomeEntryMinor <= 0) return 0;
  final remaining = plannedSavingsMinor - movedThisMonthMinor;
  if (remaining <= 0) return 0;
  final share = planIncomeMinor > 0
      ? plannedSavingsMinor * incomeEntryMinor / planIncomeMinor
      : plannedSavingsMinor.toDouble();
  final unit = pow(10, Money.decimalsFor(currency)).toInt();
  final rounded = (share / unit).round() * unit;
  return min(remaining, rounded);
}
