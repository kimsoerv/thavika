import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/amount_field.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'recurring_controllers.dart';

class RecurringFormPage extends GetView<RecurringFormController> {
  const RecurringFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.isEditing ? l10n.recurringEdit : l10n.recurringNew,
        ),
        actions: [
          if (controller.isEditing)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
        ],
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
                          value: 'expense',
                          label: Text(l10n.expense),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text(l10n.income),
                        ),
                      ],
                      selected: {controller.type.value},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => controller.setType(s.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => AmountField(
                      controller: controller.amountCtrl,
                      currency: controller.currency,
                      label: l10n.recurringAmount,
                      errorText: controller.amountError.value
                          ? l10n.amountRequired
                          : null,
                      onChanged: (_) => controller.amountError.value = false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final c in controller.categories)
                          ChoiceChip(
                            avatar: Icon(
                              iconFor(c.icon),
                              size: 18,
                              color: colorForCategory(c.id),
                            ),
                            label: Text(categoryDisplayName(l10n, c)),
                            selected: controller.categoryId.value == c.id,
                            onSelected: (_) {
                              controller.categoryId.value = c.id;
                              controller.categoryError.value = false;
                            },
                          ),
                      ],
                    ),
                  ),
                  Obx(
                    () => controller.categoryError.value
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.categoryRequired,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          )
                        : const SizedBox.shrink(),
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
                  const SizedBox(height: 16),
                  Text(
                    l10n.recurringFrequency,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'weekly',
                          label: Text(l10n.frequencyWeekly),
                        ),
                        ButtonSegment(
                          value: 'monthly',
                          label: Text(l10n.frequencyMonthly),
                        ),
                      ],
                      selected: {controller.frequency.value},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          controller.frequency.value = s.first,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.recurringFirstDate,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Obx(
                      () => ActionChip(
                        avatar: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          DateFormat.yMMMd().format(controller.startOn.value),
                        ),
                        onPressed: () => _pickDate(context),
                      ),
                    ),
                  ),
                  Obx(
                    () => controller.type.value == 'expense'
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.recurringIsBill),
                                subtitle: Text(l10n.recurringIsBillHint),
                                value: controller.isBill.value,
                                onChanged: (v) => controller.isBill.value = v,
                              ),
                              if (controller.isBill.value)
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(l10n.recurringAutoCreate),
                                  subtitle: controller.autoCreate.value
                                      ? null
                                      : Text(l10n.recurringAutoCreateOff),
                                  value: controller.autoCreate.value,
                                  onChanged: (v) =>
                                      controller.autoCreate.value = v,
                                ),
                              if (controller.isBill.value)
                                DropdownButton<int>(
                                  value: controller.remindDays.value,
                                  items: [
                                    for (final d in const [0, 1, 2, 3, 5, 7])
                                      DropdownMenuItem(
                                        value: d,
                                        child: Text(
                                          l10n.recurringRemindDays(d),
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      controller.remindDays.value = v;
                                    }
                                  },
                                ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (controller.isEditing)
                    Obx(
                      () => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.recurringActive),
                        value: controller.isActive.value,
                        onChanged: (v) => controller.isActive.value = v,
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
      initialDate: controller.startOn.value,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) controller.startOn.value = picked;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.recurringDeleteTitle),
        content: Text(l10n.recurringDeleteBody),
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
    if (ok == true) {
      await controller.delete();
      Get.back<void>();
    }
  }
}
