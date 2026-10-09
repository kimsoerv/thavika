import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/plan/domain/plan_templates.dart';
import 'package:thavika/features/setup/domain/setup_advice.dart';

int _sum(List<PlanItemDraft> items) =>
    items.fold(0, (s, i) => s + i.amountMinor);

PlanItemDraft _byCat(List<PlanItemDraft> items, String cat) =>
    items.firstWhere((i) => i.categoryId == cat);

void main() {
  group('recommend', () {
    test('rent and food up to half of income suggest 50/30/20', () {
      expect(SetupAdvice.recommend(200000, 50000, 50000), 'balanced');
    });
    test('over half and up to 65% suggest 70/20/10', () {
      expect(SetupAdvice.recommend(200000, 70000, 50000), 'seventy');
      expect(SetupAdvice.recommend(200000, 80000, 50000), 'seventy');
    });
    test('over 65% suggests a custom plan', () {
      expect(SetupAdvice.recommend(200000, 100000, 50000), 'custom');
    });
    test('unknown income falls back to 50/30/20', () {
      expect(SetupAdvice.recommend(0, 0, 0), 'balanced');
      expect(SetupAdvice.needsPercent(0, 100, 100), 0);
    });
  });

  group('buildPlan', () {
    test('without known costs it is the plain template', () {
      final items = SetupAdvice.buildPlan(
        template: PlanTemplates.balanced,
        incomeMinor: 200000,
        currency: 'USD',
      );
      expect(_sum(items), 200000);
    });

    test('bigger rent and food are paid for by the wants, not savings', () {
      final plain = PlanTemplates.balanced.build(200000, 'USD');
      final items = SetupAdvice.buildPlan(
        template: PlanTemplates.balanced,
        incomeMinor: 200000,
        currency: 'USD',
        rentMinor: 60000,
        foodMinor: 50000,
      );
      expect(_byCat(items, 'cat_housing').amountMinor, 60000);
      expect(_byCat(items, 'cat_food').amountMinor, 50000);
      expect(_sum(items), 200000);
      for (final cat in ['cat_shopping', 'cat_fun', 'cat_personal']) {
        expect(
          _byCat(items, cat).amountMinor,
          lessThan(_byCat(plain, cat).amountMinor),
        );
      }
      expect(
        items
            .where((i) => i.group == 'savings')
            .fold(0, (s, i) => s + i.amountMinor),
        plain
            .where((i) => i.group == 'savings')
            .fold(0, (s, i) => s + i.amountMinor),
      );
    });

    test('lower rent and food move the extra into savings goals', () {
      final plain = PlanTemplates.balanced.build(200000, 'USD');
      final items = SetupAdvice.buildPlan(
        template: PlanTemplates.balanced,
        incomeMinor: 200000,
        currency: 'USD',
        rentMinor: 20000,
        foodMinor: 10000,
      );
      expect(_sum(items), 200000);
      final goals = items.firstWhere((i) => i.name == 'goals');
      final plainGoals = plain.firstWhere((i) => i.name == 'goals');
      expect(goals.amountMinor, greaterThan(plainGoals.amountMinor));
    });

    test('totals stay exact in a currency without decimals', () {
      final items = SetupAdvice.buildPlan(
        template: PlanTemplates.seventy,
        incomeMinor: 2000000,
        currency: 'KHR',
        rentMinor: 700000,
        foodMinor: 500000,
      );
      expect(_sum(items), 2000000);
      expect(items.every((i) => i.amountMinor >= 0), isTrue);
    });

    test('custom plan only gets the known costs', () {
      final items = SetupAdvice.buildPlan(
        template: PlanTemplates.custom,
        incomeMinor: 200000,
        currency: 'USD',
        rentMinor: 100000,
        foodMinor: 60000,
      );
      expect(_sum(items), 160000);
    });
  });
}
