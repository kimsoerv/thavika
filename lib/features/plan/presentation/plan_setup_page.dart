import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/plan_templates.dart';
import 'plan_labels.dart';
import 'plan_setup_controller.dart';

class PlanSetupPage extends GetView<PlanSetupController> {
  const PlanSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.isEditing ? l10n.planEditTitle : l10n.planSetupTitle,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  TextField(
                    controller: controller.nameCtrl,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: l10n.planNameLabel,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.planIncomeLabel, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Obx(
                    () => TextField(
                      controller: controller.incomeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: theme.textTheme.titleLarge,
                      onChanged: controller.onIncomeChanged,
                      decoration: InputDecoration(
                        prefixText: Money.symbolFor(controller.currency),
                        hintText: '0',
                        errorText: controller.incomeError.value
                            ? l10n.planIncomeRequired
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(() {
                    final selected = controller.templateIndex.value;
                    return GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 2.3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var i = 0; i < PlanTemplates.all.length; i++)
                          _TemplateCard(
                            title: templateName(l10n, PlanTemplates.all[i].id),
                            hint: templateHint(l10n, PlanTemplates.all[i].id),
                            selected: i == selected,
                            onTap: () => controller.selectTemplate(i),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    l10n.planGuidance,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GoalsCard(controller: controller),
                  _SplitBar(controller: controller),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.planYourCategories,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Obx(
                        () =>
                            controller.editMode.value && controller.dirty.value
                            ? TextButton(
                                onPressed: controller.reset,
                                child: Text(l10n.planReset),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Obx(
                        () => TextButton.icon(
                          onPressed: controller.toggleEdit,
                          icon: Icon(
                            controller.editMode.value
                                ? Icons.check
                                : Icons.edit_outlined,
                            size: 18,
                          ),
                          label: Text(
                            controller.editMode.value
                                ? l10n.planDone
                                : l10n.planEdit,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _ItemList(controller: controller),
                  const SizedBox(height: 12),
                  _LeftBox(controller: controller),
                  const SizedBox(height: 8),
                  _SavingBox(controller: controller),
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
                          final ok = await controller.use();
                          if (ok) Get.back<bool>(result: true);
                        },
                  child: Text(l10n.planUse),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.controller});

  final PlanSetupController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final income = controller.incomeMinor.value;
    final groups = controller.groups;
    final totals = {for (final g in groups) g: controller.totalFor(g)};
    final sum = totals.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: sum == 0
                ? ColoredBox(color: theme.colorScheme.surfaceContainerHigh)
                : Row(
                    children: [
                      for (final g in groups)
                        if (totals[g]! > 0)
                          Expanded(
                            flex: totals[g]!,
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              color: groupColor(g),
                            ),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final g in groups)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: groupColor(g),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${groupLabel(l10n, g)} '
                    '${income > 0 ? (totals[g]! * 100 / income).round() : 0}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.controller});

  final PlanSetupController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currency = controller.currency;
    final editing = controller.editMode.value;

    return Column(
      children: [
        for (final group in controller.groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: groupColor(group),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    groupLabel(l10n, group),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  Money.format(controller.totalFor(group), currency),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          for (final item in controller.items.where((i) => i.group == group))
            editing
                ? _EditRow(
                    key: ValueKey(item.uid),
                    item: item,
                    controller: controller,
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: theme.dividerColor, width: 0.5),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            planItemLabel(l10n, item.name),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (item.isFixed)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              l10n.planFixed,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        Text(Money.format(item.amountMinor, currency)),
                      ],
                    ),
                  ),
          if (editing)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton.icon(
                  onPressed: () => _addItem(context, group),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.planAddTo(groupLabel(l10n, group))),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _addItem(BuildContext context, String group) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddItemSheet(controller: controller, group: group),
    );
  }
}

class _EditRow extends StatefulWidget {
  const _EditRow({super.key, required this.item, required this.controller});

  final PlanItemDraft item;
  final PlanSetupController controller;

  @override
  State<_EditRow> createState() => _EditRowState();
}

class _EditRowState extends State<_EditRow> {
  late final TextEditingController _name;
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _amount = TextEditingController(
      text: widget.item.amountMinor == 0
          ? ''
          : Money.toInputText(
              widget.item.amountMinor,
              widget.controller.currency,
            ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currency = widget.controller.currency;
    final linked =
        widget.item.categoryId != null ||
        widget.item.name == 'emergency_fund' ||
        widget.item.name == 'goals' ||
        widget.item.name == 'giving' ||
        widget.item.name == 'debt_payment';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
      child: Row(
        children: [
          Expanded(
            child: linked
                ? Text(planItemLabel(l10n, widget.item.name))
                : TextField(
                    controller: _name,
                    maxLength: 24,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: l10n.planItemName,
                    ),
                    onChanged: (v) =>
                        widget.controller.rename(widget.item.uid, v),
                  ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textAlign: TextAlign.end,
              decoration: InputDecoration(
                isDense: true,
                prefixText: Money.symbolFor(currency),
                hintText: '0',
              ),
              onChanged: (v) => widget.controller.setAmount(
                widget.item.uid,
                Money.parseMinor(v, currency),
              ),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            icon: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => widget.controller.remove(widget.item.uid),
          ),
        ],
      ),
    );
  }
}

class _LeftBox extends StatelessWidget {
  const _LeftBox({required this.controller});

  final PlanSetupController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final income = controller.incomeMinor.value;
    final left = controller.left;
    final currency = controller.currency;

    final String text;
    final Color color;
    if (income <= 0) {
      text = l10n.planIncomeHint;
      color = theme.colorScheme.onSurfaceVariant;
    } else if (left == 0) {
      text = l10n.planEveryDollar;
      color = const Color(0xFF2E7D32);
    } else if (left > 0) {
      text = l10n.planLeftToAssign(Money.format(left, currency));
      color = const Color(0xFFB26A00);
    } else {
      text = l10n.planOverIncome(Money.format(-left, currency));
      color = theme.colorScheme.error;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
}

class _SavingBox extends StatelessWidget {
  const _SavingBox({required this.controller});

  final PlanSetupController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const green = Color(0xFF2E7D32);
    final saving = controller.savings;
    final currency = controller.currency;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.planYouWillSave,
            style: theme.textTheme.bodySmall?.copyWith(color: green),
          ),
          Text(
            l10n.planPerMonth(Money.format(saving, currency)),
            style: theme.textTheme.titleLarge?.copyWith(
              color: green,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            l10n.planIn12Months(Money.format(saving * 12, currency)),
            style: theme.textTheme.bodySmall?.copyWith(color: green),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to add a line to the plan. It owns its text controller.
class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({required this.controller, required this.group});

  final PlanSetupController controller;
  final String group;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _name = TextEditingController();
  String? _categoryId;
  var _showError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit(List<CategoryRow> unused) {
    final typed = _name.text.trim();
    if (_categoryId == null && typed.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final id = _categoryId;
    if (id != null) {
      final cat = unused.firstWhere((c) => c.id == id);
      widget.controller.addItem(
        group: widget.group,
        name: cat.isDefault ? cat.id : cat.name,
        categoryId: cat.id,
      );
    } else {
      widget.controller.addItem(group: widget.group, name: typed);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canLink = widget.group != 'savings' && widget.group != 'giving';
    final unused = widget.controller.unusedCategories;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.planAddTo(groupLabel(l10n, widget.group)),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (canLink && unused.isNotEmpty) ...[
            Text(l10n.planLinkCategory, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in unused)
                  ChoiceChip(
                    label: Text(categoryDisplayName(l10n, c)),
                    selected: _categoryId == c.id,
                    onSelected: (on) => setState(() {
                      _categoryId = on ? c.id : null;
                      _showError = false;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_categoryId == null)
            TextField(
              controller: _name,
              autofocus: !canLink || unused.isEmpty,
              maxLength: 24,
              decoration: InputDecoration(
                labelText: l10n.planItemName,
                helperText: l10n.planNoTracking,
                errorText: _showError ? l10n.planItemNameRequired : null,
                counterText: '',
              ),
              onChanged: (_) {
                if (_showError) setState(() => _showError = false);
              },
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => _submit(unused), child: Text(l10n.add)),
        ],
      ),
    );
  }
}

/// "Your goals need X a month" with a button that fits the plan to them.
class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.controller});

  final PlanSetupController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Obx(() {
      final needed = controller.goalsMonthly.value;
      if (needed <= 0 || controller.incomeMinor.value <= 0) {
        return const SizedBox.shrink();
      }
      final percent = controller.goalsPercent;
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.planGoalsTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                l10n.planGoalsBody(
                  Money.format(needed, controller.currency),
                  percent,
                ),
              ),
              if (percent > 40) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.planGoalsHigh,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: controller.fitToGoals,
                child: Text(l10n.planGoalsFit),
              ),
            ],
          ),
        ),
      );
    });
  }
}
