import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/recurring_repository.dart';
import 'recurring_controllers.dart';

String frequencyLabel(AppLocalizations l10n, String frequency) =>
    frequency == 'weekly' ? l10n.frequencyWeekly : l10n.frequencyMonthly;

class RecurringListPage extends GetView<RecurringListController> {
  const RecurringListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recurringTitle),
        actions: [
          IconButton(
            tooltip: l10n.recurringAdd,
            icon: const Icon(Icons.add),
            onPressed: () => Get.toNamed(Routes.recurringForm),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final rules = controller.rules;
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 56,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.recurringEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Get.toNamed(Routes.recurringForm),
                      child: Text(l10n.recurringAdd),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              for (final item in rules)
                ListTile(
                  onTap: () =>
                      Get.toNamed(Routes.recurringForm, arguments: item),
                  leading: CircleAvatar(
                    backgroundColor: colorForCategory(
                      item.rule.categoryId,
                    ).withValues(alpha: 0.14),
                    child: Icon(
                      iconFor(item.category?.icon ?? ''),
                      color: colorForCategory(item.rule.categoryId),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    item.rule.note.isNotEmpty
                        ? item.rule.note
                        : categoryDisplayName(l10n, item.category),
                  ),
                  subtitle: Text(
                    item.rule.isActive
                        ? '${frequencyLabel(l10n, item.rule.frequency)} · '
                              '${l10n.recurringNext(DateFormat.yMMMd().format(item.rule.nextRunOn))}'
                        : l10n.recurringPaused,
                  ),
                  trailing: Text(
                    '${item.isIncome ? '+' : '-'}${Money.format(item.rule.amountMinor, item.rule.currency)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: item.isIncome ? theme.colorScheme.primary : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
