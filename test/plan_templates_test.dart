import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/plan/domain/plan_templates.dart';

int total(List<PlanItemDraft> items) =>
    items.fold(0, (sum, i) => sum + i.amountMinor);

int groupTotal(List<PlanItemDraft> items, String group) => items
    .where((i) => i.group == group)
    .fold(0, (sum, i) => sum + i.amountMinor);

void main() {
  test('every template adds up to 100 percent except custom', () {
    for (final t in PlanTemplates.all) {
      expect(t.totalPercent, t.id == 'custom' ? 0 : 100, reason: t.id);
    }
  });

  test('50/30/20 at 2000 gives the expected split', () {
    final items = PlanTemplates.balanced.build(200000, 'USD');
    expect(total(items), 200000);
    expect(groupTotal(items, 'needs'), 100000);
    expect(groupTotal(items, 'wants'), 60000);
    expect(groupTotal(items, 'savings'), 40000);
    final housing = items.firstWhere((i) => i.categoryId == 'cat_housing');
    expect(housing.amountMinor, 40000);
    expect(housing.isFixed, isTrue);
  });

  test('70/20/10 has a giving and debt group', () {
    final items = PlanTemplates.seventy.build(200000, 'USD');
    expect(total(items), 200000);
    expect(groupTotal(items, 'savings'), 40000);
    expect(groupTotal(items, 'giving'), 20000);
  });

  test('80/20 saves a fifth of the income', () {
    final items = PlanTemplates.eighty.build(200000, 'USD');
    expect(total(items), 200000);
    expect(groupTotal(items, 'spending'), 160000);
    expect(groupTotal(items, 'savings'), 40000);
  });

  test('awkward incomes still add up exactly', () {
    for (final income in [123456, 99999, 1, 777777]) {
      for (final t in [
        PlanTemplates.balanced,
        PlanTemplates.seventy,
        PlanTemplates.eighty,
      ]) {
        expect(
          total(t.build(income, 'USD')),
          income,
          reason: '${t.id} $income',
        );
      }
    }
  });

  test('currencies without decimals add up too', () {
    final items = PlanTemplates.balanced.build(4000000, 'KHR');
    expect(total(items), 4000000);
  });

  test('custom starts at zero', () {
    final items = PlanTemplates.custom.build(200000, 'USD');
    expect(total(items), 0);
    expect(items, isNotEmpty);
  });

  test('every expense line points at a default category', () {
    const known = {
      'cat_housing',
      'cat_food',
      'cat_transport',
      'cat_bills',
      'cat_health',
      'cat_family',
      'cat_shopping',
      'cat_fun',
      'cat_personal',
      'cat_other',
    };
    for (final t in PlanTemplates.all) {
      for (final i in t.build(100000, 'USD')) {
        if (i.categoryId != null) expect(known, contains(i.categoryId));
      }
    }
  });
}
