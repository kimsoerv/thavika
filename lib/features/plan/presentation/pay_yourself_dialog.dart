import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/amount_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/pay_yourself_first.dart';

/// Offers to move part of new income to a goal. Does nothing when there is
/// nothing to offer.
Future<void> offerPayYourselfFirst(
  BuildContext context, {
  required PayYourselfFirst service,
  required int incomeMinor,
  required String currency,
}) async {
  final offer = await service.offerFor(incomeMinor);
  if (offer == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _PayYourselfDialog(
      service: service,
      offer: offer,
      incomeMinor: incomeMinor,
      currency: currency,
    ),
  );
}

class _PayYourselfDialog extends StatefulWidget {
  const _PayYourselfDialog({
    required this.service,
    required this.offer,
    required this.incomeMinor,
    required this.currency,
  });

  final PayYourselfFirst service;
  final SavingsOffer offer;
  final int incomeMinor;
  final String currency;

  @override
  State<_PayYourselfDialog> createState() => _PayYourselfDialogState();
}

class _PayYourselfDialogState extends State<_PayYourselfDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: Money.toInputText(widget.offer.amountMinor, widget.currency),
  );
  late String _goalId = widget.offer.goals.first.goal.id;
  bool _error = false;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minor = Money.parseMinor(_amount.text, widget.currency);
    if (minor <= 0) {
      setState(() => _error = true);
      return;
    }
    setState(() => _busy = true);
    await widget.service.setAside(_goalId, minor);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.payFirstTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.payFirstBody(
                Money.format(widget.incomeMinor, widget.currency),
                Money.format(widget.offer.amountMinor, widget.currency),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.offer.goals.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _goalId,
                decoration: InputDecoration(labelText: l10n.payFirstGoal),
                items: [
                  for (final g in widget.offer.goals)
                    DropdownMenuItem(
                      value: g.goal.id,
                      child: Text(g.goal.name),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _goalId = v);
                },
              ),
              const SizedBox(height: 12),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.offer.goals.first.goal.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            AmountField(
              controller: _amount,
              currency: widget.currency,
              errorText: _error ? l10n.goalAmountRequired : null,
              onChanged: (_) {
                if (_error) setState(() => _error = false);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.payFirstSkip),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.payFirstSet),
        ),
      ],
    );
  }
}
