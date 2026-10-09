import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/ui/date_labels.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/transaction_repository.dart';
import 'transactions_controller.dart';
import 'tx_tile.dart';

class TransactionsPage extends GetView<TransactionsController> {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Obx(
              () => Row(
                children: [
                  IconButton(
                    tooltip: l10n.previousMonth,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => controller.shiftMonth(-1),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMM().format(controller.month.value),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.nextMonth,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => controller.shiftMonth(1),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => controller.query.value = v,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Obx(
              () => Row(
                children: [
                  for (final entry in {
                    'all': l10n.all,
                    'expense': l10n.expense,
                    'income': l10n.income,
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: controller.typeFilter.value == entry.key,
                        onSelected: (_) =>
                            controller.typeFilter.value = entry.key,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Obx(() {
            final meta = controller.meta;
            final wallet = meta.walletById(controller.walletFilter.value);
            final tag = controller.tagFilter.value == null
                ? null
                : meta.tagById(controller.tagFilter.value!);
            if (meta.wallets.length < 2 && meta.tags.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  if (meta.wallets.length > 1)
                    InputChip(
                      avatar: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                      ),
                      label: Text(wallet?.name ?? l10n.filterAnyWallet),
                      selected: wallet != null,
                      onPressed: () => _pickFilter(
                        context,
                        title: l10n.filterWallet,
                        options: {for (final w in meta.wallets) w.id: w.name},
                        current: controller.walletFilter.value,
                        onPicked: (id) => controller.walletFilter.value = id,
                        anyLabel: l10n.filterAnyWallet,
                      ),
                      onDeleted: wallet == null
                          ? null
                          : () => controller.walletFilter.value = null,
                    ),
                  if (meta.tags.isNotEmpty)
                    InputChip(
                      avatar: const Icon(Icons.sell_outlined, size: 18),
                      label: Text(
                        tag == null ? l10n.filterAnyTag : '#${tag.name}',
                      ),
                      selected: tag != null,
                      onPressed: () => _pickFilter(
                        context,
                        title: l10n.filterTag,
                        options: {
                          for (final t in meta.tags) t.id: '#${t.name}',
                        },
                        current: controller.tagFilter.value,
                        onPicked: (id) => controller.tagFilter.value = id,
                        anyLabel: l10n.filterAnyTag,
                      ),
                      onDeleted: tag == null
                          ? null
                          : () => controller.tagFilter.value = null,
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Expanded(
            child: Obx(() {
              final list = controller.filtered;
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    controller.items.isEmpty
                        ? l10n.noEntriesBody
                        : l10n.noMatches,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final rows = <Object>[];
              DateTime? lastDay;
              for (final e in list) {
                final day = dateOnly(e.tx.occurredOn);
                if (lastDay != day) {
                  rows.add(day);
                  lastDay = day;
                }
                rows.add(e);
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                itemCount: rows.length + 1,
                itemBuilder: (context, i) {
                  if (i == rows.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.swipeHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final row = rows[i];
                  if (row is DateTime) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                      child: Text(
                        dayLabel(l10n, row),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final item = row as TxWithCategory;
                  return Dismissible(
                    key: ValueKey(item.tx.id),
                    // Swipe right to copy to today, left to delete.
                    background: Container(
                      color: theme.colorScheme.primaryContainer,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      child: Icon(
                        Icons.copy_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    secondaryBackground: Container(
                      color: theme.colorScheme.errorContainer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction != DismissDirection.startToEnd) return true;
                      final copyId = await controller.duplicate(item.tx.id);
                      if (!context.mounted) return false;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            persist: false,
                            duration: const Duration(seconds: 5),
                            content: Text(l10n.entryDuplicated),
                            action: SnackBarAction(
                              label: l10n.undo,
                              onPressed: () => controller.delete(copyId),
                            ),
                          ),
                        );
                      // The tile stays; the copy appears as a new entry.
                      return false;
                    },
                    onDismissed: (_) {
                      controller.delete(item.tx.id);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            persist: false,
                            duration: const Duration(seconds: 5),
                            content: Text(l10n.entryDeleted),
                            action: SnackBarAction(
                              label: l10n.undo,
                              onPressed: () => controller.restore(item.tx.id),
                            ),
                          ),
                        );
                    },
                    child: TxTile(
                      item: item,
                      extra: controller.extraFor(item),
                      onTap: () => Get.toNamed(Routes.entry, arguments: item),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFilter(
    BuildContext context, {
    required String title,
    required Map<String, String> options,
    required String? current,
    required void Function(String? id) onPicked,
    required String anyLabel,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              title: Text(anyLabel),
              selected: current == null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final e in options.entries)
              ListTile(
                title: Text(e.value),
                selected: current == e.key,
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onPicked(picked.isEmpty ? null : picked);
  }
}
