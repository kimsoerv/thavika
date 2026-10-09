import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/ui/amount_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../entry/application/entry_meta_service.dart';
import '../data/transfer_repository.dart';

enum TransferError { amount, same }

class TransferFormController extends GetxController {
  TransferFormController(this._repo, this.meta, this._settings);

  final TransferRepository _repo;
  final EntryMetaService meta;
  final SettingsService _settings;

  /// Set when an existing transfer is being edited.
  TransferRow? editing;

  final from = RxnString();
  final to = RxnString();
  final date = DateTime.now().obs;
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final error = Rxn<TransferError>();
  final saving = false.obs;

  bool get isEditing => editing != null;
  String get currency => editing?.currency ?? _settings.currency.value;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is TransferRow) {
      editing = args;
      from.value = args.fromWalletId;
      to.value = args.toWalletId;
      date.value = args.occurredOn;
      amountCtrl.text = Money.toInputText(args.amountMinor, args.currency);
      noteCtrl.text = args.note;
    } else if (meta.wallets.length >= 2) {
      from.value = meta.wallets[0].id;
      to.value = meta.wallets[1].id;
    }
  }

  Future<bool> save() async {
    if (saving.value) return false;
    final minor = Money.parseMinor(amountCtrl.text, currency);
    if (minor <= 0) {
      error.value = TransferError.amount;
      return false;
    }
    final a = from.value;
    final b = to.value;
    if (a == null || b == null || a == b) {
      error.value = TransferError.same;
      return false;
    }
    saving.value = true;
    try {
      final existing = editing;
      if (existing == null) {
        await _repo.add(
          fromWalletId: a,
          toWalletId: b,
          amountMinor: minor,
          currency: currency,
          date: date.value,
          note: noteCtrl.text.trim(),
        );
      } else {
        await _repo.update(
          existing.id,
          fromWalletId: a,
          toWalletId: b,
          amountMinor: minor,
          date: date.value,
          note: noteCtrl.text.trim(),
        );
      }
      return true;
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.onClose();
  }
}

class TransferFormPage extends GetView<TransferFormController> {
  const TransferFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget picker(String label, RxnString value) {
      return Obx(
        () => DropdownButtonFormField<String>(
          initialValue: value.value,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final w in controller.meta.wallets)
              DropdownMenuItem(value: w.id, child: Text(w.name)),
          ],
          onChanged: (v) {
            value.value = v;
            controller.error.value = null;
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.isEditing ? l10n.transferEdit : l10n.transferTitle,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  picker(l10n.transferFrom, controller.from),
                  const SizedBox(height: 12),
                  picker(l10n.transferTo, controller.to),
                  const SizedBox(height: 12),
                  Obx(
                    () => AmountField(
                      controller: controller.amountCtrl,
                      currency: controller.currency,
                      autofocus: !controller.isEditing,
                      label: l10n.recurringAmount,
                      errorText: controller.error.value == TransferError.amount
                          ? l10n.transferAmountRequired
                          : null,
                      onChanged: (_) => controller.error.value = null,
                    ),
                  ),
                  Obx(
                    () => controller.error.value == TransferError.same
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.transferSame,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller.noteCtrl,
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: l10n.noteHint,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Obx(
                      () => ActionChip(
                        avatar: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          DateFormat.yMMMd().format(controller.date.value),
                        ),
                        onPressed: () => _pickDate(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Obx(
                () => FilledButton(
                  onPressed: controller.saving.value
                      ? null
                      : () async {
                          if (await controller.save()) Get.back<void>();
                        },
                  child: Text(l10n.save),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.date.value,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) controller.date.value = picked;
  }
}
