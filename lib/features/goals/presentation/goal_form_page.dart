import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/amount_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'goal_form_controller.dart';

class GoalFormPage extends GetView<GoalFormController> {
  const GoalFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? l10n.goalEdit : l10n.goalNew),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Obx(
                    () => TextField(
                      controller: controller.nameCtrl,
                      autofocus: !controller.isEditing,
                      maxLength: 30,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => controller.nameError.value = false,
                      decoration: InputDecoration(
                        labelText: l10n.goalName,
                        hintText: l10n.goalNameHint,
                        counterText: '',
                        errorText: controller.nameError.value
                            ? l10n.goalNameRequired
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => AmountField(
                      controller: controller.amountCtrl,
                      currency: controller.currency,
                      label: l10n.goalTarget,
                      errorText: controller.amountError.value
                          ? l10n.goalTargetRequired
                          : null,
                      onChanged: (_) => controller.amountError.value = false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.goalTargetDate, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Obx(() {
                    final date = controller.targetDate.value;
                    return Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            date == null
                                ? l10n.goalNoDate
                                : DateFormat.yMMMd().format(date),
                          ),
                          onPressed: () => _pickDate(context),
                        ),
                        if (date != null)
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).clearButtonTooltip,
                            onPressed: () => controller.targetDate.value = null,
                          ),
                      ],
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
                          final id = await controller.save();
                          if (id != null) Get.back<String>(result: id);
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = controller.targetDate.value;
    // An old date being edited must stay selectable.
    final first = current != null && current.isBefore(today) ? current : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today.add(const Duration(days: 90)),
      firstDate: first,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) controller.targetDate.value = picked;
  }
}
