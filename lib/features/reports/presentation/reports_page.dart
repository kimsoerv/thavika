import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/bar_chart.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../core/ui/share_file.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'reports_controller.dart';

class ReportsPage extends GetView<ReportsController> {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Obx(() {
        final currency = controller.currency;
        final categories = controller.byCategory;
        final spent = controller.spent;
        final maxAmount = categories.isEmpty ? 1 : categories.first.amountMinor;

        final String comparison;
        if (!controller.hasPrevious) {
          comparison = l10n.reportNoLast;
        } else {
          final diff = spent - controller.previousSpent;
          if (diff == 0) {
            comparison = l10n.reportSame;
          } else if (diff < 0) {
            comparison = l10n.reportLess(Money.format(-diff, currency));
          } else {
            comparison = l10n.reportMore(Money.format(diff, currency));
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: l10n.previousMonth,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => controller.shiftMonth(-1),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(controller.month.value),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.nextMonth,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => controller.shiftMonth(1),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: l10n.income,
                          value: Money.format(controller.income, currency),
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: l10n.spent,
                          value: Money.format(spent, currency),
                          color: theme.colorScheme.error,
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: l10n.reportLeftOver,
                          value: Money.format(controller.leftOver, currency),
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(comparison, style: theme.textTheme.bodyMedium),
                  ),
                  const SizedBox(height: 20),
                  Text(l10n.reportDaily, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _DailyChart(controller: controller),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.reportTrend,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      _Legend(
                        color: theme.colorScheme.primary,
                        label: l10n.income,
                      ),
                      const SizedBox(width: 12),
                      _Legend(
                        color: theme.colorScheme.error,
                        label: l10n.spent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _TrendChart(controller: controller),
                  const SizedBox(height: 20),
                  Text(
                    l10n.spendingByCategory,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        l10n.reportNoSpending,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    categoryDisplayName(l10n, c.category),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '${Money.format(c.amountMinor, currency)} · '
                                  '${spent == 0 ? 0 : (c.amountMinor * 100 / spent).round()}%',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: c.amountMinor / maxAmount,
                                minHeight: 8,
                                color: colorForCategory(c.categoryId),
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHigh,
                              ),
                            ),
                          ],
                        ),
                      ),
                  _WalletSection(controller: controller),
                  _TagSection(controller: controller),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final path = await controller.exportMonth();
                      if (!context.mounted) return;
                      if (path == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(l10n.nothingToExport),
                          ),
                        );
                        return;
                      }
                      await shareFile(context, path);
                    },
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(l10n.reportExportMonth),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final path = await controller.exportMonthExcel();
                      if (!context.mounted) return;
                      if (path == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text(l10n.nothingToExport),
                          ),
                        );
                        return;
                      }
                      await shareFile(context, path);
                    },
                    icon: const Icon(Icons.grid_on_outlined),
                    label: Text(l10n.reportExportExcel),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final days = controller.dailySpending;
    final now = DateTime.now();
    final month = controller.month.value;
    final isThisMonth = now.year == month.year && now.month == month.month;
    final total = days.fold<int>(0, (s, v) => s + v);
    if (total == 0) {
      return Text(
        l10n.reportNoSpending,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    var busiest = 0;
    for (var i = 1; i < days.length; i++) {
      if (days[i] > days[busiest]) busiest = i;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BarChart(
          semanticLabel: l10n.reportDaily,
          colors: [theme.colorScheme.error.withValues(alpha: 0.75)],
          labelEvery: 5,
          groups: [
            for (var i = 0; i < days.length; i++)
              BarGroup(
                label: '${i + 1}',
                values: [days[i]],
                highlight: isThisMonth && now.day == i + 1,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.reportBusiestDay(
            DateFormat.MMMd().format(
              DateTime(month.year, month.month, busiest + 1),
            ),
            Money.format(days[busiest], controller.currency),
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final months = controller.trend;
    return BarChart(
      semanticLabel: l10n.reportTrend,
      colors: [theme.colorScheme.primary, theme.colorScheme.error],
      groups: [
        for (final m in months)
          BarGroup(
            label: DateFormat.MMM().format(m.month),
            values: [m.income, m.spent],
            highlight: m.month == controller.month.value,
          ),
      ],
    );
  }
}

class _AmountBars extends StatelessWidget {
  const _AmountBars({
    required this.title,
    required this.rows,
    required this.currency,
    this.hint,
  });

  final String title;
  final List<MapEntry<String, int>> rows;
  final String currency;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = rows.isEmpty ? 1 : rows.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: theme.textTheme.titleSmall),
        if (hint != null)
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.key)),
                    Text(
                      Money.format(r.value, currency),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max <= 0 ? 0 : r.value / max,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WalletSection extends StatelessWidget {
  const _WalletSection({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wallets = controller.walletTotals;
    if (wallets.isEmpty) return const SizedBox.shrink();
    return _AmountBars(
      title: l10n.reportByWallet,
      currency: controller.currency,
      rows: [for (final w in wallets) MapEntry(w.key, w.value.spent)],
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tags = controller.tagTotals;
    if (tags.isEmpty) return const SizedBox.shrink();
    return _AmountBars(
      title: l10n.reportByTag,
      hint: l10n.reportByTagHint,
      currency: controller.currency,
      rows: [for (final t in tags) MapEntry('#${t.key}', t.value)],
    );
  }
}
