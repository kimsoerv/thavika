import 'package:flutter/material.dart';

/// Four dots and a number pad. Calls [onComplete] with the PIN once it is
/// full, then clears itself.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onComplete,
    this.length = 4,
    this.enabled = true,
    this.corner,
  });

  final Future<void> Function(String pin) onComplete;
  final int length;
  final bool enabled;

  /// Shown bottom left, e.g. a fingerprint button.
  final Widget? corner;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _busy = false;

  Future<void> _press(String digit) async {
    if (!widget.enabled || _busy || _pin.length >= widget.length) return;
    setState(() => _pin += digit);
    if (_pin.length == widget.length) {
      _busy = true;
      final pin = _pin;
      await widget.onComplete(pin);
      if (!mounted) return;
      setState(() {
        _pin = '';
        _busy = false;
      });
    }
  }

  void _erase() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.length; i++)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          _row([for (final d in row) _key(d)]),
        _row([
          SizedBox(width: 72, height: 72, child: widget.corner),
          _key('0'),
          SizedBox(
            width: 72,
            height: 72,
            child: IconButton(
              icon: const Icon(Icons.backspace_outlined),
              onPressed: widget.enabled ? _erase : null,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final c in children)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: c,
          ),
      ],
    ),
  );

  Widget _key(String digit) => SizedBox(
    width: 72,
    height: 72,
    child: FilledButton.tonal(
      style: FilledButton.styleFrom(shape: const CircleBorder()),
      onPressed: widget.enabled ? () => _press(digit) : null,
      child: Text(digit, style: Theme.of(context).textTheme.headlineSmall),
    ),
  );
}
