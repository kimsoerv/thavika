import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/amount_field.dart';
import '../../../core/ui/category_sheet.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../core/ui/date_labels.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../plan/application/pay_yourself_first.dart';
import '../../plan/presentation/pay_yourself_dialog.dart';
import '../../receipts/receipt_service.dart';
import '../domain/quick_line.dart';
import 'entry_controller.dart';

class EntryPage extends GetView<EntryController> {
  const EntryPage({super.key});

  List<CategoryHint> _hints(AppLocalizations l10n) => [
    for (final c in controller.allCategories)
      CategoryHint(
        id: c.id,
        name: categoryDisplayName(l10n, c),
        isIncome: c.kind == 'income',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        centerTitle: true,
        // Expense / income lives in the bar, so the form starts at the amount.
        title: SizedBox(
          width: 220,
          child: Obx(
            () => SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'expense', label: Text(l10n.expense)),
                ButtonSegment(value: 'income', label: Text(l10n.income)),
              ],
              selected: {controller.type.value},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onSelectionChanged: (s) => controller.setType(s.first),
            ),
          ),
        ),
        actions: [
          if (!controller.isEditing)
            Obx(
              () => IconButton(
                tooltip: l10n.entryQuickApply,
                isSelected: controller.showQuick.value,
                icon: const Icon(Icons.bolt_outlined),
                selectedIcon: const Icon(Icons.bolt),
                onPressed: () =>
                    controller.showQuick.value = !controller.showQuick.value,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!controller.isEditing)
                      Obx(
                        () => controller.showQuick.value
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _QuickPanel(
                                  controller: controller,
                                  hints: () => _hints(l10n),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final text = controller.amountText.value;
                      return Text(
                        '${Money.symbolFor(controller.currency)}${text.isEmpty ? '0' : text}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: text.isEmpty
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      );
                    }),
                    Obx(() {
                      final message = switch (controller.error.value) {
                        EntryError.amountRequired => l10n.amountRequired,
                        EntryError.categoryRequired => l10n.categoryRequired,
                        EntryError.splitNeedAmount => l10n.entrySplitNeedAmount,
                        EntryError.splitIncomplete => l10n.entrySplitIncomplete,
                        EntryError.splitMismatch => l10n.entrySplitMismatch,
                        null => '',
                      };
                      return SizedBox(
                        height: 20,
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      );
                    }),
                    Obx(
                      () => controller.splitMode.value
                          ? _SplitEditor(controller: controller)
                          : _CategoryGrid(
                              controller: controller,
                              onMore: () => _addCategory(context),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Date, note and Details stay pinned above the keypad, so they are
            // always visible and tappable, whatever the phone's height.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Obx(
                        () => ActionChip(
                          avatar: const Icon(Icons.calendar_today, size: 18),
                          label: Text(dayLabel(l10n, controller.date.value)),
                          onPressed: () => _pickDate(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller.noteCtrl,
                          textInputAction: TextInputAction.done,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: l10n.noteHint,
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _OptionsRow(controller: controller),
                    ],
                  ),
                  Obx(() {
                    final list = controller.suggestions;
                    if (list.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final s in list)
                            ActionChip(
                              label: Text(s.note),
                              onPressed: () => controller.useSuggestion(s),
                            ),
                        ],
                      ),
                    );
                  }),
                  _ReceiptPreview(controller: controller),
                ],
              ),
            ),
            _Keypad(controller: controller),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Obx(
                () => FilledButton(
                  onPressed: controller.saving.value
                      ? null
                      : () async {
                          final isNewIncome =
                              controller.type.value == 'income' &&
                              !controller.isEditing;
                          final amount = controller.total;
                          final id = await controller.save();
                          if (id == null) return;
                          if (isNewIncome && context.mounted) {
                            await offerPayYourselfFirst(
                              context,
                              service: Get.find<PayYourselfFirst>(),
                              incomeMinor: amount,
                              currency: controller.currency,
                            );
                          }
                          Get.back<String>(result: id);
                        },
                  child: Text(
                    controller.isEditing
                        ? l10n.save
                        : controller.type.value == 'income'
                        ? l10n.saveIncome
                        : l10n.saveExpense,
                  ),
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
    if (picked != null) controller.setDate(picked);
  }

  Future<void> _addCategory(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CategoryEditSheet.show(
      context,
      title: l10n.addCategory,
      submitLabel: l10n.add,
      onSubmit: (name, icon) => controller.addCategory(name, icon),
    );
  }
}

/// One button next to the note. It opens wallet, tags, receipt and split,
/// which most entries do not need. A dot shows when any of them is set.
class _OptionsRow extends StatelessWidget {
  const _OptionsRow({required this.controller});

  final EntryController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Obx(() {
      final hasExtras =
          controller.tagIds.isNotEmpty ||
          controller.receipt.value != null ||
          controller.splitMode.value;
      return Badge(
        smallSize: 10,
        isLabelVisible: hasExtras,
        child: IconButton.outlined(
          tooltip: l10n.entryDetails,
          icon: const Icon(Icons.tune),
          onPressed: () => _openSheet(context),
        ),
      );
    });
  }

  Future<void> _openSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Obx(() {
          final meta = controller.meta;
          final wallet = meta.walletById(controller.walletId.value);
          final tagNames = [
            for (final id in controller.tagIds)
              if (meta.tagById(id) != null) '#${meta.tagById(id)!.name}',
          ];
          Widget trailing(String text) => SizedBox(
            width: 140,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (meta.wallets.length > 1)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(l10n.entryWallet),
                  trailing: trailing(wallet?.name ?? ''),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickWallet(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: Text(l10n.entryTags),
                trailing: trailing(tagNames.join(' ')),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickTags(context);
                },
              ),
              ListTile(
                leading: Icon(
                  controller.receipt.value == null
                      ? Icons.photo_camera_outlined
                      : Icons.check_circle_outline,
                ),
                title: Text(l10n.entryReceipt),
                onTap: () {
                  Navigator.pop(ctx);
                  _receiptMenu(context);
                },
              ),
              if (!controller.isEditing)
                ListTile(
                  leading: const Icon(Icons.call_split),
                  title: Text(l10n.entrySplit),
                  selected: controller.splitMode.value,
                  trailing: controller.splitMode.value
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.toggleSplit();
                  },
                ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _pickWallet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final meta = controller.meta;
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.entryChooseWallet,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ),
            for (final w in meta.wallets)
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(w.name),
                trailing: Text(
                  Money.format(meta.balances[w.id] ?? 0, w.currency),
                ),
                selected: w.id == controller.walletId.value,
                onTap: () => Navigator.pop(ctx, w.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) controller.setWallet(id);
  }

  Future<void> _pickTags(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TagsSheet(controller: controller),
    );
  }

  Future<void> _receiptMenu(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.entryReceiptTake),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.entryReceiptChoose),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (controller.receipt.value != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.entryReceiptRemove),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'camera':
        await controller.pickReceipt(ImageSource.camera);
      case 'gallery':
        await controller.pickReceipt(ImageSource.gallery);
      case 'remove':
        controller.removeReceipt();
    }
  }
}

/// Bottom sheet with every tag; it owns its text field.
class _TagsSheet extends StatefulWidget {
  const _TagsSheet({required this.controller});

  final EntryController controller;

  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await widget.controller.createTag(name);
    _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = widget.controller;

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
          Text(l10n.entryTags, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Obx(() {
            final tags = c.meta.tags;
            if (tags.isEmpty) {
              return Text(
                l10n.entryTagsNone,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in tags)
                  FilterChip(
                    label: Text('#${t.name}'),
                    selected: c.tagIds.contains(t.id),
                    onSelected: (_) => c.toggleTag(t.id),
                  ),
              ],
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _create(),
            decoration: InputDecoration(
              labelText: l10n.entryNewTag,
              counterText: '',
              suffixIcon: IconButton(
                tooltip: l10n.entryAddTag,
                icon: const Icon(Icons.add),
                onPressed: _create,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.planDone),
          ),
        ],
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({required this.controller});

  final EntryController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final name = controller.receipt.value;
      if (name == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ReceiptThumbnail(name: name, size: 72),
        ),
      );
    });
  }
}

/// A small picture of a receipt; tapping it opens it full size.
class ReceiptThumbnail extends StatelessWidget {
  const ReceiptThumbnail({super.key, required this.name, this.size = 56});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: Get.find<ReceiptService>().fileFor(name),
      builder: (context, snap) {
        final file = snap.data;
        if (file == null) {
          return SizedBox(
            width: size,
            height: size,
            child: const Icon(Icons.broken_image_outlined),
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.all(12),
              child: InteractiveViewer(child: Image.file(file)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.controller, required this.onMore});

  final EntryController controller;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Obx(
      () => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final c in controller.categories)
            _CategoryTile(
              label: categoryDisplayName(l10n, c),
              icon: iconFor(c.icon),
              color: colorForCategory(c.id),
              selected: controller.categoryId.value == c.id,
              onTap: () => controller.selectCategory(c.id),
            ),
          _CategoryTile(
            label: l10n.more,
            icon: Icons.add,
            color: theme.colorScheme.onSurfaceVariant,
            selected: false,
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

class _SplitEditor extends StatelessWidget {
  const _SplitEditor({required this.controller});

  final EntryController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currency = controller.currency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.entrySplitTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: controller.toggleSplit,
              child: Text(l10n.cancel),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Obx(
          () => Column(
            children: [
              for (final part in controller.splits.toList())
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Obx(() {
                          final id = part.categoryId.value;
                          final cat = controller.allCategories.firstWhereOrNull(
                            (c) => c.id == id,
                          );
                          return OutlinedButton.icon(
                            onPressed: () => _pickCategory(context, part),
                            icon: Icon(
                              iconFor(cat?.icon ?? ''),
                              size: 18,
                              color: id == null ? null : colorForCategory(id),
                            ),
                            label: Text(
                              cat == null
                                  ? l10n.entrySplitPickCategory
                                  : categoryDisplayName(l10n, cat),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: AmountField(
                          controller: part.amountCtrl,
                          currency: currency,
                          onChanged: (t) => controller.setPartAmount(part, t),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.delete,
                        icon: const Icon(Icons.close),
                        onPressed: controller.splits.length > 2
                            ? () => controller.removePart(part)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: controller.addPart,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.entrySplitAddPart),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Obx(() {
                final left = controller.total - controller.splitAssigned;
                final String text;
                final Color color;
                if (controller.total <= 0) {
                  text = l10n.entrySplitNeedAmount;
                  color = theme.colorScheme.onSurfaceVariant;
                } else if (left == 0) {
                  text = l10n.entrySplitDone;
                  color = const Color(0xFF2E7D32);
                } else if (left > 0) {
                  text = l10n.entrySplitLeft(Money.format(left, currency));
                  color = const Color(0xFFB26A00);
                } else {
                  text = l10n.entrySplitOver(Money.format(-left, currency));
                  color = theme.colorScheme.error;
                }
                return Text(
                  text,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: color),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickCategory(BuildContext context, SplitPart part) async {
    final l10n = AppLocalizations.of(context);
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final c in controller.categories)
                _CategoryTile(
                  label: categoryDisplayName(l10n, c),
                  icon: iconFor(c.icon),
                  color: colorForCategory(c.id),
                  selected: part.categoryId.value == c.id,
                  onTap: () => Navigator.pop(ctx, c.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (id != null) {
      part.categoryId.value = id;
      if (controller.error.value == EntryError.splitIncomplete) {
        controller.error.value = null;
      }
    }
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.28 : 0.12),
                shape: BoxShape.circle,
                border: selected ? Border.all(color: color, width: 2) : null,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.controller});

  final EntryController controller;

  static const _keys = [
    '1', '2', '3', //
    '4', '5', '6',
    '7', '8', '9',
    '.', '0', 'back',
  ];

  @override
  Widget build(BuildContext context) {
    final decimals = Money.decimalsFor(controller.currency);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var row = 0; row < 4; row++)
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (final key in _keys.sublist(row * 3, row * 3 + 3))
                    Expanded(
                      child: key == '.' && decimals == 0
                          ? const SizedBox.shrink()
                          : TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size.fromHeight(44),
                              ),
                              onPressed: () => controller.press(key),
                              onLongPress: key == 'back'
                                  ? () => controller.press('clear')
                                  : null,
                              child: key == 'back'
                                  ? const Icon(Icons.backspace_outlined)
                                  : Text(
                                      key,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The typed line ("coffee 2.5") and the last few entries to repeat.
class _QuickPanel extends StatelessWidget {
  const _QuickPanel({required this.controller, required this.hints});

  final EntryController controller;
  final List<CategoryHint> Function() hints;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller.quickCtrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.applyQuickLine(hints()),
          decoration: InputDecoration(
            hintText: l10n.entryQuickHint,
            isDense: true,
            prefixIcon: const Icon(Icons.bolt),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => IconButton(
                    tooltip: controller.listening.value
                        ? l10n.entryVoiceStop
                        : l10n.entryVoiceStart,
                    isSelected: controller.listening.value,
                    icon: const Icon(Icons.mic_none),
                    selectedIcon: Icon(
                      Icons.mic,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () => controller.toggleVoice(hints()),
                  ),
                ),
                IconButton(
                  tooltip: l10n.entryQuickApply,
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => controller.applyQuickLine(hints()),
                ),
              ],
            ),
          ),
        ),
        Obx(
          () => controller.voiceUnavailable.value
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    l10n.entryVoiceUnavailable,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Obx(() {
          final list = controller.recents;
          if (list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.entryRepeat,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final r in list)
                  ActionChip(
                    avatar: const Icon(Icons.replay, size: 16),
                    label: Text(
                      '${r.note.isEmpty ? categoryNameFor(l10n, r.categoryId, '') : r.note} '
                      '${Money.format(r.amountMinor, r.currency)}',
                    ),
                    onPressed: () {
                      controller.useRecent(r);
                      controller.showQuick.value = false;
                    },
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
