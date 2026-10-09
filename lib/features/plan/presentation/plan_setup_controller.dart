import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../../entry/data/category_repository.dart';
import '../../goals/data/goal_repository.dart';
import '../../goals/domain/goal_math.dart';
import '../application/reminder_service.dart';
import '../data/plan_repository.dart';
import '../../setup/domain/setup_advice.dart';
import '../domain/plan_balance.dart';
import '../domain/plan_templates.dart';

class PlanSetupController extends GetxController {
  PlanSetupController(
    this._plans,
    this._categories,
    this._settings,
    this._reminders,
    this._goals,
  );

  final PlanRepository _plans;
  final CategoryRepository _categories;
  final SettingsService _settings;
  final ReminderService _reminders;
  final GoalRepository _goals;

  /// Set when an existing plan is being edited.
  PlanWithItems? editing;

  final incomeCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  /// What the open goals with a date need each month, together.
  final goalsMonthly = 0.obs;
  final incomeMinor = 0.obs;
  final incomeError = false.obs;
  final templateIndex = 0.obs;
  final items = <PlanItemDraft>[].obs;
  final categories = <CategoryRow>[].obs;
  final editMode = false.obs;
  final dirty = false.obs;
  final saving = false.obs;

  StreamSubscription<List<CategoryRow>>? _catSub;
  StreamSubscription<List<GoalWithSaved>>? _goalSub;

  bool get isEditing => editing != null;
  String get currency => editing?.plan.currency ?? _settings.currency.value;
  PlanTemplate get template => PlanTemplates.all[templateIndex.value];

  /// Groups in display order; a group that only exists in saved items is appended.
  List<String> get groups {
    final result = [...template.groups];
    for (final i in items) {
      if (!result.contains(i.group)) result.add(i.group);
    }
    return result;
  }

  @override
  void onInit() {
    super.onInit();
    _catSub = _categories.watch('expense').listen(categories.assignAll);
    _goalSub = _goals.watchGoals().listen((list) {
      final today = DateTime.now();
      goalsMonthly.value = list.fold<int>(0, (sum, g) {
        final p = goalProgress(
          targetMinor: g.goal.targetMinor,
          savedMinor: g.savedMinor,
          targetDate: g.goal.targetDate,
          today: today,
        );
        return sum + (p.monthlyNeededMinor ?? 0);
      });
    });

    final args = Get.arguments;
    if (args is PlanWithItems) {
      editing = args;
      final index = PlanTemplates.all.indexWhere(
        (t) => t.id == args.plan.template,
      );
      templateIndex.value = index == -1 ? PlanTemplates.all.length - 1 : index;
      incomeMinor.value = args.plan.incomeMinor;
      incomeCtrl.text = Money.toInputText(args.plan.incomeMinor, currency);
      nameCtrl.text = args.plan.name ?? '';
      items.assignAll([
        for (final i in args.items)
          PlanItemDraft(
            group: i.groupName,
            name: i.name,
            categoryId: i.categoryId,
            amountMinor: i.amountMinor,
            isFixed: i.isFixed,
          ),
      ]);
      dirty.value = true;
    } else if (args is PlanSeed) {
      final index = PlanTemplates.all.indexWhere(
        (t) => t.id == args.templateId,
      );
      templateIndex.value = index == -1 ? 0 : index;
      incomeMinor.value = args.incomeMinor;
      incomeCtrl.text = Money.toInputText(args.incomeMinor, currency);
      items.assignAll(
        SetupAdvice.buildPlan(
          template: template,
          incomeMinor: args.incomeMinor,
          currency: currency,
          rentMinor: args.rentMinor,
          foodMinor: args.foodMinor,
        ),
      );
      // Keep the amounts the user gave when they change the income.
      dirty.value = args.rentMinor > 0 || args.foodMinor > 0;
    } else {
      _rebuild();
    }
  }

  void _rebuild() {
    items.assignAll(template.build(incomeMinor.value, currency));
  }

  void onIncomeChanged(String text) {
    incomeMinor.value = Money.parseMinor(text, currency);
    incomeError.value = false;
    if (!dirty.value) _rebuild();
  }

  void selectTemplate(int index) {
    templateIndex.value = index;
    dirty.value = false;
    _rebuild();
  }

  void reset() {
    dirty.value = false;
    _rebuild();
  }

  /// Share of income that the goals need, in percent.
  int get goalsPercent =>
      PlanBalance.percentOfIncome(goalsMonthly.value, incomeMinor.value);

  /// Sets the saving to what the goals need and shrinks the rest to fit.
  void fitToGoals() {
    if (goalsMonthly.value <= 0 || incomeMinor.value <= 0) return;
    items.assignAll(
      PlanBalance.fitToGoals(
        template: template,
        incomeMinor: incomeMinor.value,
        currency: currency,
        goalsMonthlyMinor: goalsMonthly.value,
      ),
    );
    dirty.value = true;
  }

  void toggleEdit() => editMode.value = !editMode.value;

  void setAmount(String uid, int minor) {
    final item = items.firstWhereOrNull((i) => i.uid == uid);
    if (item == null) return;
    item.amountMinor = minor;
    dirty.value = true;
    items.refresh();
  }

  void rename(String uid, String name) {
    final item = items.firstWhereOrNull((i) => i.uid == uid);
    if (item == null) return;
    item.name = name;
    dirty.value = true;
  }

  void remove(String uid) {
    items.removeWhere((i) => i.uid == uid);
    dirty.value = true;
  }

  void addItem({
    required String group,
    required String name,
    String? categoryId,
  }) {
    items.add(
      PlanItemDraft(
        group: group,
        name: name,
        categoryId: categoryId,
        amountMinor: 0,
      ),
    );
    dirty.value = true;
  }

  /// Expense categories that have no line in the plan yet.
  List<CategoryRow> get unusedCategories {
    final used = items.map((i) => i.categoryId).whereType<String>().toSet();
    return categories.where((c) => !used.contains(c.id)).toList();
  }

  int totalFor(String group) => items
      .where((i) => i.group == group)
      .fold(0, (sum, i) => sum + i.amountMinor);

  int get assigned => items.fold(0, (sum, i) => sum + i.amountMinor);
  int get left => incomeMinor.value - assigned;
  int get savings => totalFor('savings');

  /// Saves the plan. Returns false when the income is missing.
  Future<bool> use() async {
    if (saving.value) return false;
    if (incomeMinor.value <= 0) {
      incomeError.value = true;
      return false;
    }
    saving.value = true;
    try {
      await _plans.savePlan(
        template: template.id,
        incomeMinor: incomeMinor.value,
        currency: currency,
        items: items.toList(),
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
      );
      // Ask for notification permission now that reminders have a purpose.
      await _reminders.requestPermission();
      return true;
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    _catSub?.cancel();
    _goalSub?.cancel();
    nameCtrl.dispose();
    incomeCtrl.dispose();
    super.onClose();
  }
}
