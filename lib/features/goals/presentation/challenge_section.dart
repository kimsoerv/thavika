import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/ui/amount_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge_math.dart';
import 'goals_section.dart';

/// The saving challenge of a goal: start one, tick weeks off, see the streak.
class ChallengeSection extends StatelessWidget {
  const ChallengeSection({
    super.key,
    required this.goalId,
    required this.currency,
  });

  final String goalId;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final repo = Get.find<ChallengeRepository>();
    return StreamBuilder<ChallengeRow?>(
      stream: repo.watchForGoal(goalId),
      builder: (context, snap) {
        final challenge = snap.data;
        if (challenge == null) {
          return _StartButton(repo: repo, goalId: goalId, currency: currency);
        }
        return _ChallengeCard(
          repo: repo,
          challenge: challenge,
          currency: currency,
        );
      },
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.repo,
    required this.goalId,
    required this.currency,
  });

  final ChallengeRepository repo;
  final String goalId;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.flag_outlined),
        label: Text(l10n.challengeStart),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: () async {
          final result = await showDialog<_NewChallenge>(
            context: context,
            builder: (_) => _StartDialog(currency: currency),
          );
          if (result == null) return;
          await repo.start(
            goalId: goalId,
            kind: result.kind,
            unitMinor: result.unitMinor,
            steps: result.steps,
          );
        },
      ),
    );
  }
}

class _NewChallenge {
  const _NewChallenge(this.kind, this.unitMinor, this.steps);

  final String kind;
  final int unitMinor;
  final int steps;
}

class _StartDialog extends StatefulWidget {
  const _StartDialog({required this.currency});

  final String currency;

  @override
  State<_StartDialog> createState() => _StartDialogState();
}

class _StartDialogState extends State<_StartDialog> {
  final _unit = TextEditingController();
  final _steps = TextEditingController(text: '52');
  String _kind = 'weekly';
  bool _error = false;

  @override
  void dispose() {
    _unit.dispose();
    _steps.dispose();
    super.dispose();
  }

  int get _unitMinor => Money.parseMinor(_unit.text, widget.currency);
  int get _stepCount => (int.tryParse(_steps.text) ?? 0).clamp(0, 104);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = _unitMinor > 0 && _stepCount > 0
        ? ChallengeMath.totalAmount(_kind, _unitMinor, _stepCount)
        : 0;
    return AlertDialog(
      title: Text(l10n.challengeStart),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<String>(
              groupValue: _kind,
              onChanged: (v) => setState(() => _kind = v ?? _kind),
              child: Column(
                children: [
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'weekly',
                    title: Text(l10n.challengeKindStepUp),
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'fixed',
                    title: Text(l10n.challengeKindFixed),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AmountField(
              controller: _unit,
              currency: widget.currency,
              label: l10n.challengeUnit,
              errorText: _error && _unitMinor <= 0
                  ? l10n.goalAmountRequired
                  : null,
              onChanged: (_) => setState(() => _error = false),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _steps,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.challengeWeeks),
              onChanged: (_) => setState(() {}),
            ),
            if (total > 0) ...[
              const SizedBox(height: 12),
              Text(
                l10n.challengeTotalHint(Money.format(total, widget.currency)),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_unitMinor <= 0 || _stepCount <= 0) {
              setState(() => _error = true);
              return;
            }
            Navigator.pop(
              context,
              _NewChallenge(_kind, _unitMinor, _stepCount),
            );
          },
          child: Text(l10n.challengeCreate),
        ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.repo,
    required this.challenge,
    required this.currency,
  });

  final ChallengeRepository repo;
  final ChallengeRow challenge;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = challenge;
    final done = ChallengeMath.parseSteps(c.completedSteps);
    final due = ChallengeMath.dueStep(c.startOn, DateTime.now(), c.steps);
    final streak = ChallengeMath.streak(done, due);
    final behind = ChallengeMath.behind(done, due);

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.kind == 'weekly'
                        ? l10n.challengeStepUpTitle
                        : l10n.challengeFixedTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.challengeStop,
                  icon: const Icon(Icons.close),
                  onPressed: () => _stop(context),
                ),
              ],
            ),
            Text(
              l10n.challengeDone(done.length, c.steps),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              behind > 0
                  ? l10n.challengeBehind(behind)
                  : l10n.challengeStreak(streak),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: behind > 0 ? theme.colorScheme.error : goalColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var step = 1; step <= c.steps; step++)
                  Tooltip(
                    message: l10n.challengeStepTip(
                      step,
                      Money.format(
                        ChallengeMath.stepAmount(c.kind, c.unitMinor, step),
                        currency,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => repo.toggleStep(c.id, step),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: done.contains(step)
                              ? goalColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: done.contains(step)
                                ? goalColor
                                : step < due
                                ? theme.colorScheme.error
                                : step == due
                                ? goalColor
                                : theme.colorScheme.outlineVariant,
                            width: step <= due && !done.contains(step) ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          '$step',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: done.contains(step)
                                ? Colors.white
                                : step > due
                                ? theme.colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stop(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.challengeStop),
        content: Text(l10n.challengeStopBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.challengeStop),
          ),
        ],
      ),
    );
    if (ok == true) await repo.delete(challenge.id);
  }
}
