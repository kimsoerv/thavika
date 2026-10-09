import 'dart:math';

import 'package:intl/intl.dart';

/// Money helpers. Amounts are always integers in minor units (cents).
class Money {
  Money._();

  static const _noDecimals = {'KHR', 'JPY', 'VND', 'KRW'};

  static const _symbols = {
    'USD': r'$',
    'KHR': '៛',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'THB': '฿',
    'VND': '₫',
    'KRW': '₩',
    'SGD': r'S$',
    'AUD': r'A$',
  };

  static List<String> get supportedCurrencies => _symbols.keys.toList();

  static int decimalsFor(String currency) =>
      _noDecimals.contains(currency) ? 0 : 2;

  static String symbolFor(String currency) => _symbols[currency] ?? currency;

  /// 450 -> "$4.50"
  static String format(int minor, String currency) {
    if (minor < 0) return '-${format(-minor, currency)}';
    final d = decimalsFor(currency);
    final value = minor / pow(10, d);
    final f = NumberFormat.decimalPatternDigits(
      locale: 'en_US',
      decimalDigits: d,
    );
    return '${symbolFor(currency)}${f.format(value)}';
  }

  /// "4.5" -> 450. Returns 0 when the text is empty or not a number.
  static int parseMinor(String text, String currency) {
    final d = decimalsFor(currency);
    final cleaned = text.trim();
    if (cleaned.isEmpty || cleaned == '.') return 0;
    final parts = cleaned.split('.');
    if (parts.length > 2) return 0;
    final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    if (whole == null) return 0;
    var frac = parts.length > 1 ? parts[1] : '';
    if (frac.length > d) frac = frac.substring(0, d);
    frac = frac.padRight(d, '0');
    final fracValue = d == 0 ? 0 : (int.tryParse(frac) ?? 0);
    return whole * pow(10, d).toInt() + fracValue;
  }

  /// 450 -> "4.5", 400 -> "4" (text to put back in the keypad when editing).
  static String toInputText(int minor, String currency) {
    final d = decimalsFor(currency);
    if (d == 0) return '$minor';
    final unit = pow(10, d).toInt();
    final whole = minor ~/ unit;
    var frac = (minor % unit).toString().padLeft(d, '0');
    frac = frac.replaceFirst(RegExp(r'0+$'), '');
    return frac.isEmpty ? '$whole' : '$whole.$frac';
  }
}
