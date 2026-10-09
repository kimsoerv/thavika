import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/services/settings_service.dart';
import 'features/auth/application/auth_service.dart';
import 'features/debts/data/debt_repository.dart';
import 'features/entry/application/entry_meta_service.dart';
import 'features/entry/data/category_repository.dart';
import 'features/receipts/receipt_service.dart';
import 'features/goals/data/challenge_repository.dart';
import 'features/goals/data/goal_repository.dart';
import 'features/lock/application/lock_service.dart';
import 'features/plan/application/budget_service.dart';
import 'features/plan/application/pay_yourself_first.dart';
import 'features/plan/application/reminder_scheduler.dart';
import 'features/plan/application/reminder_service.dart';
import 'features/plan/data/plan_repository.dart';
import 'features/recurring/application/recurring_service.dart';
import 'features/recurring/data/recurring_repository.dart';
import 'features/settings/application/backup_service.dart';
import 'features/sync/application/sync_service.dart';
import 'features/tags/data/tag_repository.dart';
import 'features/transactions/data/transaction_repository.dart';
import 'features/widget/widget_sync.dart';
import 'features/wallets/data/transfer_repository.dart';
import 'features/wallets/data/wallet_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // App-wide services live for the whole app run.
  final db = Get.put<AppDatabase>(AppDatabase(), permanent: true);
  final settings = await Get.putAsync<SettingsService>(
    () => SettingsService(db).init(),
    permanent: true,
  );
  final auth = await Get.putAsync<AuthService>(
    () => AuthService().init(),
    permanent: true,
  );
  await Get.putAsync<LockService>(
    () => LockService(settings).init(),
    permanent: true,
  );
  Get.put(CategoryRepository(db), permanent: true);
  final transactions = Get.put(TransactionRepository(db), permanent: true);
  final plans = Get.put(PlanRepository(db), permanent: true);
  Get.put(GoalRepository(db), permanent: true);
  Get.put(ChallengeRepository(db), permanent: true);
  final recurring = Get.put(RecurringRepository(db), permanent: true);
  Get.put(WalletRepository(db), permanent: true);
  Get.put(DebtRepository(db), permanent: true);
  Get.put(TransferRepository(db), permanent: true);
  Get.put(TagRepository(db), permanent: true);
  Get.put(BackupService(db, settings), permanent: true);
  Get.put(ReceiptService(), permanent: true);

  await Get.putAsync<EntryMetaService>(
    () => EntryMetaService(
      Get.find<WalletRepository>(),
      Get.find<TagRepository>(),
    ).init(),
    permanent: true,
  );

  // Entries that were due while the app was closed are created first, so the
  // plan check already counts them.
  await Get.putAsync<RecurringService>(
    () => RecurringService(recurring).init(),
    permanent: true,
  );
  final reminders = await Get.putAsync<ReminderService>(
    () => ReminderService(settings).init(),
    permanent: true,
  );
  final budget = await Get.putAsync<BudgetService>(
    () => BudgetService(transactions, plans, reminders).init(),
    permanent: true,
  );
  Get.put(
    PayYourselfFirst(budget, Get.find<GoalRepository>(), settings),
    permanent: true,
  );
  await Get.putAsync<ReminderScheduler>(
    () => ReminderScheduler(
      reminders,
      budget,
      Get.find<GoalRepository>(),
      recurring,
    ).init(),
    permanent: true,
  );

  await Get.putAsync<SyncService>(
    () => SyncService(db, settings, auth).init(),
    permanent: true,
  );
  final widgetSync = await Get.putAsync<WidgetSync>(
    () => WidgetSync(budget, settings).init(),
    permanent: true,
  );
  final showSetup = await settings.needsSetup();
  runApp(ThavikaApp(showSetup: showSetup));
  if (!showSetup) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widgetSync.handleLaunch();
    });
  }
}
