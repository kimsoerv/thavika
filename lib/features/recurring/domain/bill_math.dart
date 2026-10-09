import 'recurrence.dart';

enum BillState { overdue, dueToday, upcoming }

class BillStatus {
  const BillStatus(this.state, this.days);

  final BillState state;

  /// Days overdue, or days until the due date (0 when due today).
  final int days;
}

/// Where a bill stands on [today], given its next due date.
BillStatus billStatus(DateTime nextDue, DateTime today) {
  final days = dateOnly(nextDue).difference(dateOnly(today)).inDays;
  if (days < 0) return BillStatus(BillState.overdue, -days);
  if (days == 0) return const BillStatus(BillState.dueToday, 0);
  return BillStatus(BillState.upcoming, days);
}

/// What a bill costs in an average month (weekly bills happen 52/12 times).
int monthlyEquivalent(int amountMinor, String frequency) {
  if (frequency == 'weekly') return (amountMinor * 52 / 12).round();
  return amountMinor;
}
