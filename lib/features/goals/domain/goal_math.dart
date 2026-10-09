import 'dart:math';

class GoalProgress {
  const GoalProgress({
    required this.savedMinor,
    required this.targetMinor,
    required this.fraction,
    required this.remainingMinor,
    required this.isDone,
    required this.isOverdue,
    required this.monthlyNeededMinor,
  });

  final int savedMinor;
  final int targetMinor;

  /// 0 to 1 (never above 1).
  final double fraction;
  final int remainingMinor;
  final bool isDone;

  /// A target date was set and has already passed.
  final bool isOverdue;

  /// What to put aside each month to reach the date; null without a date or
  /// once the goal is reached.
  final int? monthlyNeededMinor;
}

/// Progress of a savings goal and, with a target date, how much to save
/// per month to get there.
GoalProgress goalProgress({
  required int targetMinor,
  required int savedMinor,
  DateTime? targetDate,
  required DateTime today,
}) {
  final remaining = max(0, targetMinor - savedMinor);
  final done = targetMinor > 0 && savedMinor >= targetMinor;
  final fraction = targetMinor <= 0
      ? 0.0
      : (savedMinor / targetMinor).clamp(0.0, 1.0);

  var overdue = false;
  int? monthly;
  if (!done && targetDate != null) {
    final todayDate = DateTime(today.year, today.month, today.day);
    final daysLeft = targetDate.difference(todayDate).inDays;
    if (daysLeft < 0) {
      overdue = true;
      monthly = remaining;
    } else {
      final months = max(1, (daysLeft / 30.44).ceil());
      monthly = (remaining / months).ceil();
    }
  }

  return GoalProgress(
    savedMinor: savedMinor,
    targetMinor: targetMinor,
    fraction: fraction,
    remainingMinor: remaining,
    isDone: done,
    isOverdue: overdue,
    monthlyNeededMinor: monthly,
  );
}
