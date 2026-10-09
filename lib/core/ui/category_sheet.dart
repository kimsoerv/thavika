import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import 'category_visuals.dart';

/// Bottom sheet to create or edit a category: a name and an icon.
/// It owns its text controller, so the controller is disposed only after the
/// sheet is fully gone.
class CategoryEditSheet extends StatefulWidget {
  const CategoryEditSheet({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    this.initialName = '',
    this.initialIcon,
  });

  final String title;
  final String submitLabel;
  final String initialName;
  final String? initialIcon;
  final Future<void> Function(String name, String icon) onSubmit;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String submitLabel,
    required Future<void> Function(String name, String icon) onSubmit,
    String initialName = '',
    String? initialIcon,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CategoryEditSheet(
        title: title,
        submitLabel: submitLabel,
        onSubmit: onSubmit,
        initialName: initialName,
        initialIcon: initialIcon,
      ),
    );
  }

  @override
  State<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<CategoryEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late String _icon = widget.initialIcon ?? customIconKeys.first;
  var _showError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    await widget.onSubmit(name, _icon);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // An icon chosen earlier stays selectable even if it is not in the list.
    final icons = [
      if (!customIconKeys.contains(_icon)) _icon,
      ...customIconKeys,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 24,
            decoration: InputDecoration(
              labelText: l10n.categoryName,
              errorText: _showError ? l10n.categoryNameRequired : null,
              counterText: '',
            ),
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in icons)
                IconButton.filledTonal(
                  isSelected: key == _icon,
                  icon: Icon(iconFor(key)),
                  onPressed: () => setState(() => _icon = key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
        ],
      ),
    );
  }
}
