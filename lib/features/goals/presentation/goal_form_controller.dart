import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../data/goal_repository.dart';

class GoalFormController extends GetxController {
  GoalFormController(this._repo, this._settings);

  final GoalRepository _repo;
  final SettingsService _settings;

  /// Set when an existing goal is being edited.
  GoalRow? editing;

  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final targetDate = Rxn<DateTime>();
  final nameError = false.obs;
  final amountError = false.obs;
  final saving = false.obs;

  bool get isEditing => editing != null;
  String get currency => editing?.currency ?? _settings.currency.value;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is GoalRow) {
      editing = args;
      nameCtrl.text = args.name;
      amountCtrl.text = Money.toInputText(args.targetMinor, args.currency);
      targetDate.value = args.targetDate;
    }
  }

  /// Returns the goal id, or null when something is missing.
  Future<String?> save() async {
    if (saving.value) return null;
    final name = nameCtrl.text.trim();
    final target = Money.parseMinor(amountCtrl.text, currency);
    nameError.value = name.isEmpty;
    amountError.value = target <= 0;
    if (name.isEmpty || target <= 0) return null;

    saving.value = true;
    try {
      final existing = editing;
      if (existing != null) {
        await _repo.updateGoal(
          existing.id,
          name: name,
          targetMinor: target,
          targetDate: targetDate.value,
        );
        return existing.id;
      }
      return await _repo.addGoal(
        name: name,
        targetMinor: target,
        currency: currency,
        targetDate: targetDate.value,
      );
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
    super.onClose();
  }
}
