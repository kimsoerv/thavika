import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// Asks for one line of text. Returns null when cancelled or left empty.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  int maxLength = 24,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPrompt(
      title: title,
      label: label,
      initial: initial,
      maxLength: maxLength,
    ),
  );
}

/// A dialog that owns its text controller, so the controller is disposed
/// only after the dialog is fully gone.
class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.label,
    required this.initial,
    required this.maxLength,
  });

  final String title;
  final String label;
  final String initial;
  final int maxLength;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    Navigator.pop(context, text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: widget.maxLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: widget.label, counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
