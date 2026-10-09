import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/ui/amount_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'setup_controller.dart';

class SetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SetupController>(
      () =>
          SetupController(Get.find<SettingsService>(), Get.find(), Get.find()),
    );
  }
}

class SetupPage extends GetView<SetupController> {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Obx(
              () => Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            (controller.step.value + 1) /
                            SetupController.stepCount,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.setupStepOf(
                        controller.step.value + 1,
                        SetupController.stepCount,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                final child = switch (controller.step.value) {
                  0 => const _LanguageStep(),
                  1 => const _CurrencyStep(),
                  2 => const _WalletStep(),
                  _ => const _IncomeStep(),
                };
                return SingleChildScrollView(
                  key: ValueKey(controller.step.value),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: child,
                );
              }),
            ),
            const _Buttons(),
          ],
        ),
      ),
    );
  }
}

class _Buttons extends GetView<SetupController> {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Obx(() {
      final last = controller.isLast;
      final canPlan = controller.incomeMinor.value > 0;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: controller.saving.value
                    ? null
                    : last
                    ? (canPlan ? () => controller.finish(withPlan: true) : null)
                    : controller.next,
                child: Text(last ? l10n.setupFinish : l10n.setupNext),
              ),
            ),
            if (last)
              TextButton(
                onPressed: controller.saving.value
                    ? null
                    : () => controller.finish(withPlan: false),
                child: Text(l10n.setupSkipPlan),
              )
            else if (controller.step.value > 0)
              TextButton(
                onPressed: controller.back,
                child: Text(l10n.setupBack),
              )
            else
              const SizedBox(height: 48),
          ],
        ),
      );
    });
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.body);

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _LanguageStep extends GetView<SetupController> {
  const _LanguageStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(l10n.setupWelcomeTitle, l10n.setupWelcomeBody),
        Obx(() {
          final current = controller.settings.locale.languageCode;
          return Column(
            children: [
              for (final code in SettingsService.languages)
                Card(
                  child: ListTile(
                    title: Text(code == 'km' ? 'ខ្មែរ' : 'English'),
                    trailing: current == code
                        ? const Icon(Icons.check_circle)
                        : const Icon(Icons.circle_outlined),
                    onTap: () => controller.setLanguage(code),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _CurrencyStep extends GetView<SetupController> {
  const _CurrencyStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(l10n.setupCurrencyTitle, l10n.setupCurrencyBody),
        Obx(() {
          final current = controller.currency;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in _ordered())
                ChoiceChip(
                  label: Text('$code  ${Money.symbolFor(code)}'),
                  selected: code == current,
                  onSelected: (_) => controller.setCurrency(code),
                ),
            ],
          );
        }),
      ],
    );
  }

  /// USD and KHR first, then the rest.
  List<String> _ordered() {
    final all = Money.supportedCurrencies;
    return [
      for (final c in ['USD', 'KHR'])
        if (all.contains(c)) c,
      for (final c in all)
        if (c != 'USD' && c != 'KHR') c,
    ];
  }
}

class _WalletStep extends GetView<SetupController> {
  const _WalletStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(l10n.setupWalletTitle, l10n.setupWalletBody),
        Obx(
          () => AmountField(
            controller: controller.openingCtrl,
            currency: controller.currency,
            style: theme.textTheme.titleLarge,
            onChanged: controller.onOpeningChanged,
          ),
        ),
      ],
    );
  }
}

class _IncomeStep extends GetView<SetupController> {
  const _IncomeStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(l10n.setupIncomeTitle, l10n.setupCostsHint),
        Obx(
          () => AmountField(
            controller: controller.incomeCtrl,
            currency: controller.currency,
            label: l10n.planIncomeLabel,
            style: theme.textTheme.titleMedium,
            onChanged: controller.onIncomeChanged,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => AmountField(
            controller: controller.rentCtrl,
            currency: controller.currency,
            label: l10n.setupRentLabel,
            style: theme.textTheme.titleMedium,
            onChanged: controller.onRentChanged,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => AmountField(
            controller: controller.foodCtrl,
            currency: controller.currency,
            label: l10n.setupFoodLabel,
            style: theme.textTheme.titleMedium,
            onChanged: controller.onFoodChanged,
          ),
        ),
        const _Advice(),
      ],
    );
  }
}

class _Advice extends GetView<SetupController> {
  const _Advice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Obx(() {
      if (controller.incomeMinor.value <= 0) return const SizedBox.shrink();
      final suggested = controller.suggested;
      final chosen = controller.chosen;
      final haveCosts =
          controller.rentMinor.value + controller.foodMinor.value > 0;

      String name(String id) => switch (id) {
        'balanced' => l10n.tplBalanced,
        'seventy' => l10n.tplSeventy,
        _ => l10n.tplCustom,
      };

      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.setupAdviceTitle, style: theme.textTheme.titleMedium),
            if (haveCosts) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.setupShareLine(controller.needsPercent)} '
                '${switch (suggested) {
                  'balanced' => l10n.setupAdviceBalanced,
                  'seventy' => l10n.setupAdviceSeventy,
                  _ => l10n.setupAdviceCustom,
                }}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            for (final id in const ['balanced', 'seventy', 'custom'])
              Card(
                child: ListTile(
                  title: Text(name(id)),
                  subtitle: id == suggested && haveCosts
                      ? Text(l10n.setupRecommended)
                      : null,
                  trailing: chosen == id
                      ? const Icon(Icons.check_circle)
                      : const Icon(Icons.circle_outlined),
                  onTap: () => controller.pick(id),
                ),
              ),
          ],
        ),
      );
    });
  }
}
