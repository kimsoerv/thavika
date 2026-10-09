import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../application/lock_service.dart';
import 'pin_pad.dart';

enum PinFlow { set, change, disable }

/// Turn the lock on, change the PIN, or turn the lock off.
class PinFlowPage extends StatefulWidget {
  const PinFlowPage({super.key});

  @override
  State<PinFlowPage> createState() => _PinFlowPageState();
}

enum _Stage { current, fresh, confirm }

class _PinFlowPageState extends State<PinFlowPage> {
  final _lock = Get.find<LockService>();
  late final PinFlow _flow = Get.arguments is PinFlow
      ? Get.arguments as PinFlow
      : PinFlow.set;
  late _Stage _stage = _flow == PinFlow.set ? _Stage.fresh : _Stage.current;
  String _first = '';
  bool _error = false;
  bool _wrongCurrent = false;

  Future<void> _onPin(String pin) async {
    switch (_stage) {
      case _Stage.current:
        if (!await _lock.check(pin)) {
          setState(() => _wrongCurrent = true);
          return;
        }
        if (_flow == PinFlow.disable) {
          await _lock.disable();
          Get.back(result: false);
          return;
        }
        setState(() {
          _wrongCurrent = false;
          _stage = _Stage.fresh;
        });
      case _Stage.fresh:
        setState(() {
          _first = pin;
          _error = false;
          _stage = _Stage.confirm;
        });
      case _Stage.confirm:
        if (pin != _first) {
          setState(() {
            _error = true;
            _stage = _Stage.fresh;
          });
          return;
        }
        await _lock.setPin(pin);
        Get.back(result: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = switch (_stage) {
      _Stage.current => l10n.lockEnterCurrent,
      _Stage.fresh => l10n.lockEnterNew,
      _Stage.confirm => l10n.lockConfirmNew,
    };
    final message = _wrongCurrent
        ? l10n.lockWrong
        : _error
        ? l10n.lockMismatch
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLock)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 24,
                  child: message == null
                      ? null
                      : Text(
                          message,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                ),
                const SizedBox(height: 16),
                PinPad(key: ValueKey(_stage), onComplete: _onPin),
                if (_flow != PinFlow.disable && _stage == _Stage.fresh) ...[
                  const SizedBox(height: 24),
                  Text(
                    l10n.lockForgotWarning,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
