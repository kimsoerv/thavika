import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/services/settings_service.dart';
import '../../transactions/data/transaction_repository.dart';
import '../application/budget_service.dart';
import '../application/reminder_service.dart';
import '../data/plan_repository.dart';
import '../domain/plan_advisor.dart';
import '../domain/plan_check.dart';
import '../domain/plan_templates.dart';

/// Backs the Plan tab: the plan check, advice on the plan, and saved plans.
class PlanController extends GetxController {
  PlanController(
    this.budget,
    this.reminders,
    this.settings,
    this._plans,
    this._transactions,
  );

  final BudgetService budget;
  final ReminderService reminders;
  final SettingsService settings;
  final PlanRepository _plans;
  final TransactionRepository _transactions;

  static const _dismissedKey = 'advice_dismissed';

  /// Moves that would fit the plan to how money was really spent.
  final advice = <AdviceMove>[].obs;

  PlanWithItems? get plan => budget.plan.value;
  PlanCheck? get check => budget.check.value;
  String get currency => plan?.plan.currency ?? settings.currency.value;

  /// How far through the month we are (0 to 1); where the pace marker sits.
  double get monthProgress {
    final now = DateTime.now();
    return now.day / daysInMonth(now);
  }

  @override
  void onInit() {
    super.onInit();
    ever(budget.plan, (_) => loadAdvice());
    loadAdvice();
  }

  void openSetup() => Get.toNamed(Routes.planSetup, arguments: plan);

  void openPlans() => Get.toNamed(Routes.plans);

  String _monthKey(DateTime d) => '${d.year}-${d.month}';

  /// Looks at the last two full months that the current plan covered.
  Future<void> loadAdvice() async {
    final current = plan;
    if (current == null) {
      advice.clear();
      return;
    }
    final now = DateTime.now();
    if (await settings.getString(_dismissedKey) == _monthKey(now)) {
      advice.clear();
      return;
    }

    final startedOn = current.plan.activeFrom;
    final months = <Map<String, int>>[];
    for (var back = 1; back <= 2; back++) {
      final from = DateTime(now.year, now.month - back);
      if (startedOn != null &&
          from.isBefore(DateTime(startedOn.year, startedOn.month))) {
        continue;
      }
      final spent = await _transactions.expenseByCategory(
        from,
        DateTime(from.year, from.month + 1),
      );
      if (spent.isNotEmpty) months.add(spent);
    }

    advice.assignAll(
      PlanAdvisor.suggest(
        lines: [
          for (final i in current.items)
            AdviceLine(
              id: i.id,
              categoryId: i.categoryId,
              group: i.groupName,
              budgetMinor: i.amountMinor,
              isFixed: i.isFixed,
            ),
        ],
        spentByMonth: months,
        currency: current.plan.currency,
      ),
    );
  }

  /// Saves the moves into the plan, from this month on.
  Future<void> applyAdvice() async {
    final current = plan;
    if (current == null || advice.isEmpty) return;
    final change = <String, int>{};
    for (final m in advice) {
      change[m.fromLineId] = (change[m.fromLineId] ?? 0) - m.amountMinor;
      change[m.toLineId] = (change[m.toLineId] ?? 0) + m.amountMinor;
    }
    await _plans.savePlan(
      template: current.plan.template,
      incomeMinor: current.plan.incomeMinor,
      currency: current.plan.currency,
      name: current.plan.name,
      items: [
        for (final i in current.items)
          PlanItemDraft(
            group: i.groupName,
            name: i.name,
            categoryId: i.categoryId,
            amountMinor: i.amountMinor + (change[i.id] ?? 0),
            isFixed: i.isFixed,
          ),
      ],
    );
    advice.clear();
  }

  Future<void> dismissAdvice() async {
    await settings.setString(_dismissedKey, _monthKey(DateTime.now()));
    advice.clear();
  }
}
