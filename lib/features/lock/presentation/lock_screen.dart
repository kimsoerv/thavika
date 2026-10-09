import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../application/lock_service.dart';
import 'pin_pad.dart';

/// Covers the whole app while it is locked.
class LockOverlay extends StatelessWidget {
  const LockOverlay({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final lock = Get.find<LockService>();
    return Stack(
      children: [
        ?child,
        Obx(
          () => lock.locked.value
              ? const Positioned.fill(child: LockScreen())
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _lock = Get.find<LockService>();
  final _wrong = false.obs;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lock.waitSeconds.value > 0) {
        _lock.waitSeconds.value = _lock.remainingWait;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _biometric() async {
    if (!mounted || !_lock.biometric.value) return;
    final reason = AppLocalizations.of(context).lockBiometricReason;
    await _lock.unlockWithBiometrics(reason);
  }

  Future<void> _submit(String pin) async {
    final result = await _lock.unlockWithPin(pin);
    _wrong.value = result == PinResult.wrong;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(l10n.lockTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Obx(() {
                  final wait = _lock.waitSeconds.value;
                  final text = wait > 0
                      ? l10n.lockWait(wait)
                      : _wrong.value
                      ? l10n.lockWrong
                      : l10n.lockEnterPin;
                  final bad = wait > 0 || _wrong.value;
                  return Text(
                    text,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: bad
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }),
                const SizedBox(height: 32),
                Obx(
                  () => PinPad(
                    enabled: _lock.waitSeconds.value == 0,
                    onComplete: _submit,
                    corner: _lock.biometric.value
                        ? IconButton(
                            tooltip: l10n.lockBiometricButton,
                            icon: const Icon(Icons.fingerprint, size: 32),
                            onPressed: _biometric,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
