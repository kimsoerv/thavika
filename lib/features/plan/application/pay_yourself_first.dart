import 'package:get/get.dart';

import '../../../core/services/settings_service.dart';
import '../../goals/data/goal_repository.dart';
import '../domain/pay_yourself_first.dart';
import 'budget_service.dart';

/// What to suggest after the user records income.
class SavingsOffer {
  const SavingsOffer({required this.goals, required this.amountMinor});

  /// Goals that are not reached yet.
  final List<GoalWithSaved> goals;
  final int amountMinor;
}

/// Pay yourself first: when income comes in, offer to move the planned
/// saving to a goal straight away.
class PayYourselfFirst {
  PayYourselfFirst(this._budget, this._goals, this._settings);

  final BudgetService _budget;
  final GoalRepository _goals;
  final SettingsService _settings;

  /// Null when there is nothing to offer: no plan, no open goal, or the
  /// planned saving is already moved.
  Future<SavingsOffer?> offerFor(int incomeEntryMinor) async {
    final plan = _budget.plan.value;
    if (plan == null) return null;
    final planned = plan.items
        .where((i) => i.groupName == 'savings')
        .fold<int>(0, (s, i) => s + i.amountMinor);
    final moved = await _goals.watchMovedInMonth(DateTime.now()).first;
    final amount = suggestSetAside(
      plannedSavingsMinor: planned,
      planIncomeMinor: plan.plan.incomeMinor,
      movedThisMonthMinor: moved,
      incomeEntryMinor: incomeEntryMinor,
      currency: _settings.currency.value,
    );
    if (amount <= 0) return null;

    final open = (await _goals.watchGoals().first)
        .where((g) => g.savedMinor < g.goal.targetMinor)
        .toList();
    if (open.isEmpty) return null;
    return SavingsOffer(goals: open, amountMinor: amount);
  }

  Future<void> setAside(String goalId, int amountMinor) =>
      _goals.addContribution(
        goalId: goalId,
        amountMinor: amountMinor,
        date: DateTime.now(),
      );

  static PayYourselfFirst get to => Get.find();
}
