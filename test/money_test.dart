import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/core/money/money.dart';

void main() {
  group('Money.parseMinor', () {
    test('whole and decimal amounts', () {
      expect(Money.parseMinor('4', 'USD'), 400);
      expect(Money.parseMinor('4.5', 'USD'), 450);
      expect(Money.parseMinor('4.50', 'USD'), 450);
      expect(Money.parseMinor('0.05', 'USD'), 5);
      expect(Money.parseMinor('12.', 'USD'), 1200);
    });

    test('ignores extra decimals instead of rounding', () {
      expect(Money.parseMinor('1.239', 'USD'), 123);
    });

    test('currencies without decimals', () {
      expect(Money.parseMinor('4000', 'KHR'), 4000);
    });

    test('empty or invalid text is zero', () {
      expect(Money.parseMinor('', 'USD'), 0);
      expect(Money.parseMinor('.', 'USD'), 0);
      expect(Money.parseMinor('1.2.3', 'USD'), 0);
    });
  });

  group('Money.format', () {
    test('adds symbol, separators and decimals', () {
      expect(Money.format(450, 'USD'), r'$4.50');
      expect(Money.format(123456, 'USD'), r'$1,234.56');
      expect(Money.format(4000, 'KHR'), '៛4,000');
    });

    test('puts the minus sign before the symbol', () {
      expect(Money.format(-450, 'USD'), r'-$4.50');
    });
  });

  group('Money.toInputText', () {
    test('round trips through the keypad text', () {
      expect(Money.toInputText(450, 'USD'), '4.5');
      expect(Money.toInputText(400, 'USD'), '4');
      expect(Money.toInputText(5, 'USD'), '0.05');
      expect(Money.toInputText(4000, 'KHR'), '4000');
    });
  });
}
