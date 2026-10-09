import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/goals/domain/goal_math.dart';

void main() {
  final today = DateTime(2026, 10, 9);

  test('progress without a date', () {
    final p = goalProgress(targetMinor: 50000, savedMinor: 32000, today: today);
    expect(p.fraction, closeTo(0.64, 0.0001));
    expect(p.remainingMinor, 18000);
    expect(p.isDone, isFalse);
    expect(p.monthlyNeededMinor, isNull);
  });

  test('monthly amount needed to reach the date', () {
    // About 2.7 months to 31 Dec: rounded up to 3 months.
    final p = goalProgress(
      targetMinor: 50000,
      savedMinor: 32000,
      targetDate: DateTime(2026, 12, 31),
      today: today,
    );
    expect(p.monthlyNeededMinor, 6000);
    expect(p.isOverdue, isFalse);
  });

  test('a close date still needs at least a month', () {
    final p = goalProgress(
      targetMinor: 10000,
      savedMinor: 0,
      targetDate: DateTime(2026, 10, 12),
      today: today,
    );
    expect(p.monthlyNeededMinor, 10000);
  });

  test('reaching the target finishes the goal', () {
    final p = goalProgress(
      targetMinor: 50000,
      savedMinor: 60000,
      targetDate: DateTime(2026, 12, 31),
      today: today,
    );
    expect(p.isDone, isTrue);
    expect(p.fraction, 1.0);
    expect(p.remainingMinor, 0);
    expect(p.monthlyNeededMinor, isNull);
  });

  test('a date in the past is overdue', () {
    final p = goalProgress(
      targetMinor: 50000,
      savedMinor: 10000,
      targetDate: DateTime(2026, 9, 1),
      today: today,
    );
    expect(p.isOverdue, isTrue);
    expect(p.monthlyNeededMinor, 40000);
  });

  test('a zero target does not divide by zero', () {
    final p = goalProgress(targetMinor: 0, savedMinor: 0, today: today);
    expect(p.fraction, 0);
    expect(p.isDone, isFalse);
  });
}
