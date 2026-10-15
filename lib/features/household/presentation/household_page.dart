import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/ui/text_prompt.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_service.dart';
import '../application/household_service.dart';
import '../domain/household.dart';

/// Start, join, manage or leave a household.
class HouseholdPage extends StatelessWidget {
  const HouseholdPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = Get.find<AuthService>();
    final service = Get.find<HouseholdService>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.householdTitle)),
      body: SafeArea(
        child: Obx(() {
          // Read the observables first: an Obx that reads none throws.
          final user = auth.user.value;
          final household = service.info.value;
          final busy = service.busy.value;

          if (user == null) {
            return _SignInFirst(text: l10n.householdNeedSignIn);
          }
          return Column(
            children: [
              if (busy) const LinearProgressIndicator(),
              Expanded(
                child: household == null
                    ? _NoHousehold(service: service, busy: busy)
                    : _InHousehold(
                        service: service,
                        household: household,
                        me: user.id,
                        busy: busy,
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _SignInFirst extends StatelessWidget {
  const _SignInFirst({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Get.toNamed(Routes.account),
              child: Text(l10n.accountTitle),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- helpers ----

/// Runs an action and explains a failure in a snack bar.
Future<bool> _run(BuildContext context, Future<void> Function() action) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on HouseholdException catch (e) {
    final text = switch (e.problem) {
      HouseholdProblem.badCode => l10n.householdErrorCode,
      HouseholdProblem.alreadyMember => l10n.householdErrorAlready,
      HouseholdProblem.notOwner => l10n.householdErrorOwner,
      HouseholdProblem.offline => l10n.householdErrorOffline,
      HouseholdProblem.other => l10n.householdErrorOther,
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    return false;
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ---- not in a household ----

class _NoHousehold extends StatelessWidget {
  const _NoHousehold({required this.service, required this.busy});

  final HouseholdService service;
  final bool busy;

  Future<void> _start(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final name = await showTextPrompt(
      context,
      title: l10n.householdStartTitle,
      label: l10n.householdNameHint,
      maxLength: 40,
    );
    if (name == null || !context.mounted) return;
    final ok = await _confirm(
      context,
      title: l10n.householdStartTitle,
      body: l10n.householdStartConfirmBody,
      action: l10n.householdStart,
    );
    if (!ok || !context.mounted) return;
    await _run(context, () => service.create(name));
  }

  Future<void> _join(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final code = await showTextPrompt(
      context,
      title: l10n.householdJoinTitle,
      label: l10n.householdCodeHint,
      maxLength: 12,
    );
    if (code == null || !context.mounted) return;
    final ok = await _confirm(
      context,
      title: l10n.householdJoinConfirmTitle,
      body: l10n.householdJoinConfirmBody,
      action: l10n.householdJoin,
    );
    if (!ok || !context.mounted) return;
    await _run(context, () => service.join(code));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(Icons.groups_outlined, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          l10n.householdIntro,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.add),
          label: Text(l10n.householdStartTitle),
          onPressed: busy ? null : () => _start(context),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.vpn_key_outlined),
          label: Text(l10n.householdJoinTitle),
          onPressed: busy ? null : () => _join(context),
        ),
      ],
    );
  }
}

// ---- in a household ----

class _InHousehold extends StatelessWidget {
  const _InHousehold({
    required this.service,
    required this.household,
    required this.me,
    required this.busy,
  });

  final HouseholdService service;
  final HouseholdInfo household;
  final String me;
  final bool busy;

  bool get _isOwner => household.isOwner(me);

  Future<void> _rename(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final name = await showTextPrompt(
      context,
      title: l10n.householdRename,
      label: l10n.householdNameHint,
      initial: household.name,
      maxLength: 40,
    );
    if (name == null || !context.mounted) return;
    await _run(context, () => service.rename(name));
  }

  Future<void> _invite(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    String? code;
    final ok = await _run(context, () async {
      code = await service.invite();
    });
    final made = code;
    if (!ok || made == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.householdInvite),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: SelectableText(
                made,
                style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.householdInviteHint),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l10n.householdCopy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: made));
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.householdCopied)));
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.householdOk),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, HouseholdMember member) async {
    final l10n = AppLocalizations.of(context);
    final name = _nameOf(member);
    final ok = await _confirm(
      context,
      title: l10n.householdRemoveConfirm(name),
      body: l10n.householdRemoveBody(name),
      action: l10n.householdRemove,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _run(context, () => service.removeMember(member.userId));
  }

  Future<void> _leave(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final last = household.members.length <= 1;
    final ok = await _confirm(
      context,
      title: l10n.householdLeaveConfirmTitle(household.name),
      body: last ? l10n.householdLeaveLast : l10n.householdLeaveBody,
      action: l10n.householdLeave,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _run(context, () async {
      await service.leave();
    });
  }

  String _nameOf(HouseholdMember m) {
    final name = m.displayName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return '${m.userId.substring(0, 6)}…';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(household.name, style: theme.textTheme.headlineSmall),
            ),
            if (_isOwner)
              IconButton(
                tooltip: l10n.householdRename,
                icon: const Icon(Icons.edit_outlined),
                onPressed: busy ? null : () => _rename(context),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.householdMembers, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final m in household.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Text(_nameOf(m).characters.first.toUpperCase()),
            ),
            title: Text(_nameOf(m)),
            subtitle: Text(
              [
                if (m.isOwner) l10n.householdOwner,
                if (m.userId == me) l10n.householdYou,
              ].join(' · '),
            ),
            trailing: _isOwner && m.userId != me
                ? IconButton(
                    tooltip: l10n.householdRemove,
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: busy ? null : () => _remove(context, m),
                  )
                : null,
          ),
        if (_isOwner) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: Text(l10n.householdInvite),
            onPressed: busy ? null : () => _invite(context),
          ),
        ],
        const SizedBox(height: 32),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.logout),
          label: Text(l10n.householdLeave),
          onPressed: busy ? null : () => _leave(context),
        ),
      ],
    );
  }
}
