import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/plan/domain/plan_check.dart';

void main() {
  // 12 October: 31 days in the month.
  final day12 = DateTime(2026, 10, 12);

  group('paceStatus', () {
    // Budget $240: expected by day 12 is about $93.
    test('at or below the expected amount is on track', () {
      expect(
        paceStatus(spent: 9000, budget: 24000, today: day12),
        PaceStatus.onTrack,
      );
    });

    test('up to 15 percent above is slightly ahead', () {
      expect(
        paceStatus(spent: 10000, budget: 24000, today: day12),
        PaceStatus.slightlyAhead,
      );
    });

    test('more than 15 percent above is off track', () {
      expect(
        paceStatus(spent: 12000, budget: 24000, today: day12),
        PaceStatus.offTrack,
      );
    });

    test('using the whole budget is over', () {
      expect(
        paceStatus(spent: 24000, budget: 24000, today: day12),
        PaceStatus.over,
      );
    });

    test('a zero budget', () {
      expect(paceStatus(spent: 0, budget: 0, today: day12), PaceStatus.onTrack);
      expect(paceStatus(spent: 1, budget: 0, today: day12), PaceStatus.over);
    });

    test('the same spending is fine late in the month', () {
      expect(
        paceStatus(spent: 12000, budget: 24000, today: DateTime(2026, 10, 20)),
        PaceStatus.onTrack,
      );
    });
  });

  group('computePlanCheck', () {
    const lines = [
      PlanLine(
        id: 'housing',
        group: 'needs',
        name: 'cat_housing',
        categoryId: 'cat_housing',
        budgetMinor: 44000,
        isFixed: true,
      ),
      PlanLine(
        id: 'food',
        group: 'needs',
        name: 'cat_food',
        categoryId: 'cat_food',
        budgetMinor: 28000,
        isFixed: false,
      ),
      PlanLine(
        id: 'shopping',
        group: 'wants',
        name: 'cat_shopping',
        categoryId: 'cat_shopping',
        budgetMinor: 24000,
        isFixed: false,
      ),
      PlanLine(
        id: 'emergency',
        group: 'savings',
        name: 'emergency_fund',
        categoryId: null,
        budgetMinor: 20000,
        isFixed: false,
      ),
      PlanLine(
        id: 'goals',
        group: 'savings',
        name: 'goals',
        categoryId: null,
        budgetMinor: 20000,
        isFixed: false,
      ),
    ];

    PlanCheck check(Map<String, int> spent, [DateTime? today]) =>
        computePlanCheck(
          lines: lines,
          spentByCategory: spent,
          today: today ?? day12,
        );

    test('statuses, safe to spend and projected savings', () {
      final c = check({
        'cat_housing': 44000,
        'cat_food': 12000,
        'cat_shopping': 19200,
      });

      // Savings lines have no category, so only three lines are checked.
      expect(c.items, hasLength(3));
      expect(c.items[0].status, PaceStatus.onTrack); // fixed, paid in full
      expect(c.items[1].status, PaceStatus.slightlyAhead);
      expect(c.items[2].status, PaceStatus.offTrack);
      expect(c.overall, PaceStatus.offTrack);
      expect(c.offTrackCount, 1);
      expect(c.slightlyAheadCount, 1);

      // Fixed bills are left out of the flexible numbers.
      expect(c.flexibleBudget, 52000);
      expect(c.flexibleSpent, 31200);
      // (52000 - 31200) / 20 days left including today.
      expect(c.safeToSpend, 1040);
      expect(c.daysLeft, 19);

      expect(c.plannedSavings, 40000);
      // Pace: 31200 / 12 * 31 = 80600, which is 28600 over the flexible budget.
      expect(c.projectedSavings, 11400);
      expect(c.projectionReliable, isTrue);
    });

    test('a fixed bill is only a problem when it goes over', () {
      final c = check({'cat_housing': 50000});
      expect(c.items.first.status, PaceStatus.over);
    });

    test('safe to spend never goes below zero', () {
      final c = check({'cat_food': 30000, 'cat_shopping': 30000});
      expect(c.safeToSpend, 0);
      expect(c.projectedSavings, 0);
    });

    test('nothing spent means on track with the full savings', () {
      final c = check({});
      expect(c.overall, PaceStatus.onTrack);
      expect(c.projectedSavings, 40000);
    });

    test('the projection is not trusted in the first days of the month', () {
      final c = check({'cat_shopping': 20000}, DateTime(2026, 10, 2));
      expect(c.projectionReliable, isFalse);
    });
  });
}
