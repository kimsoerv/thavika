import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/plan/domain/reminder_planner.dart';

List<PlannedReminder> _plan({
  required DateTime now,
  ReminderPrefs prefs = const ReminderPrefs(),
  bool hasEntryToday = false,
  int planned = 0,
  int moved = 0,
  List<BillInfo> bills = const [],
}) => ReminderPlanner.plan(
  now: now,
  prefs: prefs,
  hasEntryToday: hasEntryToday,
  plannedSavingsMinor: planned,
  movedToGoalsMinor: moved,
  bills: bills,
);

Iterable<PlannedReminder> _of(List<PlannedReminder> l, ReminderKind k) =>
    l.where((r) => r.kind == k);

void main() {
  group('daily', () {
    test('seven days from today when nothing is recorded', () {
      final r = _of(_plan(now: DateTime(2026, 3, 10, 8)), ReminderKind.daily);
      expect(r.length, 7);
      expect(r.first.at, DateTime(2026, 3, 10, 21));
    });

    test('today is skipped once an entry exists', () {
      final r = _of(
        _plan(now: DateTime(2026, 3, 10, 8), hasEntryToday: true),
        ReminderKind.daily,
      );
      expect(r.length, 6);
      expect(r.first.at, DateTime(2026, 3, 11, 21));
    });

    test('today is skipped when the time has passed', () {
      final r = _of(_plan(now: DateTime(2026, 3, 10, 22)), ReminderKind.daily);
      expect(r.first.at, DateTime(2026, 3, 11, 21));
    });

    test('off means none', () {
      final r = _plan(
        now: DateTime(2026, 3, 10),
        prefs: const ReminderPrefs(daily: false),
      );
      expect(_of(r, ReminderKind.daily), isEmpty);
    });

    test('uses the chosen time', () {
      final r = _of(
        _plan(
          now: DateTime(2026, 3, 10, 6),
          prefs: const ReminderPrefs(hour: 7, minute: 30),
        ),
        ReminderKind.daily,
      );
      expect(r.first.at, DateTime(2026, 3, 10, 7, 30));
    });
  });

  group('savings', () {
    test('reminds on the 5th and 20th with what is left', () {
      final r = _of(
        _plan(now: DateTime(2026, 3, 1), planned: 20000, moved: 5000),
        ReminderKind.savings,
      ).toList();
      expect(r.map((e) => e.at.day), [5, 20, 5, 20]);
      expect(r.first.amountMinor, 15000);
      // Next month's reminders do not know an amount yet.
      expect(r[2].amountMinor, isNull);
    });

    test('nothing for this month once the saving is moved', () {
      final r = _of(
        _plan(now: DateTime(2026, 3, 1), planned: 20000, moved: 20000),
        ReminderKind.savings,
      ).toList();
      expect(r.length, 2);
      expect(r.first.at.month, 4);
    });

    test('nothing without a planned saving', () {
      expect(
        _of(_plan(now: DateTime(2026, 3, 1)), ReminderKind.savings),
        isEmpty,
      );
    });

    test('dates that have passed are not scheduled', () {
      final r = _of(
        _plan(now: DateTime(2026, 3, 10), planned: 100),
        ReminderKind.savings,
      ).toList();
      expect(r.first.at, DateTime(2026, 3, 20, 12));
    });

    test('ids stay unique', () {
      final r = _plan(now: DateTime(2026, 3, 1), planned: 100);
      expect(r.map((e) => e.id).toSet().length, r.length);
    });
  });

  group('month end', () {
    test('last day of this and next month at 20:00', () {
      final r = _of(
        _plan(now: DateTime(2026, 2, 10)),
        ReminderKind.monthEnd,
      ).toList();
      expect(r.map((e) => e.at), [
        DateTime(2026, 2, 28, 20),
        DateTime(2026, 3, 31, 20),
      ]);
    });

    test('this month is skipped after the last evening', () {
      final r = _of(
        _plan(now: DateTime(2026, 2, 28, 21)),
        ReminderKind.monthEnd,
      ).toList();
      expect(r.length, 1);
      expect(r.first.at.month, 3);
    });
  });

  group('bills', () {
    BillInfo rent(DateTime due, {int before = 2}) => BillInfo(
      id: 'rent',
      name: 'Rent',
      amountMinor: 40000,
      nextDue: due,
      frequency: 'monthly',
      anchorDay: due.day,
      remindDaysBefore: before,
    );

    test('reminds the chosen days before at 9:00', () {
      final r = _of(
        _plan(now: DateTime(2026, 3, 1), bills: [rent(DateTime(2026, 3, 10))]),
        ReminderKind.bill,
      ).toList();
      expect(r.first.at, DateTime(2026, 3, 8, 9));
      expect(r.first.dueOn, DateTime(2026, 3, 10));
      expect(r.first.name, 'Rent');
      expect(r.first.amountMinor, 40000);
    });

    test('a monthly bill also gets next month inside the horizon', () {
      final r = _of(
        _plan(now: DateTime(2026, 3, 8), bills: [rent(DateTime(2026, 3, 10))]),
        ReminderKind.bill,
      ).toList();
      expect(r.map((e) => e.dueOn), [
        DateTime(2026, 3, 10),
        DateTime(2026, 4, 10),
      ]);
    });

    test('a reminder time that has passed is skipped', () {
      final r = _of(
        _plan(
          now: DateTime(2026, 3, 9, 12),
          bills: [rent(DateTime(2026, 3, 10))],
        ),
        ReminderKind.bill,
      ).toList();
      expect(r.first.dueOn, DateTime(2026, 4, 10));
    });

    test('0 days before means the morning of the due date', () {
      final r = _of(
        _plan(
          now: DateTime(2026, 3, 1),
          bills: [rent(DateTime(2026, 3, 10), before: 0)],
        ),
        ReminderKind.bill,
      ).toList();
      expect(r.first.at, DateTime(2026, 3, 10, 9));
    });

    test('off means none', () {
      final r = _plan(
        now: DateTime(2026, 3, 1),
        prefs: const ReminderPrefs(bills: false),
        bills: [rent(DateTime(2026, 3, 10))],
      );
      expect(_of(r, ReminderKind.bill), isEmpty);
    });
  });

  test('every notification has its own id', () {
    final r = _plan(
      now: DateTime(2026, 3, 1),
      planned: 100,
      bills: [
        BillInfo(
          id: 'a',
          name: 'A',
          amountMinor: 1,
          nextDue: DateTime(2026, 3, 5),
          frequency: 'weekly',
          anchorDay: 5,
          remindDaysBefore: 1,
        ),
      ],
    );
    expect(r.map((e) => e.id).toSet().length, r.length);
  });
}
