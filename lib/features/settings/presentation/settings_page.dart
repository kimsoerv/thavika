import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/ui/share_file.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../lock/application/lock_service.dart';
import '../../lock/presentation/pin_flow_page.dart';
import '../application/backup_service.dart';
import 'settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          children: [
            Obx(() {
              final locked = controller.hasData.value;
              final code = controller.settings.currency.value;
              return ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(l10n.settingsCurrency),
                subtitle: locked ? Text(l10n.settingsCurrencyLocked) : null,
                trailing: Text(
                  '$code ${Money.symbolFor(code)}',
                  style: theme.textTheme.titleSmall,
                ),
                enabled: !locked,
                onTap: locked ? null : () => _pickCurrency(context),
              );
            }),
            Obx(() {
              final lang = controller.settings.language.value;
              return ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.settingsLanguage),
                trailing: Text(
                  _languageName(l10n, lang),
                  style: theme.textTheme.titleSmall,
                ),
                onTap: () => _pickLanguage(context),
              );
            }),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(l10n.settingsWallets),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.wallets),
            ),
            ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: Text(l10n.debtsTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.debts),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(l10n.netWorthTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.netWorth),
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(l10n.settingsCategories),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.categories),
            ),
            ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: Text(l10n.settingsTags),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.tags),
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(l10n.settingsRecurring),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.recurringList),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.settingsReminders),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.reminders),
            ),
            const _LockTiles(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.settingsData,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(l10n.settingsExportCsv),
              onTap: () => _exportCsv(context),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_outlined),
              title: Text(l10n.settingsExportExcel),
              onTap: () => _exportExcel(context),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: Text(l10n.settingsBackup),
              subtitle: Text(l10n.settingsBackupHint),
              onTap: () => _backup(context),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: Text(l10n.settingsRestore),
              onTap: () => _restore(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.settingsAbout),
              subtitle: Text(l10n.settingsAboutBody),
            ),
          ],
        ),
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
          duration: const Duration(seconds: 4),
          content: Text(message),
        ),
      );
  }

  String _languageName(AppLocalizations l10n, String code) => switch (code) {
    'en' => l10n.languageEnglish,
    'km' => l10n.languageKhmer,
    _ => l10n.languageSystem,
  };

  Future<void> _pickLanguage(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final current = controller.settings.language.value;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsLanguage),
        children: [
          for (final code in const ['system', 'en', 'km'])
            ListTile(
              title: Text(_languageName(l10n, code)),
              trailing: code == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, code),
            ),
        ],
      ),
    );
    if (picked != null) await controller.settings.setLanguage(picked);
  }

  Future<void> _pickCurrency(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final current = controller.settings.currency.value;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.settingsCurrency),
        children: [
          for (final code in SettingsController.currencies)
            ListTile(
              title: Text('$code  ${Money.symbolFor(code)}'),
              trailing: code == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, code),
            ),
        ],
      ),
    );
    if (picked != null) await controller.setCurrency(picked);
  }

  Future<void> _exportCsv(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final path = await controller.exportAllCsv();
    if (!context.mounted) return;
    if (path == null) {
      _toast(context, l10n.nothingToExport);
      return;
    }
    await shareFile(context, path);
  }

  Future<void> _exportExcel(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final path = await controller.exportAllExcel();
    if (!context.mounted) return;
    if (path == null) {
      _toast(context, l10n.nothingToExport);
      return;
    }
    await shareFile(context, path);
  }

  Future<void> _backup(BuildContext context) async {
    final path = await controller.exportBackup();
    if (!context.mounted) return;
    await shareFile(context, path);
  }

  Future<void> _restore(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final picked = await FilePicker.pickFile(type: FileType.any);
    final path = picked?.path;
    if (path == null || !context.mounted) return;

    final String text;
    try {
      text = await File(path).readAsString();
    } on FileSystemException {
      if (context.mounted) _toast(context, l10n.restoreFailed);
      return;
    }
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.restoreAction),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await controller.restore(text);
      if (context.mounted) _toast(context, l10n.restoreDone);
    } on BackupException {
      if (context.mounted) _toast(context, l10n.restoreFailed);
    }
  }
}

class _LockTiles extends StatelessWidget {
  const _LockTiles();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lock = Get.find<LockService>();
    return Obx(() {
      final on = lock.enabled.value;
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.settingsLock),
            trailing: Text(
              on ? l10n.lockStatusOn : l10n.lockStatusOff,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            onTap: () => Get.toNamed(
              Routes.pinFlow,
              arguments: on ? PinFlow.disable : PinFlow.set,
            ),
          ),
          if (on) ...[
            ListTile(
              contentPadding: const EdgeInsets.only(left: 72, right: 16),
              title: Text(l10n.lockChangePin),
              onTap: () =>
                  Get.toNamed(Routes.pinFlow, arguments: PinFlow.change),
            ),
            FutureBuilder<bool>(
              future: lock.biometricsAvailable,
              builder: (context, snap) {
                if (snap.data != true) return const SizedBox.shrink();
                return Obx(
                  () => SwitchListTile(
                    contentPadding: const EdgeInsets.only(left: 72, right: 16),
                    title: Text(l10n.lockUseBiometric),
                    value: lock.biometric.value,
                    onChanged: lock.setBiometric,
                  ),
                );
              },
            ),
          ],
        ],
      );
    });
  }
}
