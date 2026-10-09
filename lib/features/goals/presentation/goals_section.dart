import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/goal_math.dart';
import 'goals_controller.dart';

const goalColor = Color(0xFF2E7D32);

/// "Savings goals" block for the Plan tab.
class GoalsSection extends GetView<GoalsController> {
  const GoalsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Obx(() {
      final goals = controller.goals;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.goalsTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => Get.toNamed(Routes.goalForm),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.goalNew),
              ),
            ],
          ),
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.goalsEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final item in goals)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GoalCard(
                  name: item.goal.name,
                  currency: item.goal.currency,
                  targetMinor: item.goal.targetMinor,
                  savedMinor: item.savedMinor,
                  targetDate: item.goal.targetDate,
                  onTap: () =>
                      Get.toNamed(Routes.goalDetail, arguments: item.goal.id),
                ),
              ),
        ],
      );
    });
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.name,
    required this.currency,
    required this.targetMinor,
    required this.savedMinor,
    required this.targetDate,
    required this.onTap,
  });

  final String name;
  final String currency;
  final int targetMinor;
  final int savedMinor;
  final DateTime? targetDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final progress = goalProgress(
      targetMinor: targetMinor,
      savedMinor: savedMinor,
      targetDate: targetDate,
      today: DateTime.now(),
    );

    final String detail;
    if (progress.isDone) {
      detail = l10n.goalReached;
    } else if (progress.monthlyNeededMinor != null) {
      detail = progress.isOverdue
          ? l10n.goalOverdue
          : l10n.goalPerMonth(
              Money.format(progress.monthlyNeededMinor!, currency),
            );
    } else {
      detail = l10n.goalRemaining(
        Money.format(progress.remainingMinor, currency),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProgressRing(fraction: progress.fraction, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      l10n.goalSavedOf(
                        Money.format(savedMinor, currency),
                        Money.format(targetMinor, currency),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      targetDate == null || progress.isDone
                          ? detail
                          : '$detail · ${l10n.goalDueBy(DateFormat.yMMMd().format(targetDate!))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: goalColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circle that fills as the goal is reached, with the percentage inside.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.fraction,
    required this.size,
    this.strokeWidth = 6,
  });

  final double fraction;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: fraction,
            strokeWidth: strokeWidth,
            strokeCap: StrokeCap.round,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            color: goalColor,
          ),
          Center(
            child: Text(
              '${(fraction * 100).floor()}%',
              style:
                  (size > 100
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.labelMedium)
                      ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
