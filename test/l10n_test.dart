import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, String> _load(String name) {
  final json =
      jsonDecode(File('lib/l10n/$name').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

Set<String> _placeholders(String text) =>
    RegExp(r'\{(\w+)(?:,|\})').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  final en = _load('app_en.arb');
  final km = _load('app_km.arb');

  test('Khmer has every English key and nothing extra', () {
    expect(km.keys.toSet(), en.keys.toSet());
  });

  test('Khmer keeps the same placeholders as English', () {
    for (final key in en.keys) {
      expect(
        _placeholders(km[key]!),
        _placeholders(en[key]!),
        reason: 'placeholders differ for $key',
      );
    }
  });

  test('no Khmer string is empty', () {
    for (final e in km.entries) {
      expect(e.value.trim(), isNotEmpty, reason: e.key);
    }
  });
}
