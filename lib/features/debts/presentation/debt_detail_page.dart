import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/ui/amount_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/debt_repository.dart';
import '../domain/debt_math.dart';

class DebtDetailController extends GetxController {
  DebtDetailController(this._repo);

  final DebtRepository _repo;
  final debtId = Get.arguments is String ? Get.arguments as String : '';
  final item = Rxn<DebtWithPaid>();
  final payments = <DebtPaymentRow>[].obs;
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void onInit() {
    super.onInit();
    _subs.add(
      _repo.watchAll().listen(
        (all) => item.value = all.firstWhereOrNull((d) => d.debt.id == debtId),
      ),
    );
    _subs.add(_repo.watchPayments(debtId).listen(payments.assignAll));
  }

  Future<void> addPayment(int amountMinor) => _repo.addPayment(
    debtId: debtId,
    amountMinor: amountMinor,
    date: DateTime.now(),
  );

  Future<void> deletePayment(String id) => _repo.deletePayment(id);

  Future<void> restorePayment(String id) => _repo.restorePayment(id);

  Future<void> deleteDebt() => _repo.delete(debtId);

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }
}

class DebtDetailPage extends GetView<DebtDetailController> {
  const DebtDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Obx(() {
      final item = controller.item.value;
      if (item == null) return const Scaffold(body: SizedBox.shrink());
      final d = item.debt;
      final left = outstanding(d.amountMinor, item.paidMinor);
      final lent = d.direction == 'lent';
      final color = lent ? theme.colorScheme.primary : theme.colorScheme.error;

      return Scaffold(
        appBar: AppBar(
          title: Text(d.person),
          actions: [
            IconButton(
              tooltip: l10n.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Get.toNamed(Routes.debtForm, arguments: item),
            ),
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
        bottomNavigationBar: left > 0
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(l10n.debtAddPayment),
                    onPressed: () => _addPayment(context, d, left),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                lent ? l10n.debtLent : l10n.debtBorrowed,
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
              const SizedBox(height: 4),
              Text(
                left == 0
                    ? l10n.debtSettled
                    : l10n.debtLeft(Money.format(left, d.currency)),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: paidFraction(d.amountMinor, item.paidMinor),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.debtPaidOf(
                  Money.format(item.paidMinor, d.currency),
                  Money.format(d.amountMinor, d.currency),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMd().format(d.startedOn) +
                    (d.dueOn != null
                        ? ' · ${l10n.debtDueOn(DateFormat.yMMMd().format(d.dueOn!))}'
                        : ''),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (d.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(d.note),
              ],
              const SizedBox(height: 24),
              Text(l10n.debtPayments, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Obx(() {
                final list = controller.payments;
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l10n.debtNoPayments,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final p in list)
                      Dismissible(
                        key: ValueKey(p.id),
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
                        onDismissed: (_) async {
                          await controller.deletePayment(p.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                persist: false,
                                duration: const Duration(seconds: 4),
                                content: Text(l10n.entryDeleted),
                                action: SnackBarAction(
                                  label: l10n.undo,
                                  onPressed: () =>
                                      controller.restorePayment(p.id),
                                ),
                              ),
                            );
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(Money.format(p.amountMinor, d.currency)),
                          subtitle: Text(
                            DateFormat.yMMMd().format(p.occurredOn),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _addPayment(BuildContext context, DebtRow d, int left) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _PaymentDialog(currency: d.currency, initialMinor: left),
    );
    if (amount != null) await controller.addPayment(amount);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.debtDeleteTitle),
        content: Text(l10n.debtDeleteBody),
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
    if (ok != true) return;
    await controller.deleteDebt();
    Get.back<void>();
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.currency, required this.initialMinor});

  final String currency;
  final int initialMinor;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
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
      title: Text(l10n.debtAddPayment),
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
          child: Text(l10n.add),
        ),
      ],
    );
  }
}
