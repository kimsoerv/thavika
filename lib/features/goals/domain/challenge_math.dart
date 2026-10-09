/// Maths of a weekly saving challenge.
///
/// 'weekly' ("step up"): week n saves n times the unit, so 52 weeks of a $1
/// unit save $1,378. 'fixed': every week saves the unit.
class ChallengeMath {
  ChallengeMath._();

  static int stepAmount(String kind, int unitMinor, int step) =>
      kind == 'weekly' ? unitMinor * step : unitMinor;

  /// What the whole challenge saves.
  static int totalAmount(String kind, int unitMinor, int steps) {
    var sum = 0;
    for (var s = 1; s <= steps; s++) {
      sum += stepAmount(kind, unitMinor, s);
    }
    return sum;
  }

  static Set<int> parseSteps(String csv) => {
    for (final part in csv.split(','))
      if (int.tryParse(part.trim()) != null) int.parse(part.trim()),
  };

  static String encodeSteps(Set<int> steps) =>
      (steps.toList()..sort()).join(',');

  /// How many steps are due by [today]: step 1 is due on the start day,
  /// step 2 a week later, and so on. Zero before the start.
  static int dueStep(DateTime start, DateTime today, int steps) {
    final s = DateTime(start.year, start.month, start.day);
    final t = DateTime(today.year, today.month, today.day);
    final days = t.difference(s).inDays;
    if (days < 0) return 0;
    final due = days ~/ 7 + 1;
    return due > steps ? steps : due;
  }

  /// Weeks in a row that were done, counting back from the latest due week.
  /// The current week not being done yet does not break the streak.
  static int streak(Set<int> done, int dueStep) {
    var step = dueStep;
    if (step > 0 && !done.contains(step)) step--;
    var count = 0;
    while (step > 0 && done.contains(step)) {
      count++;
      step--;
    }
    return count;
  }

  /// Due weeks that were not done, counting only weeks before the current
  /// one (the current week still has time).
  static int behind(Set<int> done, int dueStep) {
    var missed = 0;
    for (var s = 1; s < dueStep; s++) {
      if (!done.contains(s)) missed++;
    }
    return missed;
  }

  static int savedSoFar(String kind, int unitMinor, Set<int> done) =>
      done.fold(0, (sum, s) => sum + stepAmount(kind, unitMinor, s));
}
