import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/recurring/domain/bill_math.dart';

void main() {
  final today = DateTime(2026, 3, 10, 15, 30);

  test('upcoming, due today and overdue', () {
    final up = billStatus(DateTime(2026, 3, 13), today);
    expect(up.state, BillState.upcoming);
    expect(up.days, 3);
    expect(billStatus(DateTime(2026, 3, 10), today).state, BillState.dueToday);
    final late = billStatus(DateTime(2026, 3, 7), today);
    expect(late.state, BillState.overdue);
    expect(late.days, 3);
  });

  test('time of day does not matter', () {
    expect(
      billStatus(
        DateTime(2026, 3, 11, 23, 59),
        DateTime(2026, 3, 10, 0, 1),
      ).days,
      1,
    );
  });

  test('monthly equivalent', () {
    expect(monthlyEquivalent(1000, 'monthly'), 1000);
    expect(monthlyEquivalent(1200, 'weekly'), 5200);
  });
}
