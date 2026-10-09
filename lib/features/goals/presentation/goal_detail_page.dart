import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/ui/amount_field.dart';
import '../../../core/ui/date_labels.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/goal_math.dart';
import 'challenge_section.dart';
import 'goal_detail_controller.dart';
import 'goals_section.dart';

class GoalDetailPage extends GetView<GoalDetailController> {
  const GoalDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Obx(() {
      final item = controller.goal.value;
      if (item == null) {
        return const Scaffold(body: SizedBox.shrink());
      }
      final goal = item.goal;
      final currency = goal.currency;
      final progress = goalProgress(
        targetMinor: goal.targetMinor,
        savedMinor: item.savedMinor,
        targetDate: goal.targetDate,
        today: DateTime.now(),
      );

      return Scaffold(
        appBar: AppBar(
          title: Text(goal.name),
          actions: [
            IconButton(
              tooltip: l10n.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Get.toNamed(Routes.goalForm, arguments: goal),
            ),
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: ProgressRing(
                        fraction: progress.fraction,
                        size: 150,
                        strokeWidth: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.goalSavedOf(
                        Money.format(item.savedMinor, currency),
                        Money.format(goal.targetMinor, currency),
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.isDone
                          ? l10n.goalReached
                          : l10n.goalRemaining(
                              Money.format(progress.remainingMinor, currency),
                            ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: goalColor,
                      ),
                    ),
                    if (goal.targetDate != null && !progress.isDone) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.goalDueBy(
                          DateFormat.yMMMd().format(goal.targetDate!),
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (progress.monthlyNeededMinor != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: goalColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          progress.isOverdue
                              ? l10n.goalOverdue
                              : l10n.goalPerMonth(
                                  Money.format(
                                    progress.monthlyNeededMinor!,
                                    currency,
                                  ),
                                ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: goalColor,
                          ),
                        ),
                      ),
                    ],
                    ChallengeSection(goalId: goal.id, currency: currency),
                    const SizedBox(height: 24),
                    Text(l10n.goalHistory, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Obx(() {
                      final list = controller.contributions;
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            l10n.goalNoHistory,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final c in list)
                            Dismissible(
                              key: ValueKey(c.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: theme.colorScheme.errorContainer,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                              onDismissed: (_) {
                                controller.removeContribution(c.id);
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      persist: false,
                                      duration: const Duration(seconds: 5),
                                      content: Text(l10n.entryDeleted),
                                      action: SnackBarAction(
                                        label: l10n.undo,
                                        onPressed: () => controller
                                            .restoreContribution(c.id),
                                      ),
                                    ),
                                  );
                              },
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(dayLabel(l10n, c.occurredOn)),
                                trailing: Text(
                                  '+${Money.format(c.amountMinor, currency)}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: goalColor,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        // In the bottom bar so a floating message sits above it, not on it.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: FilledButton.icon(
              onPressed: () => _addMoney(context, currency),
              icon: const Icon(Icons.add),
              label: Text(l10n.goalAddMoney),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _addMoney(BuildContext context, String currency) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _AddMoneySheet(currency: currency, onAdd: controller.addMoney),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.goalDeleteTitle),
        content: Text(l10n.goalDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.deleteGoal();
      Get.back<void>();
    }
  }
}

/// Bottom sheet to add money to a goal. It owns its text controller.
class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet({required this.currency, required this.onAdd});

  final String currency;
  final Future<void> Function(int amountMinor) onAdd;

  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  final _amount = TextEditingController();
  var _showError = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final minor = Money.parseMinor(_amount.text, widget.currency);
    if (minor <= 0) {
      setState(() => _showError = true);
      return;
    }
    await widget.onAdd(minor);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.goalAddMoney,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          AmountField(
            controller: _amount,
            currency: widget.currency,
            autofocus: true,
            errorText: _showError ? l10n.goalAmountRequired : null,
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: Text(l10n.add)),
        ],
      ),
    );
  }
}
