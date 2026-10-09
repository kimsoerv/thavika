import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../sync/application/sync_service.dart';
import '../../sync/data/sync_engine.dart';
import '../application/auth_service.dart';

/// Sign in, see how the sync is doing, sign out, delete the account.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = Get.find<AuthService>();
    final sync = Get.find<SyncService>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: SafeArea(
        child: Obx(() {
          if (!auth.isConfigured) {
            return _Message(text: l10n.accountNotConfigured);
          }
          final user = auth.user.value;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (user == null)
                ..._guest(context, l10n, theme, auth, sync)
              else
                ..._signedIn(context, l10n, theme, auth, sync),
            ],
          );
        }),
      ),
    );
  }

  List<Widget> _guest(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    AuthService auth,
    SyncService sync,
  ) {
    return [
      Icon(
        Icons.cloud_off_outlined,
        size: 48,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(height: 12),
      Text(l10n.accountGuest, style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        l10n.accountGuestBody,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        icon: const Icon(Icons.login),
        label: Text(l10n.accountSignInGoogle),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: () => _signIn(context, l10n, auth, sync),
      ),
      Obx(() {
        final e = auth.error.value;
        if (e == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            l10n.accountSignInFailed(e),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        );
      }),
    ];
  }

  List<Widget> _signedIn(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    AuthService auth,
    SyncService sync,
  ) {
    final pending = sync.pending.value;
    final last = sync.lastSyncedAt.value;
    final String status;
    final IconData icon;
    switch (sync.state.value) {
      case SyncState.syncing:
        status = l10n.syncStatusSyncing;
        icon = Icons.sync;
      case SyncState.offline:
        status = l10n.syncStatusOffline;
        icon = Icons.cloud_off_outlined;
      case SyncState.error:
        status = l10n.syncStatusError(sync.lastError.value ?? '');
        icon = Icons.sync_problem_outlined;
      default:
        status = pending > 0
            ? l10n.syncStatusPending(pending)
            : l10n.syncStatusSynced;
        icon = pending > 0
            ? Icons.cloud_upload_outlined
            : Icons.cloud_done_outlined;
    }
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.person,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(l10n.accountSignedInAs(auth.email ?? '')),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(status)),
                ],
              ),
              if (last != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.syncLast(DateFormat.jm().format(last)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.sync),
                label: Text(l10n.syncNow),
                onPressed: sync.state.value == SyncState.syncing
                    ? null
                    : sync.syncNow,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => _signOut(context, l10n, sync),
        child: Text(l10n.accountSignOut),
      ),
      const SizedBox(height: 8),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
        onPressed: () => _delete(context, l10n, sync),
        child: Text(l10n.accountDelete),
      ),
    ];
  }

  Future<void> _signIn(
    BuildContext context,
    AppLocalizations l10n,
    AuthService auth,
    SyncService sync,
  ) async {
    if (!await auth.signInWithGoogle()) return;
    final check = await sync.checkAccount();

    if (check == AccountCheck.otherAccountData) {
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.accountOtherDataTitle),
          content: Text(l10n.accountOtherDataBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.accountOtherDataContinue),
            ),
          ],
        ),
      );
      if (ok != true) {
        await sync.signOut();
        return;
      }
    } else if (check == AccountCheck.adoptGuestData && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            persist: false,
            duration: const Duration(seconds: 4),
            content: Text(l10n.accountAdoptNote),
          ),
        );
    }
    await sync.start();
  }

  Future<void> _signOut(
    BuildContext context,
    AppLocalizations l10n,
    SyncService sync,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accountSignOut),
        content: Text(l10n.accountSignOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.accountSignOut),
          ),
        ],
      ),
    );
    if (ok == true) await sync.signOut();
  }

  Future<void> _delete(
    BuildContext context,
    AppLocalizations l10n,
    SyncService sync,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accountDelete),
        content: Text(l10n.accountDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await sync.deleteAccount();
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
