import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/money/money.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/settings_service.dart';
import '../../entry/application/entry_meta_service.dart';
import '../../wallets/data/wallet_repository.dart';
import '../domain/setup_advice.dart';

class SetupController extends GetxController {
  SetupController(this.settings, this._wallets, this._meta);

  final SettingsService settings;
  final WalletRepository _wallets;
  final EntryMetaService _meta;

  /// Language, currency, money now, income and costs.
  static const stepCount = 4;

  final step = 0.obs;
  final saving = false.obs;

  final openingCtrl = TextEditingController();
  final incomeCtrl = TextEditingController();
  final rentCtrl = TextEditingController();
  final foodCtrl = TextEditingController();

  final openingMinor = 0.obs;
  final incomeMinor = 0.obs;
  final rentMinor = 0.obs;
  final foodMinor = 0.obs;

  /// Set when the user picks a plan; until then the suggestion is used.
  final picked = RxnString();

  String get currency => settings.currency.value;
  bool get isLast => step.value == stepCount - 1;

  int get needsPercent => SetupAdvice.needsPercent(
    incomeMinor.value,
    rentMinor.value,
    foodMinor.value,
  );

  String get suggested => SetupAdvice.recommend(
    incomeMinor.value,
    rentMinor.value,
    foodMinor.value,
  );

  String get chosen => picked.value ?? suggested;

  void next() {
    if (!isLast) step.value++;
  }

  void back() {
    if (step.value > 0) step.value--;
  }

  Future<void> setLanguage(String code) => settings.setLanguage(code);

  /// Nothing exists yet, so the currency can change freely here.
  Future<void> setCurrency(String code) async {
    await settings.setCurrency(code);
    // The same digits mean a different amount in another currency.
    onOpeningChanged(openingCtrl.text);
    onIncomeChanged(incomeCtrl.text);
    onRentChanged(rentCtrl.text);
    onFoodChanged(foodCtrl.text);
  }

  void onOpeningChanged(String t) =>
      openingMinor.value = Money.parseMinor(t, currency);
  void onIncomeChanged(String t) =>
      incomeMinor.value = Money.parseMinor(t, currency);
  void onRentChanged(String t) =>
      rentMinor.value = Money.parseMinor(t, currency);
  void onFoodChanged(String t) =>
      foodMinor.value = Money.parseMinor(t, currency);

  void pick(String templateId) => picked.value = templateId;

  /// Finishes the setup. With [withPlan] and an income, the plan screen
  /// opens already filled in; otherwise the app opens on the home tab.
  Future<void> finish({required bool withPlan}) async {
    if (saving.value) return;
    saving.value = true;
    try {
      if (openingMinor.value > 0) {
        final wallet = _meta.wallets.firstOrNull;
        if (wallet != null) {
          await _wallets.update(
            wallet.id,
            name: wallet.name,
            kind: wallet.kind,
            icon: wallet.icon,
            openingMinor: openingMinor.value,
          );
        }
      }
      await settings.markSetupDone();
    } finally {
      saving.value = false;
    }

    final seed = withPlan && incomeMinor.value > 0
        ? PlanSeed(
            templateId: chosen,
            incomeMinor: incomeMinor.value,
            rentMinor: rentMinor.value,
            foodMinor: foodMinor.value,
          )
        : null;
    Get.offAllNamed(Routes.home);
    if (seed != null) Get.toNamed(Routes.planSetup, arguments: seed);
  }

  @override
  void onClose() {
    openingCtrl.dispose();
    incomeCtrl.dispose();
    rentCtrl.dispose();
    foodCtrl.dispose();
    super.onClose();
  }
}
