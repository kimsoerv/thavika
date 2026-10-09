import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'wallet_visuals.dart';
import 'wallets_controller.dart';

class WalletsPage extends GetView<WalletsController> {
  const WalletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.walletsTitle),
        actions: [
          IconButton(
            tooltip: l10n.walletNew,
            icon: const Icon(Icons.add),
            onPressed: () => Get.toNamed(Routes.walletForm),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final currency = controller.currency;
          final balances = controller.meta.balances;
          final wallets = controller.all;
          final transfers = controller.transfers;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.walletsTotal,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        Money.format(controller.total, currency),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final w in wallets)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      walletIcon(w.kind),
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(w.name),
                  subtitle: Text(
                    w.isArchived
                        ? l10n.walletArchived
                        : walletKindLabel(l10n, w.kind),
                  ),
                  trailing: Text(
                    Money.format(balances[w.id] ?? 0, w.currency),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Get.toNamed(Routes.walletForm, arguments: w),
                ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  if (wallets.where((w) => !w.isArchived).length < 2) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          persist: false,
                          duration: const Duration(seconds: 4),
                          content: Text(l10n.walletNeedTwo),
                        ),
                      );
                    return;
                  }
                  Get.toNamed(Routes.transferForm);
                },
                icon: const Icon(Icons.swap_horiz),
                label: Text(l10n.walletMoveMoney),
              ),
              const SizedBox(height: 24),
              Text(l10n.transferRecent, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              if (transfers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.transferNone,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final t in transfers)
                  Dismissible(
                    key: ValueKey(t.id),
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
                    onDismissed: (_) {
                      controller.deleteTransfer(t.id);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            persist: false,
                            duration: const Duration(seconds: 5),
                            content: Text(l10n.transferDeleted),
                            action: SnackBarAction(
                              label: l10n.undo,
                              onPressed: () => controller.restoreTransfer(t.id),
                            ),
                          ),
                        );
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const CircleAvatar(
                        child: Icon(Icons.swap_horiz),
                      ),
                      title: Text(
                        l10n.transferLine(
                          controller.walletName(t.fromWalletId),
                          controller.walletName(t.toWalletId),
                        ),
                      ),
                      subtitle: Text(
                        [
                          DateFormat.MMMd().format(t.occurredOn),
                          if (t.note.isNotEmpty) t.note,
                        ].join(' · '),
                      ),
                      trailing: Text(Money.format(t.amountMinor, t.currency)),
                      onTap: () =>
                          Get.toNamed(Routes.transferForm, arguments: t),
                    ),
                  ),
            ],
          );
        }),
      ),
    );
  }
}
