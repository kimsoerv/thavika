import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../goals/data/goal_repository.dart';
import '../../wallets/data/wallet_repository.dart';
import '../data/debt_repository.dart';
import '../domain/debt_math.dart';

class NetWorthController extends GetxController {
  NetWorthController(this._wallets, this._debts, this._goals, this.settings);

  final WalletRepository _wallets;
  final DebtRepository _debts;
  final GoalRepository _goals;
  final SettingsService settings;

  final inWallets = 0.obs;
  final inGoals = 0.obs;
  final owedToMe = 0.obs;
  final iOwe = 0.obs;
  final _subs = <StreamSubscription<dynamic>>[];

  NetWorth get value => NetWorth(
    inWallets: inWallets.value,
    inGoals: inGoals.value,
    owedToMe: owedToMe.value,
    iOwe: iOwe.value,
  );

  @override
  void onInit() {
    super.onInit();
    _subs.add(
      _wallets.watchBalances().listen(
        (b) => inWallets.value = b.values.fold(0, (s, v) => s + v),
      ),
    );
    _subs.add(_goals.watchMovedOutOfWallets().listen((v) => inGoals.value = v));
    _subs.add(
      _debts.watchAll().listen((list) {
        final t = debtTotals(
          list.map(
            (d) => DebtLine(
              direction: d.debt.direction,
              amountMinor: d.debt.amountMinor,
              paidMinor: d.paidMinor,
            ),
          ),
        );
        owedToMe.value = t.owedToMe;
        iOwe.value = t.iOwe;
      }),
    );
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }
}

class NetWorthPage extends GetView<NetWorthController> {
  const NetWorthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.netWorthTitle)),
      body: SafeArea(
        child: Obx(() {
          final c = controller.settings.currency.value;
          final n = controller.value;
          Widget row(
            String label,
            int amount, {
            Color? color,
            VoidCallback? onTap,
          }) => ListTile(
            title: Text(label),
            trailing: Text(
              Money.format(amount, c),
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
            onTap: onTap,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.netWorthTitle,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Money.format(n.total, c),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              row(
                l10n.netWorthWallets,
                n.inWallets,
                onTap: () => Get.toNamed(Routes.wallets),
              ),
              row(l10n.netWorthGoals, n.inGoals),
              row(
                l10n.debtOwedToMe,
                n.owedToMe,
                color: theme.colorScheme.primary,
                onTap: () => Get.toNamed(Routes.debts),
              ),
              row(
                l10n.debtIOwe,
                -n.iOwe,
                color: theme.colorScheme.error,
                onTap: () => Get.toNamed(Routes.debts),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.netWorthHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
