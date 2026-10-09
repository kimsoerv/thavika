import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/plan/domain/pay_yourself_first.dart';
import 'package:thavika/features/plan/domain/plan_advisor.dart';
import 'package:thavika/features/plan/domain/plan_balance.dart';
import 'package:thavika/features/plan/domain/plan_templates.dart';

int _sum(List<PlanItemDraft> l) => l.fold(0, (s, i) => s + i.amountMinor);
PlanItemDraft _named(List<PlanItemDraft> l, String n) =>
    l.firstWhere((i) => i.name == n);

void main() {
  group('fitToGoals', () {
    test('goals line gets the monthly need, total stays the income', () {
      final items = PlanBalance.fitToGoals(
        template: PlanTemplates.balanced,
        incomeMinor: 200000,
        currency: 'USD',
        goalsMonthlyMinor: 50000,
      );
      expect(_named(items, 'goals').amountMinor, 50000);
      expect(_sum(items), 200000);
      // Emergency fund and needs are not touched while wants can pay for it.
      expect(_named(items, 'emergency_fund').amountMinor, 20000);
      expect(_named(items, 'cat_housing').amountMinor, 40000);
    });

    test('wants shrink before needs', () {
      final plain = PlanTemplates.balanced.build(200000, 'USD');
      final items = PlanBalance.fitToGoals(
        template: PlanTemplates.balanced,
        incomeMinor: 200000,
        currency: 'USD',
        goalsMonthlyMinor: 50000,
      );
      expect(
        _named(items, 'cat_fun').amountMinor,
        lessThan(_named(plain, 'cat_fun').amountMinor),
      );
    });

    test('a huge need takes wants and then needs but never goes negative', () {
      final items = PlanBalance.fitToGoals(
        template: PlanTemplates.balanced,
        incomeMinor: 200000,
        currency: 'USD',
        goalsMonthlyMinor: 150000,
      );
      expect(items.every((i) => i.amountMinor >= 0), isTrue);
      expect(_named(items, 'goals').amountMinor, 150000);
    });

    test('a smaller need puts the difference on the emergency fund', () {
      final items = PlanBalance.fitToGoals(
        template: PlanTemplates.balanced,
        incomeMinor: 200000,
        currency: 'USD',
        goalsMonthlyMinor: 5000,
      );
      expect(_named(items, 'goals').amountMinor, 5000);
      // The difference lands on the emergency fund, the other free saving.
      expect(_sum(items), 200000);
      expect(_named(items, 'emergency_fund').amountMinor, 35000);
    });

    test('custom template gets a goals line without rebalancing', () {
      final items = PlanBalance.fitToGoals(
        template: PlanTemplates.custom,
        incomeMinor: 200000,
        currency: 'USD',
        goalsMonthlyMinor: 30000,
      );
      expect(_named(items, 'goals').amountMinor, 30000);
      expect(_sum(items), 30000);
    });

    test('percentOfIncome', () {
      expect(PlanBalance.percentOfIncome(50000, 200000), 25);
      expect(PlanBalance.percentOfIncome(1, 0), 0);
    });
  });

  group('suggestSetAside', () {
    int s({
      int planned = 40000,
      int income = 200000,
      int moved = 0,
      int entry = 200000,
    }) => suggestSetAside(
      plannedSavingsMinor: planned,
      planIncomeMinor: income,
      movedThisMonthMinor: moved,
      incomeEntryMinor: entry,
      currency: 'USD',
    );

    test('a full salary suggests the whole planned saving', () {
      expect(s(), 40000);
    });
    test('a smaller income suggests its share', () {
      expect(s(entry: 50000), 10000);
    });
    test('never more than what is left', () {
      expect(s(moved: 35000), 5000);
    });
    test('nothing left, nothing suggested', () {
      expect(s(moved: 40000), 0);
      expect(s(planned: 0), 0);
    });
    test('rounds to whole currency units', () {
      expect(s(entry: 33333), 6700);
    });
  });

  group('PlanAdvisor', () {
    AdviceLine line(
      String id,
      int budget, {
      String group = 'wants',
      bool fixed = false,
    }) => AdviceLine(
      id: id,
      categoryId: 'cat_$id',
      group: group,
      budgetMinor: budget,
      isFixed: fixed,
    );

    List<AdviceMove> suggest(
      List<AdviceLine> lines,
      List<Map<String, int>> months,
    ) => PlanAdvisor.suggest(
      lines: lines,
      spentByMonth: months,
      currency: 'USD',
    );

    test(
      'moves from a line that keeps coming in low to one that runs over',
      () {
        final moves = suggest(
          [line('food', 30000, group: 'needs'), line('fun', 20000)],
          [
            {'cat_food': 40000, 'cat_fun': 5000},
            {'cat_food': 38000, 'cat_fun': 6000},
          ],
        );
        expect(moves.length, 1);
        expect(moves.first.fromLineId, 'fun');
        expect(moves.first.toLineId, 'food');
        // Average 39000 - 30000 = 9000 needed; fun has 20000 - 6000 spare.
        expect(moves.first.amountMinor, 9000);
      },
    );

    test('one bad month out of two is not enough', () {
      final moves = suggest(
        [line('food', 30000, group: 'needs'), line('fun', 20000)],
        [
          {'cat_food': 40000, 'cat_fun': 5000},
          {'cat_food': 29000, 'cat_fun': 6000},
        ],
      );
      expect(moves, isEmpty);
    });

    test('fixed and savings lines are never touched', () {
      final moves = suggest(
        [
          line('rent', 30000, group: 'needs', fixed: true),
          line('fun', 20000),
          line('goals', 10000, group: 'savings'),
        ],
        [
          {'cat_rent': 40000, 'cat_fun': 5000, 'cat_goals': 0},
        ],
      );
      expect(moves, isEmpty);
    });

    test('nothing is suggested when the donors cover less than half', () {
      final moves = suggest(
        [line('food', 30000, group: 'needs'), line('fun', 20000)],
        [
          {'cat_food': 60000, 'cat_fun': 15000},
        ],
      );
      expect(moves, isEmpty);
    });

    test('no months, no advice', () {
      expect(suggest([line('food', 100)], const []), isEmpty);
    });

    test('a donor is not used twice', () {
      final moves = suggest(
        [
          line('food', 30000, group: 'needs'),
          line('transport', 10000, group: 'needs'),
          line('fun', 20000),
        ],
        [
          {'cat_food': 40000, 'cat_transport': 15000, 'cat_fun': 10000},
        ],
      );
      final fromFun = moves
          .where((m) => m.fromLineId == 'fun')
          .fold<int>(0, (s, m) => s + m.amountMinor);
      expect(fromFun, lessThanOrEqualTo(10000));
    });
  });
}
