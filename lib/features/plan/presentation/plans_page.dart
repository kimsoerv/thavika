import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/text_prompt.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/budget_service.dart';
import '../data/plan_repository.dart';
import 'plan_labels.dart';

class PlansController extends GetxController {
  PlansController(this._plans, this._budget);

  final PlanRepository _plans;
  final BudgetService _budget;

  final saved = <PlanRow>[].obs;
  StreamSubscription<List<PlanRow>>? _sub;

  PlanWithItems? get current => _budget.plan.value;

  @override
  void onInit() {
    super.onInit();
    _sub = _plans.watchLibrary().listen(saved.assignAll);
  }

  Future<void> saveCurrent(String name) async {
    final plan = current;
    if (plan == null) return;
    await _plans.saveToLibrary(plan.plan.id, name);
  }

  Future<void> use(PlanRow plan) => _plans.applyFromLibrary(plan.id);

  Future<void> delete(PlanRow plan) => _plans.deleteFromLibrary(plan.id);

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

class PlansBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PlansController(Get.find(), Get.find()));
  }
}

class PlansPage extends GetView<PlansController> {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plansTitle)),
      body: SafeArea(
        child: Obx(() {
          final list = controller.saved.toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (controller.current != null)
                OutlinedButton.icon(
                  onPressed: () => _saveCurrent(context),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(l10n.plansSaveCurrent),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Text(
                    l10n.plansEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final plan in list)
                Card(
                  child: ListTile(
                    title: Text(plan.name ?? l10n.planUnnamed),
                    subtitle: Text(
                      '${templateName(l10n, plan.template)} · '
                      '${l10n.plansIncome(Money.format(plan.incomeMinor, plan.currency))}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, plan),
                    ),
                    onTap: () => _use(context, plan),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          persist: false,
          duration: const Duration(seconds: 3),
          content: Text(message),
        ),
      );
  }

  Future<void> _saveCurrent(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final name = await showTextPrompt(
      context,
      title: l10n.plansSaveCurrent,
      label: l10n.plansNameHint,
      initial: controller.current?.plan.name ?? '',
      maxLength: 30,
    );
    if (name == null || name.trim().isEmpty) return;
    await controller.saveCurrent(name.trim());
    if (context.mounted) _toast(context, l10n.plansSaved);
  }

  Future<void> _use(BuildContext context, PlanRow plan) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.plansUse),
        content: Text(l10n.plansUseBody(plan.name ?? l10n.planUnnamed)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.plansUse),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await controller.use(plan);
    if (context.mounted) _toast(context, l10n.plansSwitched);
  }

  Future<void> _delete(BuildContext context, PlanRow plan) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.plansDeleteTitle),
        content: Text(l10n.plansDeleteBody),
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
    if (ok == true) await controller.delete(plan);
  }
}
