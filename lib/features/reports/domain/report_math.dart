/// One entry as the reports see it.
class ReportTx {
  const ReportTx({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.categoryId,
    required this.walletId,
    required this.occurredOn,
  });

  final String id;

  /// 'expense' or 'income'
  final String type;
  final int amountMinor;
  final String categoryId;
  final String? walletId;
  final DateTime occurredOn;
}

class MonthTotal {
  const MonthTotal(this.month, this.income, this.spent);

  final DateTime month;
  final int income;
  final int spent;
}

class InOut {
  const InOut(this.income, this.spent);

  final int income;
  final int spent;
}

class ReportMath {
  ReportMath._();

  static bool _inMonth(DateTime d, DateTime month) =>
      d.year == month.year && d.month == month.month;

  /// Spending for each day of [month]; index 0 is the 1st.
  static List<int> dailySpending(List<ReportTx> list, DateTime month) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final out = List<int>.filled(days, 0);
    for (final e in list) {
      if (e.type != 'expense' || !_inMonth(e.occurredOn, month)) continue;
      out[e.occurredOn.day - 1] += e.amountMinor;
    }
    return out;
  }

  /// Income and spending of the [count] months ending with [lastMonth],
  /// oldest first.
  static List<MonthTotal> monthlyTotals(
    List<ReportTx> list,
    DateTime lastMonth,
    int count,
  ) {
    final out = <MonthTotal>[];
    for (var i = count - 1; i >= 0; i--) {
      final m = DateTime(lastMonth.year, lastMonth.month - i);
      var income = 0;
      var spent = 0;
      for (final e in list) {
        if (!_inMonth(e.occurredOn, m)) continue;
        if (e.type == 'income') {
          income += e.amountMinor;
        } else {
          spent += e.amountMinor;
        }
      }
      out.add(MonthTotal(m, income, spent));
    }
    return out;
  }

  /// Income and spending per wallet in [month]. Entries without a wallet
  /// are left out.
  static Map<String, InOut> byWallet(List<ReportTx> list, DateTime month) {
    final income = <String, int>{};
    final spent = <String, int>{};
    for (final e in list) {
      final w = e.walletId;
      if (w == null || !_inMonth(e.occurredOn, month)) continue;
      final target = e.type == 'income' ? income : spent;
      target[w] = (target[w] ?? 0) + e.amountMinor;
    }
    return {
      for (final w in {...income.keys, ...spent.keys})
        w: InOut(income[w] ?? 0, spent[w] ?? 0),
    };
  }

  /// Spending per tag in [month]. An entry with two tags counts for both,
  /// so the tags do not add up to the month's total.
  static Map<String, int> spendingByTag(
    List<ReportTx> list,
    DateTime month,
    Map<String, List<String>> links,
  ) {
    final out = <String, int>{};
    for (final e in list) {
      if (e.type != 'expense' || !_inMonth(e.occurredOn, month)) continue;
      for (final tag in links[e.id] ?? const <String>[]) {
        out[tag] = (out[tag] ?? 0) + e.amountMinor;
      }
    }
    return out;
  }
}
