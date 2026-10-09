import 'package:flutter_test/flutter_test.dart';
import 'package:thavika/features/reports/domain/report_math.dart';

ReportTx tx(
  String id,
  String type,
  int amount,
  DateTime on, {
  String? wallet = 'w1',
}) => ReportTx(
  id: id,
  type: type,
  amountMinor: amount,
  categoryId: 'cat_food',
  walletId: wallet,
  occurredOn: on,
);

void main() {
  final march = DateTime(2026, 3);

  test(
    'daily spending has one slot per day and ignores income and other months',
    () {
      final list = [
        tx('a', 'expense', 100, DateTime(2026, 3, 1)),
        tx('b', 'expense', 50, DateTime(2026, 3, 1)),
        tx('c', 'expense', 70, DateTime(2026, 3, 31)),
        tx('d', 'income', 999, DateTime(2026, 3, 2)),
        tx('e', 'expense', 888, DateTime(2026, 4, 1)),
      ];
      final days = ReportMath.dailySpending(list, march);
      expect(days.length, 31);
      expect(days[0], 150);
      expect(days[30], 70);
      expect(days[1], 0);
    },
  );

  test('February length follows the year', () {
    expect(ReportMath.dailySpending([], DateTime(2028, 2)).length, 29);
    expect(ReportMath.dailySpending([], DateTime(2026, 2)).length, 28);
  });

  test('monthly totals run oldest to newest across a year change', () {
    final list = [
      tx('a', 'income', 1000, DateTime(2025, 12, 5)),
      tx('b', 'expense', 400, DateTime(2025, 12, 6)),
      tx('c', 'expense', 100, DateTime(2026, 2, 1)),
    ];
    final totals = ReportMath.monthlyTotals(list, DateTime(2026, 2), 3);
    expect(totals.map((t) => t.month), [
      DateTime(2025, 12),
      DateTime(2026, 1),
      DateTime(2026, 2),
    ]);
    expect(totals[0].income, 1000);
    expect(totals[0].spent, 400);
    expect(totals[1].income, 0);
    expect(totals[2].spent, 100);
  });

  test('wallet report splits income and spending and skips no wallet', () {
    final list = [
      tx('a', 'income', 1000, DateTime(2026, 3, 1), wallet: 'w1'),
      tx('b', 'expense', 300, DateTime(2026, 3, 2), wallet: 'w1'),
      tx('c', 'expense', 200, DateTime(2026, 3, 3), wallet: 'w2'),
      tx('d', 'expense', 999, DateTime(2026, 3, 3), wallet: null),
      tx('e', 'expense', 999, DateTime(2026, 2, 3), wallet: 'w2'),
    ];
    final r = ReportMath.byWallet(list, march);
    expect(r['w1']!.income, 1000);
    expect(r['w1']!.spent, 300);
    expect(r['w2']!.spent, 200);
    expect(r.containsKey(null), isFalse);
    expect(r.length, 2);
  });

  test('tag report counts an entry for each of its tags', () {
    final list = [
      tx('a', 'expense', 500, DateTime(2026, 3, 1)),
      tx('b', 'expense', 100, DateTime(2026, 3, 2)),
      tx('c', 'income', 900, DateTime(2026, 3, 2)),
    ];
    final r = ReportMath.spendingByTag(list, march, {
      'a': ['trip', 'family'],
      'b': ['trip'],
      'c': ['trip'],
    });
    expect(r['trip'], 600);
    expect(r['family'], 500);
  });
}
