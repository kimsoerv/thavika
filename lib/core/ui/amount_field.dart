import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money/money.dart';

/// A text field for money: digits and one decimal point, with the currency
/// symbol in front.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.currency,
    this.label,
    this.errorText,
    this.autofocus = false,
    this.onChanged,
    this.style,
  });

  final TextEditingController controller;
  final String currency;
  final String? label;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final decimals = Money.decimalsFor(currency);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(decimals > 0 ? r'[0-9.]' : r'[0-9]'),
        ),
      ],
      style: style,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: Money.symbolFor(currency),
        hintText: '0',
        errorText: errorText,
      ),
    );
  }
}
