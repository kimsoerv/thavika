import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../sync/presentation/sync_badge.dart';
import '../../plan/domain/plan_check.dart';
import '../../plan/presentation/plan_labels.dart';
import '../../shell/presentation/shell_controller.dart';
import '../../transactions/presentation/tx_tile.dart';
import 'home_controller.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Obx(() {
        final currency = controller.currency;
        final hasEntries = controller.monthTx.isNotEmpty;
        final slices = controller.breakdown;
        final check = controller.check;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMM().format(controller.month),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SyncBadge(),
                IconButton(
                  tooltip: l10n.settingsTitle,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Get.toNamed(Routes.settings),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (check != null) ...[
              _SafeToSpend(
                amount: Money.format(check.safeToSpend, currency),
                status: check.overall,
                onTap: () => Get.find<ShellController>().tab.value =
                    ShellController.planTab,
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.balanceThisMonth,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Money.format(controller.balance, currency),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                            value: Money.format(controller.spent, currency),
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (controller.meta.wallets.length > 1) ...[
              const SizedBox(height: 16),
              _WalletsRow(controller: controller),
            ],
            const SizedBox(height: 20),
            if (!hasEntries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noEntriesTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.noEntriesBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.recent,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Get.find<ShellController>().tab.value =
                        ShellController.transactionsTab,
                    child: Text(l10n.tabTransactions),
                  ),
                ],
              ),
              for (final item in controller.recent)
                TxTile(
                  item: item,
                  showDate: true,
                  extra: controller.extraFor(item),
                  onTap: () => Get.toNamed(Routes.entry, arguments: item),
                ),
            ],
            if (slices.isNotEmpty && hasEntries) ...[
              const SizedBox(height: 12),
              Text(l10n.spendingByCategory, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      for (final s in slices)
                        Expanded(
                          flex: s.amountMinor,
                          child: Container(
                            margin: const EdgeInsets.only(right: 2),
                            color: s.category == null
                                ? theme.colorScheme.outline
                                : colorForCategory(s.category!.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final s in slices)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s.category == null
                                ? theme.colorScheme.outline
                                : colorForCategory(s.category!.id),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${s.category == null ? l10n.otherSlice : categoryDisplayName(l10n, s.category)} '
                          '${Money.format(s.amountMinor, currency)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _SafeToSpend extends StatelessWidget {
  const _SafeToSpend({
    required this.amount,
    required this.status,
    required this.onTap,
  });

  final String amount;
  final PaceStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = paceColor(status, theme.colorScheme);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.checkSafeToSpend,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                  Text(
                    amount,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
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
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Money in each wallet; tap to manage them.
class _WalletsRow extends StatelessWidget {
  const _WalletsRow({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final meta = controller.meta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.homeWallets, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final w in meta.wallets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Get.toNamed(Routes.wallets),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            w.name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            Money.format(meta.balances[w.id] ?? 0, w.currency),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
