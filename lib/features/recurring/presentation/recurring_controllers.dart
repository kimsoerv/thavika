import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../../entry/data/category_repository.dart';
import '../application/recurring_service.dart';
import '../data/recurring_repository.dart';

class RecurringListController extends GetxController {
  RecurringListController(this._repo);

  final RecurringRepository _repo;
  final rules = <RecurringWithCategory>[].obs;
  StreamSubscription<List<RecurringWithCategory>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _repo.watchAll().listen(rules.assignAll);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

class RecurringFormController extends GetxController {
  RecurringFormController(
    this._repo,
    this._categories,
    this._settings,
    this._service,
  );

  final RecurringRepository _repo;
  final CategoryRepository _categories;
  final SettingsService _settings;
  final RecurringService _service;

  /// Set when an existing rule is being edited.
  RecurringWithCategory? editing;

  final type = 'expense'.obs;
  final categoryId = RxnString();
  final frequency = 'monthly'.obs;
  final startOn = DateTime.now().obs;
  final isActive = true.obs;
  final isBill = false.obs;
  final autoCreate = true.obs;
  final remindDays = 2.obs;
  final categories = <CategoryRow>[].obs;
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final amountError = false.obs;
  final categoryError = false.obs;
  final saving = false.obs;

  StreamSubscription<List<CategoryRow>>? _catSub;

  bool get isEditing => editing != null;
  String get currency => editing?.rule.currency ?? _settings.currency.value;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is RecurringWithCategory) {
      editing = args;
      final r = args.rule;
      type.value = r.type;
      categoryId.value = r.categoryId;
      frequency.value = r.frequency;
      startOn.value = r.startOn;
      isActive.value = r.isActive;
      isBill.value = r.isBill;
      autoCreate.value = r.autoCreate;
      remindDays.value = r.remindDaysBefore;
      amountCtrl.text = Money.toInputText(r.amountMinor, r.currency);
      noteCtrl.text = r.note;
    } else if (args == 'bill') {
      isBill.value = true;
    }
    _listenCategories();
  }

  void _listenCategories() {
    _catSub?.cancel();
    _catSub = _categories.watch(type.value).listen(categories.assignAll);
  }

  void setType(String value) {
    if (type.value == value) return;
    type.value = value;
    categoryId.value = null;
    _listenCategories();
  }

  /// Returns true when the rule was saved.
  Future<bool> save() async {
    if (saving.value) return false;
    final minor = Money.parseMinor(amountCtrl.text, currency);
    final cat = categoryId.value;
    amountError.value = minor <= 0;
    categoryError.value = cat == null;
    if (minor <= 0 || cat == null) return false;

    saving.value = true;
    try {
      final note = noteCtrl.text.trim();
      final existing = editing;
      if (existing != null) {
        await _repo.update(
          existing.rule,
          type: type.value,
          amountMinor: minor,
          categoryId: cat,
          note: note,
          frequency: frequency.value,
          startOn: startOn.value,
          isActive: isActive.value,
          isBill: isBill.value && type.value == 'expense',
          autoCreate: autoCreate.value,
          remindDaysBefore: remindDays.value,
        );
      } else {
        await _repo.add(
          type: type.value,
          amountMinor: minor,
          currency: currency,
          categoryId: cat,
          note: note,
          frequency: frequency.value,
          startOn: startOn.value,
          isBill: isBill.value && type.value == 'expense',
          autoCreate: autoCreate.value,
          remindDaysBefore: remindDays.value,
        );
      }
      // Create today's (or any past-dated) entries right away.
      await _service.generateDue();
      return true;
    } finally {
      saving.value = false;
    }
  }

  Future<void> delete() async {
    final existing = editing;
    if (existing != null) await _repo.delete(existing.rule.id);
  }

  @override
  void onClose() {
    _catSub?.cancel();
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.onClose();
  }
}
