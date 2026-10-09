import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/ui/amount_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/wallet_repository.dart';
import 'wallet_visuals.dart';

class WalletFormController extends GetxController {
  WalletFormController(this._repo, this._settings);

  final WalletRepository _repo;
  final SettingsService _settings;

  /// Set when an existing wallet is being edited.
  WalletRow? editing;

  final nameCtrl = TextEditingController();
  final openingCtrl = TextEditingController();
  final kind = 'cash'.obs;
  final archived = false.obs;
  final nameError = false.obs;
  final saving = false.obs;

  bool get isEditing => editing != null;
  String get currency => editing?.currency ?? _settings.currency.value;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is WalletRow) {
      editing = args;
      nameCtrl.text = args.name;
      kind.value = args.kind;
      archived.value = args.isArchived;
      openingCtrl.text = args.openingMinor == 0
          ? ''
          : Money.toInputText(args.openingMinor, args.currency);
    }
  }

  Future<bool> save() async {
    if (saving.value) return false;
    final name = nameCtrl.text.trim();
    nameError.value = name.isEmpty;
    if (name.isEmpty) return false;
    final opening = Money.parseMinor(openingCtrl.text, currency);
    saving.value = true;
    try {
      final existing = editing;
      if (existing == null) {
        await _repo.add(
          name: name,
          currency: currency,
          kind: kind.value,
          openingMinor: opening,
        );
      } else {
        await _repo.update(
          existing.id,
          name: name,
          kind: kind.value,
          icon: existing.icon,
          openingMinor: opening,
        );
        if (archived.value != existing.isArchived) {
          await _repo.setArchived(existing.id, archived.value);
        }
      }
      return true;
    } finally {
      saving.value = false;
    }
  }

  /// Other wallets an entry can move to when this one is deleted.
  Future<List<WalletRow>> otherWallets() async {
    final all = await _repo.watchAll(includeArchived: true).first;
    return all.where((w) => w.id != editing?.id).toList();
  }

  Future<void> delete(String moveTo) async {
    final existing = editing;
    if (existing != null) await _repo.delete(existing.id, moveTo: moveTo);
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    openingCtrl.dispose();
    super.onClose();
  }
}

class WalletFormPage extends GetView<WalletFormController> {
  const WalletFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? l10n.walletEdit : l10n.walletNew),
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
                    () => TextField(
                      controller: controller.nameCtrl,
                      autofocus: !controller.isEditing,
                      maxLength: 24,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => controller.nameError.value = false,
                      decoration: InputDecoration(
                        labelText: l10n.walletName,
                        counterText: '',
                        errorText: controller.nameError.value
                            ? l10n.walletNameRequired
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.walletKind,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Wrap(
                      spacing: 8,
                      children: [
                        for (final k in walletKinds)
                          ChoiceChip(
                            avatar: Icon(walletIcon(k), size: 18),
                            label: Text(walletKindLabel(l10n, k)),
                            selected: controller.kind.value == k,
                            onSelected: (_) => controller.kind.value = k,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AmountField(
                    controller: controller.openingCtrl,
                    currency: controller.currency,
                    label: l10n.walletStarting,
                  ),
                  if (controller.isEditing)
                    Obx(
                      () => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.walletArchive),
                        value: controller.archived.value,
                        onChanged: (v) => controller.archived.value = v,
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

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final others = await controller.otherWallets();
    if (!context.mounted) return;
    if (others.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            persist: false,
            duration: const Duration(seconds: 4),
            content: Text(l10n.walletOnlyOne),
          ),
        );
      return;
    }
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.walletDeleteTitle),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(l10n.walletDeleteBody),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(
              l10n.walletMoveTo,
              style: Theme.of(ctx).textTheme.labelLarge,
            ),
          ),
          for (final w in others)
            ListTile(
              leading: Icon(walletIcon(w.kind)),
              title: Text(w.name),
              onTap: () => Navigator.pop(ctx, w.id),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
            ),
          ),
        ],
      ),
    );
    if (target != null) {
      await controller.delete(target);
      Get.back<void>();
    }
  }
}
