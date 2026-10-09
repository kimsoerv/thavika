import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../application/reminder_service.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = Get.find<ReminderService>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsReminders)),
      body: SafeArea(
        child: Obx(
          () => ListView(
            children: [
              if (r.permissionDenied.value)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    l10n.remindersDenied,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              SwitchListTile(
                title: Text(l10n.remindersDaily),
                subtitle: Text(l10n.remindersDailyHint),
                value: r.enabled.value,
                onChanged: r.setEnabled,
              ),
              if (r.enabled.value)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  title: Text(l10n.remindersTime),
                  trailing: Text(
                    r.time.value.format(context),
                    style: theme.textTheme.titleSmall,
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: r.time.value,
                    );
                    if (picked != null) await r.setTime(picked);
                  },
                ),
              SwitchListTile(
                title: Text(l10n.remindersSavings),
                subtitle: Text(l10n.remindersSavingsHint),
                value: r.savings.value,
                onChanged: r.setSavings,
              ),
              SwitchListTile(
                title: Text(l10n.remindersMonthEnd),
                subtitle: Text(l10n.remindersMonthEndHint),
                value: r.monthEnd.value,
                onChanged: r.setMonthEnd,
              ),
              SwitchListTile(
                title: Text(l10n.remindersBills),
                subtitle: Text(l10n.remindersBillsHint),
                value: r.bills.value,
                onChanged: r.setBills,
              ),
              SwitchListTile(
                title: Text(l10n.remindersWarnings),
                subtitle: Text(l10n.remindersWarningsHint),
                value: r.warnings.value,
                onChanged: r.setWarnings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
