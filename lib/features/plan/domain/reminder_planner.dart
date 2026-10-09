import '../../recurring/domain/recurrence.dart';

enum ReminderKind { daily, savings, monthEnd, bill }

/// Which reminders the user wants.
class ReminderPrefs {
  const ReminderPrefs({
    this.daily = true,
    this.savings = true,
    this.monthEnd = true,
    this.bills = true,
    this.warnings = true,
    this.hour = 21,
    this.minute = 0,
  });

  final bool daily;
  final bool savings;
  final bool monthEnd;
  final bool bills;
  final bool warnings;
  final int hour;
  final int minute;
}

/// A bill that repeats: the next date it is due.
class BillInfo {
  const BillInfo({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.nextDue,
    required this.frequency,
    required this.anchorDay,
    required this.remindDaysBefore,
  });

  final String id;
  final String name;
  final int amountMinor;
  final DateTime nextDue;
  final String frequency;
  final int anchorDay;
  final int remindDaysBefore;
}

/// One notification to schedule. Text is chosen later, in the user's language.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    this.amountMinor,
    this.name,
    this.dueOn,
  });

  final int id;
  final ReminderKind kind;
  final DateTime at;

  /// Savings left to move, or the amount of a bill. Null when not known.
  final int? amountMinor;
  final String? name;
  final DateTime? dueOn;
}

/// Works out which notifications to schedule from what is known right now.
///
/// A phone cannot run code while the app is closed, so these are one-off
/// notifications for the coming days. The plan is rebuilt every time the app
/// opens or something changes, which is what makes "nothing recorded today"
/// smart: today's reminder is simply not scheduled once an entry exists.
class ReminderPlanner {
  ReminderPlanner._();

  static const dailyBase = 100;
  static const savingsBase = 200;
  static const monthEndBase = 300;
  static const billBase = 400;

  /// Days ahead that get a daily reminder.
  static const dailyHorizon = 7;

  /// Bills further away than this are planned the next time the app opens.
  static const billHorizonDays = 35;

  /// Days of the month the savings reminder fires on, at noon.
  static const savingsDays = [5, 20];

  static const maxBills = 40;

  static List<PlannedReminder> plan({
    required DateTime now,
    required ReminderPrefs prefs,
    required bool hasEntryToday,
    required int plannedSavingsMinor,
    required int movedToGoalsMinor,
    required List<BillInfo> bills,
  }) {
    final out = <PlannedReminder>[];
    final today = dateOnly(now);

    if (prefs.daily) {
      for (var i = 0; i < dailyHorizon; i++) {
        if (i == 0 && hasEntryToday) continue;
        final at = DateTime(
          today.year,
          today.month,
          today.day + i,
          prefs.hour,
          prefs.minute,
        );
        if (!at.isAfter(now)) continue;
        out.add(
          PlannedReminder(id: dailyBase + i, kind: ReminderKind.daily, at: at),
        );
      }
    }

    if (prefs.savings && plannedSavingsMinor > 0) {
      var slot = 0;
      for (var m = 0; m < 2; m++) {
        for (final day in savingsDays) {
          final at = DateTime(now.year, now.month + m, day, 12);
          if (!at.isAfter(now)) {
            slot++;
            continue;
          }
          // This month: only when the saving is not moved yet. Next month:
          // nothing is moved yet by definition.
          final left = plannedSavingsMinor - movedToGoalsMinor;
          if (m == 0 && left <= 0) {
            slot++;
            continue;
          }
          out.add(
            PlannedReminder(
              id: savingsBase + slot,
              kind: ReminderKind.savings,
              at: at,
              amountMinor: m == 0 ? left : null,
            ),
          );
          slot++;
        }
      }
    }

    if (prefs.monthEnd) {
      for (var m = 0; m < 2; m++) {
        final last = DateTime(now.year, now.month + m + 1, 0);
        final at = DateTime(last.year, last.month, last.day, 20);
        if (!at.isAfter(now)) continue;
        out.add(
          PlannedReminder(
            id: monthEndBase + m,
            kind: ReminderKind.monthEnd,
            at: at,
          ),
        );
      }
    }

    if (prefs.bills) {
      final horizon = today.add(const Duration(days: billHorizonDays));
      var n = 0;
      for (final bill in bills) {
        var due = dateOnly(bill.nextDue);
        var guard = 0;
        while (!due.isAfter(horizon) && guard++ < 12 && n < maxBills) {
          if (!due.isBefore(today)) {
            final at = DateTime(
              due.year,
              due.month,
              due.day - bill.remindDaysBefore,
              9,
            );
            if (at.isAfter(now)) {
              out.add(
                PlannedReminder(
                  id: billBase + n,
                  kind: ReminderKind.bill,
                  at: at,
                  amountMinor: bill.amountMinor,
                  name: bill.name,
                  dueOn: due,
                ),
              );
              n++;
            }
          }
          due = advance(due, bill.frequency, bill.anchorDay);
        }
      }
    }

    return out;
  }
}
