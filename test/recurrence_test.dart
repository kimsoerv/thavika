import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/recurring/domain/recurrence.dart';

void main() {
  group('advance', () {
    test('weekly adds seven days', () {
      expect(
        advance(DateTime(2026, 10, 9), 'weekly', 9),
        DateTime(2026, 10, 16),
      );
      expect(
        advance(DateTime(2026, 10, 28), 'weekly', 28),
        DateTime(2026, 11, 4),
      );
    });

    test('monthly keeps the day of the month', () {
      expect(
        advance(DateTime(2026, 10, 5), 'monthly', 5),
        DateTime(2026, 11, 5),
      );
      expect(
        advance(DateTime(2026, 12, 5), 'monthly', 5),
        DateTime(2027, 1, 5),
      );
    });

    test('monthly on the 31st uses the last day of short months', () {
      expect(
        advance(DateTime(2026, 1, 31), 'monthly', 31),
        DateTime(2026, 2, 28),
      );
      // Back to the 31st afterwards, not stuck on the 28th.
      expect(
        advance(DateTime(2026, 2, 28), 'monthly', 31),
        DateTime(2026, 3, 31),
      );
      expect(
        advance(DateTime(2028, 1, 31), 'monthly', 31),
        DateTime(2028, 2, 29),
      );
    });
  });

  group('dueDates', () {
    test('nothing is due before the start date', () {
      final r = dueDates(
        nextRunOn: DateTime(2026, 11, 1),
        frequency: 'monthly',
        anchorDay: 1,
        today: DateTime(2026, 10, 9),
      );
      expect(r.due, isEmpty);
      expect(r.next, DateTime(2026, 11, 1));
    });

    test('today counts as due', () {
      final r = dueDates(
        nextRunOn: DateTime(2026, 10, 9),
        frequency: 'monthly',
        anchorDay: 9,
        today: DateTime(2026, 10, 9, 15, 30),
      );
      expect(r.due, [DateTime(2026, 10, 9)]);
      expect(r.next, DateTime(2026, 11, 9));
    });

    test('missed dates are caught up', () {
      final r = dueDates(
        nextRunOn: DateTime(2026, 7, 15),
        frequency: 'monthly',
        anchorDay: 15,
        today: DateTime(2026, 10, 9),
      );
      expect(r.due, [
        DateTime(2026, 7, 15),
        DateTime(2026, 8, 15),
        DateTime(2026, 9, 15),
      ]);
      expect(r.next, DateTime(2026, 10, 15));
    });

    test('weekly catch up', () {
      final r = dueDates(
        nextRunOn: DateTime(2026, 9, 25),
        frequency: 'weekly',
        anchorDay: 25,
        today: DateTime(2026, 10, 9),
      );
      expect(r.due, [
        DateTime(2026, 9, 25),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 9),
      ]);
      expect(r.next, DateTime(2026, 10, 16));
    });

    test(
      'a rule that was off for years is capped but ends up in the future',
      () {
        final r = dueDates(
          nextRunOn: DateTime(2010, 1, 1),
          frequency: 'weekly',
          anchorDay: 1,
          today: DateTime(2026, 10, 9),
          maxCatchUp: 10,
        );
        expect(r.due, hasLength(10));
        expect(r.next.isAfter(DateTime(2026, 10, 9)), isTrue);
      },
    );
  });

  test('the entry id is the same for the same rule and date', () {
    final a = recurringEntryId('rule-1', DateTime(2026, 10, 9, 8));
    final b = recurringEntryId('rule-1', DateTime(2026, 10, 9, 22));
    final c = recurringEntryId('rule-1', DateTime(2026, 10, 10));
    final d = recurringEntryId('rule-2', DateTime(2026, 10, 9));
    expect(a, b);
    expect(a, isNot(c));
    expect(a, isNot(d));
  });
}
