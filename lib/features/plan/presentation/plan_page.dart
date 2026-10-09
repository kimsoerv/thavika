import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../goals/presentation/goals_section.dart';
import '../domain/plan_check.dart';
import 'plan_controller.dart';
import 'plan_labels.dart';

class PlanPage extends GetView<PlanController> {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Obx(() {
        final plan = controller.plan;
        final check = controller.check;
        if (plan == null || check == null) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _EmptyState(onChoose: controller.openSetup),
              const SizedBox(height: 16),
              const GoalsSection(),
            ],
          );
        }

        final currency = controller.currency;
        final overall = check.overall;
        final overallColor = paceColor(overall, theme.colorScheme);
        final String summary;
        switch (overall) {
          case PaceStatus.onTrack:
            summary = l10n.checkSummaryOn;
          case PaceStatus.slightlyAhead:
            summary = l10n.checkSummaryMostly;
          case PaceStatus.offTrack:
          case PaceStatus.over:
            summary = l10n.checkSummaryOff(check.offTrackCount);
        }
        final savingLine =
            check.projectionReliable &&
                check.projectedSavings < check.plannedSavings
            ? l10n.checkSavingEstimate(
                Money.format(check.projectedSavings, currency),
                Money.format(check.plannedSavings, currency),
              )
            : l10n.checkSavingOnPlan(
                Money.format(check.plannedSavings, currency),
              );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.plan.name?.isNotEmpty == true
                        ? plan.plan.name!
                        : l10n.checkTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  l10n.checkDaysLeft(check.daysLeft),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: overallColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: overallColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(savingLine, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  Text(
                    l10n.checkSafeToSpend,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    Money.format(check.safeToSpend, currency),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.checkPaceLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final item in check.items)
              _ItemRow(
                item: item,
                currency: currency,
                monthProgress: controller.monthProgress,
              ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.checkPlannedSaving,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  Money.format(check.plannedSavings, currency),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _AdviceCard(controller: controller),
            const GoalsSection(),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(l10n.billsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(Routes.bills),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bookmarks_outlined),
                title: Text(l10n.plansTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: controller.openPlans,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text(l10n.settingsReminders),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(Routes.reminders),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: controller.openSetup,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.planChange),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.track_changes,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(l10n.planEmptyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.planEmptyBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onChoose, child: Text(l10n.planChoose)),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.currency,
    required this.monthProgress,
  });

  final ItemCheck item;
  final String currency;
  final double monthProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = paceColor(item.status, theme.colorScheme);
    final budget = item.line.budgetMinor;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planItemLabel(l10n, item.line.name),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${Money.format(item.spent, currency)} / ${Money.format(budget, currency)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              if (item.isFixed && item.status == PaceStatus.onTrack)
                Text(
                  l10n.planFixed,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    paceLabel(l10n, item.status),
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              final fill = item.used.clamp(0.0, 1.0) * width;
              return SizedBox(
                height: 14,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 8,
                      width: fill,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    if (!item.isFixed)
                      Positioned(
                        left: (monthProgress * width).clamp(0.0, width - 2),
                        child: Container(
                          width: 2,
                          height: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "Adjust to real life": moves between lines based on past months.
class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.controller});

  final PlanController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Obx(() {
      final moves = controller.advice.toList();
      final plan = controller.plan;
      if (moves.isEmpty || plan == null) return const SizedBox.shrink();

      String label(String lineId) {
        final item = plan.items.firstWhereOrNull((i) => i.id == lineId);
        return item == null ? '' : planItemLabel(l10n, item.name);
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.adviceTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(l10n.adviceBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              for (final m in moves)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    l10n.adviceMove(
                      Money.format(m.amountMinor, controller.currency),
                      label(m.fromLineId),
                      label(m.toLineId),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: controller.applyAdvice,
                    child: Text(l10n.adviceApply),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: controller.dismissAdvice,
                    child: Text(l10n.adviceDismiss),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}
