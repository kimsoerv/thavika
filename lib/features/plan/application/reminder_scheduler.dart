import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../goals/data/goal_repository.dart';
import '../../recurring/data/recurring_repository.dart';
import '../domain/reminder_planner.dart';
import 'budget_service.dart';
import 'reminder_service.dart';

/// Keeps the scheduled reminders in step with the data: when an entry, a
/// plan, a goal deposit, a bill or a reminder setting changes, and when the
/// app comes back to the front (a new day).
class ReminderScheduler extends GetxService with WidgetsBindingObserver {
  ReminderScheduler(this._reminders, this._budget, this._goals, this._bills);

  final ReminderService _reminders;
  final BudgetService _budget;
  final GoalRepository _goals;
  final RecurringRepository _bills;

  final _moved = 0.obs;
  final _billList = <BillInfo>[].obs;
  final _workers = <Worker>[];
  StreamSubscription<int>? _movedSub;
  StreamSubscription<List<RecurringWithCategory>>? _billSub;
  DateTime? _movedMonth;
  Timer? _debounce;

  Future<ReminderScheduler> init() async {
    _listenMoved();
    _billSub = _bills.watchAll().listen((rules) {
      _billList.assignAll([
        for (final r in rules)
          if (r.rule.isBill && r.rule.isActive && r.rule.type == 'expense')
            BillInfo(
              id: r.rule.id,
              name: r.rule.note.isNotEmpty
                  ? r.rule.note
                  : (r.category?.name ?? ''),
              amountMinor: r.rule.amountMinor,
              nextDue: r.rule.nextRunOn,
              frequency: r.rule.frequency,
              anchorDay: r.rule.startOn.day,
              remindDaysBefore: r.rule.remindDaysBefore,
            ),
      ]);
    });

    _workers.addAll([
      ever(_budget.monthTx, (_) => _schedule()),
      ever(_budget.plan, (_) => _schedule()),
      ever(_moved, (_) => _schedule()),
      ever(_billList, (_) => _schedule()),
      ever(_reminders.changes, (_) => _schedule()),
    ]);
    WidgetsBinding.instance.addObserver(this);
    _schedule();
    return this;
  }

  void _listenMoved() {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    if (_movedMonth == month) return;
    _movedMonth = month;
    _movedSub?.cancel();
    _movedSub = _goals.watchMovedInMonth(month).listen((v) => _moved.value = v);
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _run);
  }

  Future<void> _run() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hasEntryToday = _budget.monthTx.any((e) {
      final d = e.tx.occurredOn;
      return DateTime(d.year, d.month, d.day) == today;
    });
    final planned =
        _budget.plan.value?.items
            .where((i) => i.groupName == 'savings')
            .fold<int>(0, (s, i) => s + i.amountMinor) ??
        0;

    final list = ReminderPlanner.plan(
      now: now,
      prefs: _reminders.prefs,
      hasEntryToday: hasEntryToday,
      plannedSavingsMinor: planned,
      movedToGoalsMinor: _moved.value,
      bills: _billList.toList(),
    );
    try {
      await _reminders.apply(list);
    } catch (_) {
      // Scheduling can fail on a phone that blocks exact alarms; the app
      // keeps working and tries again at the next change.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _listenMoved();
    _schedule();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _movedSub?.cancel();
    _billSub?.cancel();
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }
}
