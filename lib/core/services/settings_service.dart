import 'dart:ui';

import 'package:drift/drift.dart';
import 'package:get/get.dart' hide Value;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../db/app_database.dart';

/// App-wide settings stored in the local database.
class SettingsService extends GetxService {
  SettingsService(this._db);

  final AppDatabase _db;

  static const _currencyKey = 'currency';
  static const _languageKey = 'language';
  static const _setupDoneKey = 'setup_done';

  /// Languages the app is translated into.
  static const languages = ['en', 'km'];

  /// 'system', 'en' or 'km'.
  final language = 'system'.obs;

  /// The language the app shows right now.
  Locale get locale {
    final chosen = language.value;
    if (languages.contains(chosen)) return Locale(chosen);
    final system = PlatformDispatcher.instance.locale.languageCode;
    return Locale(languages.contains(system) ? system : 'en');
  }

  /// Main currency code (one per household later).
  final currency = 'USD'.obs;

  Future<SettingsService> init() async {
    final saved = await getString(_currencyKey);
    if (saved != null) currency.value = saved;
    final lang = await getString(_languageKey);
    if (lang != null) language.value = lang;
    await initializeDateFormatting();
    Intl.defaultLocale = locale.languageCode;
    return this;
  }

  /// True for a brand-new install. Someone who already has entries, a plan
  /// or goals (an older version of the app) skips the first-time setup.
  Future<bool> needsSetup() async {
    if (await getString(_setupDoneKey) != null) return false;
    final tx = await (_db.select(_db.transactions)..limit(1)).get();
    final plans = await (_db.select(_db.plans)..limit(1)).get();
    final goals = await (_db.select(_db.goals)..limit(1)).get();
    if (tx.isNotEmpty || plans.isNotEmpty || goals.isNotEmpty) {
      await markSetupDone();
      return false;
    }
    return true;
  }

  Future<void> markSetupDone() => setString(_setupDoneKey, '1');

  Future<void> setLanguage(String code) async {
    language.value = code;
    Intl.defaultLocale = locale.languageCode;
    await setString(_languageKey, code);
    Get.updateLocale(locale);
  }

  Future<void> setCurrency(String code) async {
    currency.value = code;
    await setString(_currencyKey, code);
    // Wallets use the main currency.
    final list = await _db.select(_db.wallets).get();
    for (final w in list) {
      if (w.currency == code) continue;
      await (_db.update(_db.wallets)..where((x) => x.id.equals(w.id))).write(
        WalletsCompanion(
          currency: Value(code),
          updatedAt: Value(DateTime.now()),
          syncState: const Value('pending'),
        ),
      );
      await _db.enqueue('wallets', w.id, 'upsert');
    }
  }

  Future<String?> getString(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.settingKey.equals(key))).getSingleOrNull();
    return row?.settingValue;
  }

  Future<void> setString(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(settingKey: key, settingValue: value),
        );
  }
}
