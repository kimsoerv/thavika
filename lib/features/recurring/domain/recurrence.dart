import 'dart:math';

import 'package:uuid/uuid.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The date after [current] for a repeating entry.
///
/// Monthly entries keep their [anchorDay]; in a short month they fall on the
/// last day (a rule anchored on the 31st runs on Feb 28, then Mar 31 again).
DateTime advance(DateTime current, String frequency, int anchorDay) {
  if (frequency == 'weekly') {
    return DateTime(current.year, current.month, current.day + 7);
  }
  final firstOfNext = DateTime(current.year, current.month + 1);
  final lastDay = DateTime(firstOfNext.year, firstOfNext.month + 1, 0).day;
  return DateTime(firstOfNext.year, firstOfNext.month, min(anchorDay, lastDay));
}

class DueDates {
  const DueDates(this.due, this.next);

  /// Dates up to and including today that still need an entry.
  final List<DateTime> due;

  /// The first date after today.
  final DateTime next;
}

/// All dates from [nextRunOn] up to [today], and the date after them.
///
/// [maxCatchUp] stops a rule that was off for years from flooding the list.
DueDates dueDates({
  required DateTime nextRunOn,
  required String frequency,
  required int anchorDay,
  required DateTime today,
  int maxCatchUp = 60,
}) {
  final end = dateOnly(today);
  var current = dateOnly(nextRunOn);
  final due = <DateTime>[];
  while (!current.isAfter(end) && due.length < maxCatchUp) {
    due.add(current);
    current = advance(current, frequency, anchorDay);
  }
  // If the cap was hit, skip ahead so the rule does not stay in the past.
  while (!current.isAfter(end)) {
    current = advance(current, frequency, anchorDay);
  }
  return DueDates(due, current);
}

/// Same id on every phone for the same rule and date, so two phones that
/// both create the entry end up with one row, not two.
String recurringEntryId(String ruleId, DateTime date) {
  final d = dateOnly(date);
  final key = '$ruleId|${d.year}-${d.month}-${d.day}';
  return const Uuid().v5(Namespace.url.value, key);
}
