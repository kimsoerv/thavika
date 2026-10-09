import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/ui/amount_field.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/recurring_repository.dart';
import '../domain/bill_math.dart';

class BillsController extends GetxController {
  BillsController(this._repo);

  final RecurringRepository _repo;
  final bills = <RecurringWithCategory>[].obs;
  StreamSubscription<List<RecurringWithCategory>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _repo.watchAll().listen((all) {
      bills.assignAll(
        all.where(
          (r) => r.rule.isBill && r.rule.isActive && r.rule.type == 'expense',
        ),
      );
    });
  }

  int get monthlyTotal => bills.fold(
    0,
    (sum, b) => sum + monthlyEquivalent(b.rule.amountMinor, b.rule.frequency),
  );

  Future<void> markPaid(RecurringWithCategory bill, int amountMinor) =>
      _repo.markPaid(bill.rule.id, amountMinor: amountMinor);

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

class BillsPage extends GetView<BillsController> {
  const BillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.billsTitle),
        actions: [
          IconButton(
            tooltip: l10n.billsAdd,
            icon: const Icon(Icons.add),
            onPressed: () =>
                Get.toNamed(Routes.recurringForm, arguments: 'bill'),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final bills = controller.bills.toList()
            ..sort((a, b) => a.rule.nextRunOn.compareTo(b.rule.nextRunOn));
          if (bills.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 56,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.billsEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () =>
                          Get.toNamed(Routes.recurringForm, arguments: 'bill'),
                      child: Text(l10n.billsAdd),
                    ),
                  ],
                ),
              ),
            );
          }
          final currency = bills.first.rule.currency;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  l10n.billsMonthly(
                    Money.format(controller.monthlyTotal, currency),
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final bill in bills) _BillTile(bill: bill),
            ],
          );
        }),
      ),
    );
  }
}

class _BillTile extends GetView<BillsController> {
  const _BillTile({required this.bill});

  final RecurringWithCategory bill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rule = bill.rule;
    final status = billStatus(rule.nextRunOn, DateTime.now());
    final String statusText;
    final Color statusColor;
    switch (status.state) {
      case BillState.overdue:
        statusText = l10n.billOverdue(status.days);
        statusColor = theme.colorScheme.error;
      case BillState.dueToday:
        statusText = l10n.billDueToday;
        statusColor = const Color(0xFFB26A00);
      case BillState.upcoming:
        statusText = l10n.billDueIn(status.days);
        statusColor = theme.colorScheme.onSurfaceVariant;
    }
    final waiting = !rule.autoCreate;

    return ListTile(
      onTap: () => Get.toNamed(Routes.recurringForm, arguments: bill),
      leading: CircleAvatar(
        backgroundColor: colorForCategory(
          rule.categoryId,
        ).withValues(alpha: 0.14),
        child: Icon(
          iconFor(bill.category?.icon ?? ''),
          color: colorForCategory(rule.categoryId),
          size: 22,
        ),
      ),
      title: Text(
        rule.note.isNotEmpty
            ? rule.note
            : categoryDisplayName(l10n, bill.category),
      ),
      subtitle: Text(
        '${DateFormat.MMMd().format(rule.nextRunOn)} · $statusText',
        style: TextStyle(color: statusColor),
      ),
      trailing: waiting
          ? FilledButton.tonal(
              onPressed: () => _markPaid(context),
              child: Text(l10n.billMarkPaid),
            )
          : Text(
              Money.format(rule.amountMinor, rule.currency),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Future<void> _markPaid(BuildContext context) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _PaidDialog(
        currency: bill.rule.currency,
        initialMinor: bill.rule.amountMinor,
      ),
    );
    if (amount == null) return;
    await controller.markPaid(bill, amount);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          persist: false,
          duration: const Duration(seconds: 3),
          content: Text(AppLocalizations.of(context).billPaidDone),
        ),
      );
  }
}

class _PaidDialog extends StatefulWidget {
  const _PaidDialog({required this.currency, required this.initialMinor});

  final String currency;
  final int initialMinor;

  @override
  State<_PaidDialog> createState() => _PaidDialogState();
}

class _PaidDialogState extends State<_PaidDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: Money.toInputText(widget.initialMinor, widget.currency),
  );
  bool _error = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.billPaidTitle),
      content: AmountField(
        controller: _amount,
        currency: widget.currency,
        autofocus: true,
        errorText: _error ? l10n.goalAmountRequired : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final minor = Money.parseMinor(_amount.text, widget.currency);
            if (minor <= 0) {
              setState(() => _error = true);
              return;
            }
            Navigator.pop(context, minor);
          },
          child: Text(l10n.billMarkPaid),
        ),
      ],
    );
  }
}
