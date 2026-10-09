import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../transactions/data/transaction_repository.dart';
import '../data/plan_repository.dart';
import '../domain/plan_check.dart';
import 'reminder_service.dart';

/// Single source of truth for "this month": the entries, the active plan,
/// and how spending compares with the plan. Home and Plan both read from here.
class BudgetService extends GetxService with WidgetsBindingObserver {
  BudgetService(this._transactions, this._plans, this._reminders);

  final TransactionRepository _transactions;
  final PlanRepository _plans;
  final ReminderService _reminders;

  final month = _firstOfMonth(DateTime.now()).obs;
  final monthTx = <TxWithCategory>[].obs;
  final plan = Rxn<PlanWithItems>();
  final check = Rxn<PlanCheck>();

  StreamSubscription<List<TxWithCategory>>? _txSub;
  StreamSubscription<PlanWithItems?>? _planSub;
  String _signature = '';

  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month);

  Future<BudgetService> init() async {
    _listenTransactions();
    _listenPlan();
    WidgetsBinding.instance.addObserver(this);
    return this;
  }

  void _listenPlan() {
    _planSub?.cancel();
    _planSub = _plans.watchForMonth(month.value).listen((p) {
      plan.value = p;
      _recompute(notify: false);
    });
  }

  void _listenTransactions() {
    _txSub?.cancel();
    final from = month.value;
    final to = DateTime(from.year, from.month + 1);
    _signature = '';
    _txSub = _transactions.watchRange(from, to).listen((list) {
      monthTx.assignAll(list);
      final signature = _signatureOf(list);
      // Only warn when an entry was added, edited, or deleted since the last
      // emission, never for the first load.
      final changed = _signature.isNotEmpty && signature != _signature;
      _signature = signature;
      _recompute(notify: changed);
    });
  }

  String _signatureOf(List<TxWithCategory> list) {
    var sum = 0;
    var latest = 0;
    for (final e in list) {
      sum += e.tx.amountMinor + e.tx.categoryId.hashCode;
      final ms = e.tx.updatedAt.millisecondsSinceEpoch;
      if (ms > latest) latest = ms;
    }
    return '${list.length}:$sum:$latest';
  }

  void _recompute({required bool notify}) {
    final p = plan.value;
    if (p == null) {
      check.value = null;
      return;
    }
    final spent = <String, int>{};
    for (final e in monthTx) {
      if (e.tx.type != 'expense') continue;
      spent[e.tx.categoryId] = (spent[e.tx.categoryId] ?? 0) + e.tx.amountMinor;
    }
    final lines = [
      for (final i in p.items)
        PlanLine(
          id: i.id,
          group: i.groupName,
          name: i.name,
          categoryId: i.categoryId,
          budgetMinor: i.amountMinor,
          isFixed: i.isFixed,
        ),
    ];
    final next = computePlanCheck(
      lines: lines,
      spentByCategory: spent,
      today: DateTime.now(),
    );
    final prev = check.value;
    check.value = next;
    if (notify && prev != null) _reminders.evaluate(prev, next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final current = _firstOfMonth(DateTime.now());
    if (current != month.value) {
      month.value = current;
      _listenTransactions();
      _listenPlan();
    } else {
      _recompute(notify: false);
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _txSub?.cancel();
    _planSub?.cancel();
    super.onClose();
  }
}
