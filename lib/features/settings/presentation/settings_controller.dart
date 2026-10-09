import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../application/backup_service.dart';

class SettingsController extends GetxController {
  SettingsController(this._db, this.settings, this.backup);

  final AppDatabase _db;
  final SettingsService settings;
  final BackupService backup;

  /// True once entries, a plan, or goals exist; the currency is then locked
  /// because totals would mix currencies.
  final hasData = false.obs;

  static List<String> get currencies => Money.supportedCurrencies;

  @override
  void onInit() {
    super.onInit();
    refreshHasData();
  }

  Future<void> refreshHasData() async {
    final tx = await (_db.select(_db.transactions)..limit(1)).get();
    final plans = await (_db.select(_db.plans)..limit(1)).get();
    final goals = await (_db.select(_db.goals)..limit(1)).get();
    hasData.value = tx.isNotEmpty || plans.isNotEmpty || goals.isNotEmpty;
  }

  Future<void> setCurrency(String code) => settings.setCurrency(code);

  Future<String?> exportAllCsv() => backup.exportCsvFile();

  Future<String?> exportAllExcel() => backup.exportXlsxFile();

  Future<String> exportBackup() => backup.exportBackupFile();

  /// Throws [BackupException] when the file is not a Thavika backup.
  Future<void> restore(String json) async {
    await backup.restoreFromJson(json);
    await refreshHasData();
  }
}
