import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';

/// One budget line while the user is building or editing a plan.
class PlanItemDraft {
  PlanItemDraft({
    String? uid,
    required this.group,
    required this.name,
    this.categoryId,
    required this.amountMinor,
    this.isFixed = false,
  }) : uid = uid ?? const Uuid().v4();

  final String uid;
  String group;

  /// Display name, or a key such as 'emergency_fund' for built-in items.
  String name;

  /// Expense category the budget is checked against (null for savings etc.).
  String? categoryId;
  int amountMinor;
  bool isFixed;
}

class _Line {
  const _Line(
    this.group,
    this.name,
    this.percent, {
    this.categoryId,
    this.fixed = false,
  });

  final String group;
  final String name;
  final int percent;
  final String? categoryId;
  final bool fixed;
}

class PlanTemplate {
  const PlanTemplate(this.id, this.groups, this._lines);

  final String id;

  /// Groups in display order.
  final List<String> groups;
  final List<_Line> _lines;

  /// Percentages add up to 100 for every template except 'custom' (all 0).
  int get totalPercent => _lines.fold(0, (s, l) => s + l.percent);

  /// Turns the percentages into amounts for [incomeMinor].
  ///
  /// Each amount is rounded to a whole currency unit, and the rounding
  /// difference goes to the biggest line so the total is exactly the income.
  List<PlanItemDraft> build(int incomeMinor, String currency) {
    final unit = pow(10, Money.decimalsFor(currency)).toInt();
    final drafts = <PlanItemDraft>[];
    var sum = 0;
    for (final line in _lines) {
      final raw = incomeMinor * line.percent / 100;
      final rounded = (raw / unit).round() * unit;
      sum += rounded;
      drafts.add(
        PlanItemDraft(
          group: line.group,
          name: line.name,
          categoryId: line.categoryId,
          amountMinor: rounded,
          isFixed: line.fixed,
        ),
      );
    }
    final target = (incomeMinor * totalPercent / 100).round();
    final diff = target - sum;
    if (diff != 0 && drafts.isNotEmpty) {
      var biggest = drafts.first;
      for (final d in drafts) {
        if (d.amountMinor > biggest.amountMinor) biggest = d;
      }
      biggest.amountMinor = max(0, biggest.amountMinor + diff);
    }
    return drafts;
  }
}

class PlanTemplates {
  PlanTemplates._();

  static const balanced = PlanTemplate(
    'balanced',
    ['needs', 'wants', 'savings'],
    [
      _Line('needs', 'cat_housing', 20, categoryId: 'cat_housing', fixed: true),
      _Line('needs', 'cat_food', 13, categoryId: 'cat_food'),
      _Line('needs', 'cat_transport', 6, categoryId: 'cat_transport'),
      _Line('needs', 'cat_bills', 6, categoryId: 'cat_bills', fixed: true),
      _Line('needs', 'cat_health', 3, categoryId: 'cat_health'),
      _Line('needs', 'cat_family', 2, categoryId: 'cat_family'),
      _Line('wants', 'cat_shopping', 11, categoryId: 'cat_shopping'),
      _Line('wants', 'cat_fun', 9, categoryId: 'cat_fun'),
      _Line('wants', 'cat_personal', 6, categoryId: 'cat_personal'),
      _Line('wants', 'cat_other', 4, categoryId: 'cat_other'),
      _Line('savings', 'emergency_fund', 10),
      _Line('savings', 'goals', 10),
    ],
  );

  static const seventy = PlanTemplate(
    'seventy',
    ['needs', 'wants', 'savings', 'giving'],
    [
      _Line('needs', 'cat_housing', 22, categoryId: 'cat_housing', fixed: true),
      _Line('needs', 'cat_food', 14, categoryId: 'cat_food'),
      _Line('needs', 'cat_transport', 7, categoryId: 'cat_transport'),
      _Line('needs', 'cat_bills', 6, categoryId: 'cat_bills', fixed: true),
      _Line('needs', 'cat_health', 3, categoryId: 'cat_health'),
      _Line('needs', 'cat_family', 3, categoryId: 'cat_family'),
      _Line('wants', 'cat_shopping', 6, categoryId: 'cat_shopping'),
      _Line('wants', 'cat_fun', 4, categoryId: 'cat_fun'),
      _Line('wants', 'cat_personal', 3, categoryId: 'cat_personal'),
      _Line('wants', 'cat_other', 2, categoryId: 'cat_other'),
      _Line('savings', 'emergency_fund', 10),
      _Line('savings', 'goals', 10),
      _Line('giving', 'giving', 5),
      _Line('giving', 'debt_payment', 5),
    ],
  );

  static const eighty = PlanTemplate(
    'eighty',
    ['spending', 'savings'],
    [
      _Line(
        'spending',
        'cat_housing',
        26,
        categoryId: 'cat_housing',
        fixed: true,
      ),
      _Line('spending', 'cat_food', 16, categoryId: 'cat_food'),
      _Line('spending', 'cat_transport', 8, categoryId: 'cat_transport'),
      _Line('spending', 'cat_bills', 8, categoryId: 'cat_bills', fixed: true),
      _Line('spending', 'cat_health', 3, categoryId: 'cat_health'),
      _Line('spending', 'cat_family', 3, categoryId: 'cat_family'),
      _Line('spending', 'cat_shopping', 7, categoryId: 'cat_shopping'),
      _Line('spending', 'cat_fun', 5, categoryId: 'cat_fun'),
      _Line('spending', 'cat_personal', 2, categoryId: 'cat_personal'),
      _Line('spending', 'cat_other', 2, categoryId: 'cat_other'),
      _Line('savings', 'emergency_fund', 10),
      _Line('savings', 'goals', 10),
    ],
  );

  /// Same lines as 'balanced', all at zero for the user to fill in.
  static const custom = PlanTemplate(
    'custom',
    ['needs', 'wants', 'savings'],
    [
      _Line('needs', 'cat_housing', 0, categoryId: 'cat_housing', fixed: true),
      _Line('needs', 'cat_food', 0, categoryId: 'cat_food'),
      _Line('needs', 'cat_transport', 0, categoryId: 'cat_transport'),
      _Line('needs', 'cat_bills', 0, categoryId: 'cat_bills', fixed: true),
      _Line('needs', 'cat_health', 0, categoryId: 'cat_health'),
      _Line('needs', 'cat_family', 0, categoryId: 'cat_family'),
      _Line('wants', 'cat_shopping', 0, categoryId: 'cat_shopping'),
      _Line('wants', 'cat_fun', 0, categoryId: 'cat_fun'),
      _Line('wants', 'cat_personal', 0, categoryId: 'cat_personal'),
      _Line('wants', 'cat_other', 0, categoryId: 'cat_other'),
      _Line('savings', 'emergency_fund', 0),
      _Line('savings', 'goals', 0),
    ],
  );

  static const all = [balanced, seventy, eighty, custom];

  static PlanTemplate byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => custom);
}
