import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/ui/amount_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../entry/application/entry_meta_service.dart';
import '../data/debt_repository.dart';

class DebtFormController extends GetxController {
  DebtFormController(this._repo, this._settings, this.meta);

  final DebtRepository _repo;
  final SettingsService _settings;
  final EntryMetaService meta;

  DebtWithPaid? editing;

  final direction = 'lent'.obs;
  final startedOn = DateTime.now().obs;
  final dueOn = Rxn<DateTime>();
  final walletId = RxnString();
  final personError = false.obs;
  final amountError = false.obs;
  final saving = false.obs;
  final personCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  bool get isEditing => editing != null;
  String get currency => editing?.debt.currency ?? _settings.currency.value;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is DebtWithPaid) {
      editing = args;
      final d = args.debt;
      direction.value = d.direction;
      startedOn.value = d.startedOn;
      dueOn.value = d.dueOn;
      walletId.value = d.walletId;
      personCtrl.text = d.person;
      amountCtrl.text = Money.toInputText(d.amountMinor, d.currency);
      noteCtrl.text = d.note;
    } else if (args == 'borrowed') {
      direction.value = 'borrowed';
    }
  }

  Future<bool> save() async {
    if (saving.value) return false;
    final person = personCtrl.text.trim();
    final minor = Money.parseMinor(amountCtrl.text, currency);
    personError.value = person.isEmpty;
    amountError.value = minor <= 0;
    if (person.isEmpty || minor <= 0) return false;

    saving.value = true;
    try {
      final existing = editing;
      if (existing != null) {
        await _repo.update(
          existing.debt.id,
          person: person,
          direction: direction.value,
          amountMinor: minor,
          note: noteCtrl.text.trim(),
          startedOn: startedOn.value,
          dueOn: dueOn.value,
          walletId: walletId.value,
        );
      } else {
        await _repo.add(
          person: person,
          direction: direction.value,
          amountMinor: minor,
          currency: currency,
          note: noteCtrl.text.trim(),
          startedOn: startedOn.value,
          dueOn: dueOn.value,
          walletId: walletId.value,
        );
      }
      return true;
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    personCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.onClose();
  }
}

class DebtFormPage extends GetView<DebtFormController> {
  const DebtFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? l10n.debtEditTitle : l10n.debtAdd),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Obx(
                    () => SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'lent',
                          label: Text(l10n.debtLent),
                        ),
                        ButtonSegment(
                          value: 'borrowed',
                          label: Text(l10n.debtBorrowed),
                        ),
                      ],
                      selected: {controller.direction.value},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          controller.direction.value = s.first,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => TextField(
                      controller: controller.personCtrl,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: l10n.debtPerson,
                        counterText: '',
                        errorText: controller.personError.value
                            ? l10n.debtPersonRequired
                            : null,
                      ),
                      onChanged: (_) => controller.personError.value = false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => AmountField(
                      controller: controller.amountCtrl,
                      currency: controller.currency,
                      label: l10n.debtAmount,
                      errorText: controller.amountError.value
                          ? l10n.goalAmountRequired
                          : null,
                      onChanged: (_) => controller.amountError.value = false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller.noteCtrl,
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: l10n.noteHint,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.debtStarted, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Obx(
                      () => ActionChip(
                        avatar: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          DateFormat.yMMMd().format(controller.startedOn.value),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: controller.startedOn.value,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            controller.startedOn.value = picked;
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.debtDue, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Obx(() {
                    final due = controller.dueOn.value;
                    return Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.event, size: 18),
                          label: Text(
                            due == null
                                ? l10n.debtNoDue
                                : DateFormat.yMMMd().format(due),
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: due ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 10),
                              ),
                            );
                            if (picked != null) controller.dueOn.value = picked;
                          },
                        ),
                        if (due != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => controller.dueOn.value = null,
                          ),
                      ],
                    );
                  }),
                  Obx(() {
                    if (controller.meta.wallets.length < 2) {
                      return const SizedBox.shrink();
                    }
                    final selected =
                        controller.walletId.value ??
                        controller.meta.wallets.first.id;
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: selected,
                        decoration: InputDecoration(
                          labelText: l10n.entryWallet,
                        ),
                        items: [
                          for (final w in controller.meta.wallets)
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                        ],
                        onChanged: (v) => controller.walletId.value = v,
                      ),
                    );
                  }),
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
}
