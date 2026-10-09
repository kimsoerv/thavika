import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/entry/domain/quick_line.dart';

void main() {
  const categories = [
    CategoryHint(id: 'cat_food', name: 'Food', isIncome: false),
    CategoryHint(id: 'cat_transport', name: 'Transport', isIncome: false),
    CategoryHint(id: 'cat_bills', name: 'Bills', isIncome: false),
    CategoryHint(id: 'cat_personal', name: 'Personal care', isIncome: false),
    CategoryHint(id: 'cat_personal2', name: 'Personal', isIncome: false),
    CategoryHint(id: 'cat_salary', name: 'Salary', isIncome: true),
  ];

  QuickLine parse(String text, {Map<String, String> known = const {}}) =>
      parseQuickLine(
        text,
        currency: 'USD',
        categories: categories,
        knownNotes: known,
      );

  test('the last number is the amount, the rest is the note', () {
    final r = parse('coffee 2.5');
    expect(r.amountMinor, 250);
    expect(r.note, 'coffee');
    expect(r.isIncome, isFalse);
  });

  test('the amount can come first or have a symbol', () {
    expect(parse('2.5 coffee').amountMinor, 250);
    expect(parse('coffee \$2.5').amountMinor, 250);
    expect(parse('coffee 2.5\$').amountMinor, 250);
    expect(parse('lunch ៛4000').amountMinor, 400000);
  });

  test('thousands and decimal commas', () {
    expect(parse('school 1,000').amountMinor, 100000);
    expect(parse('tea 2,5').amountMinor, 250);
    expect(parse('car 1,234.50').amountMinor, 123450);
  });

  test('numbers inside the note stay in the note', () {
    final r = parse('2 coffees 3');
    expect(r.amountMinor, 300);
    expect(r.note, '2 coffees');
  });

  test('no amount', () {
    final r = parse('just a note');
    expect(r.amountMinor, isNull);
    expect(r.note, 'just a note');
  });

  test('empty text', () {
    final r = parse('   ');
    expect(r.amountMinor, isNull);
    expect(r.note, '');
  });

  test('zero is not an amount', () {
    expect(parse('free sample 0').amountMinor, isNull);
  });

  test('a plus sign or an income word makes it income', () {
    expect(parse('+2000 pay').isIncome, isTrue);
    expect(parse('+2000 pay').note, 'pay');
    expect(parse('salary 2000').isIncome, isTrue);
    expect(parse('Bonus 100').isIncome, isTrue);
    expect(parse('coffee 2').isIncome, isFalse);
  });

  test('the category comes from a note used before', () {
    final r = parse('coffee 2.5', known: {'coffee': 'cat_food'});
    expect(r.categoryId, 'cat_food');
  });

  test('or from a category name in the line', () {
    expect(parse('bills 40').categoryId, 'cat_bills');
    expect(parse('electric bills 40').categoryId, 'cat_bills');
    expect(parse('transport grab 3').categoryId, 'cat_transport');
  });

  test('the longest category name wins', () {
    expect(parse('personal care 12').categoryId, 'cat_personal');
    expect(parse('personal 12').categoryId, 'cat_personal2');
  });

  test('income only matches income categories', () {
    expect(parse('salary 2000').categoryId, 'cat_salary');
    expect(parse('food 5').categoryId, 'cat_food');
    // "food" is an expense category, so it is ignored for income.
    expect(parse('+food bonus 5').categoryId, isNull);
  });

  test('names must match whole words', () {
    expect(parse('foodie 5').categoryId, isNull);
  });
}
