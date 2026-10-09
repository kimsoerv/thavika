import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/debt_repository.dart';
import '../domain/debt_math.dart';

class DebtsController extends GetxController {
  DebtsController(this._repo, this.settings);

  final DebtRepository _repo;
  final SettingsService settings;
  final debts = <DebtWithPaid>[].obs;
  StreamSubscription<List<DebtWithPaid>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _repo.watchAll().listen(debts.assignAll);
  }

  DebtTotals get totals => debtTotals(
    debts.map(
      (d) => DebtLine(
        direction: d.debt.direction,
        amountMinor: d.debt.amountMinor,
        paidMinor: d.paidMinor,
      ),
    ),
  );

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

class DebtsPage extends GetView<DebtsController> {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.debtsTitle),
        actions: [
          IconButton(
            tooltip: l10n.debtAdd,
            icon: const Icon(Icons.add),
            onPressed: () => Get.toNamed(Routes.debtForm),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final list = controller.debts.toList();
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      size: 56,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.debtsEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Get.toNamed(Routes.debtForm),
                      child: Text(l10n.debtAdd),
                    ),
                  ],
                ),
              ),
            );
          }
          final currency = controller.settings.currency.value;
          final totals = controller.totals;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TotalCard(
                      label: l10n.debtOwedToMe,
                      amount: Money.format(totals.owedToMe, currency),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TotalCard(
                      label: l10n.debtIOwe,
                      amount: Money.format(totals.iOwe, currency),
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final item in list) DebtTile(item: item),
            ],
          );
        }),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              amount,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DebtTile extends StatelessWidget {
  const DebtTile({super.key, required this.item});

  final DebtWithPaid item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final d = item.debt;
    final left = outstanding(d.amountMinor, item.paidMinor);
    final lent = d.direction == 'lent';
    final due = d.dueOn;
    final overdue =
        left > 0 &&
        due != null &&
        due.isBefore(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        );
    final color = lent ? theme.colorScheme.primary : theme.colorScheme.error;

    return Card(
      child: ListTile(
        onTap: () => Get.toNamed(Routes.debtDetail, arguments: d.id),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(
            lent ? Icons.call_made : Icons.call_received,
            color: color,
            size: 20,
          ),
        ),
        title: Text(d.person),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (due != null && left > 0)
              Text(
                overdue
                    ? '${l10n.debtOverdue} · ${DateFormat.MMMd().format(due)}'
                    : l10n.debtDueOn(DateFormat.MMMd().format(due)),
                style: TextStyle(
                  color: overdue ? theme.colorScheme.error : null,
                ),
              ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: paidFraction(d.amountMinor, item.paidMinor),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
        trailing: Text(
          left == 0 ? l10n.debtSettled : Money.format(left, d.currency),
          style: theme.textTheme.titleSmall?.copyWith(
            color: left == 0 ? theme.colorScheme.onSurfaceVariant : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
