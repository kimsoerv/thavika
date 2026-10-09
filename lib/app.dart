import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/db/app_database.dart';
import 'core/routes/app_routes.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'features/entry/data/category_repository.dart';
import 'features/entry/presentation/entry_binding.dart';
import 'features/entry/presentation/entry_page.dart';
import 'features/goals/data/goal_repository.dart';
import 'features/goals/presentation/goal_detail_controller.dart';
import 'features/goals/presentation/goal_detail_page.dart';
import 'features/goals/presentation/goal_form_controller.dart';
import 'features/goals/presentation/goal_form_page.dart';
import 'features/plan/presentation/plan_setup_binding.dart';
import 'features/plan/presentation/plans_page.dart';
import 'features/plan/presentation/reminders_page.dart';
import 'features/plan/presentation/plan_setup_page.dart';
import 'features/recurring/application/recurring_service.dart';
import 'features/recurring/data/recurring_repository.dart';
import 'features/auth/presentation/account_page.dart';
import 'features/debts/data/debt_repository.dart';
import 'features/debts/presentation/debt_detail_page.dart';
import 'features/debts/presentation/debt_form_page.dart';
import 'features/debts/presentation/debts_page.dart';
import 'features/debts/presentation/net_worth_page.dart';
import 'features/recurring/presentation/bills_page.dart';
import 'features/recurring/presentation/recurring_controllers.dart';
import 'features/recurring/presentation/recurring_form_page.dart';
import 'features/recurring/presentation/recurring_list_page.dart';
import 'features/categories/presentation/categories_page.dart';
import 'features/entry/application/entry_meta_service.dart';
import 'features/settings/application/backup_service.dart';
import 'features/tags/data/tag_repository.dart';
import 'features/tags/presentation/tags_page.dart';
import 'features/wallets/data/transfer_repository.dart';
import 'features/wallets/data/wallet_repository.dart';
import 'features/wallets/presentation/transfer_form.dart';
import 'features/wallets/presentation/wallet_form.dart';
import 'features/wallets/presentation/wallets_controller.dart';
import 'features/wallets/presentation/wallets_page.dart';
import 'features/lock/presentation/lock_screen.dart';
import 'features/lock/presentation/pin_flow_page.dart';
import 'features/settings/presentation/settings_controller.dart';
import 'features/setup/presentation/setup_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/shell/presentation/shell_controller.dart';
import 'features/shell/presentation/shell_page.dart';
import 'l10n/gen/app_localizations.dart';

class ThavikaApp extends StatelessWidget {
  const ThavikaApp({super.key, this.showSetup = false});

  /// True on a brand-new install: the first-time setup opens first.
  final bool showSetup;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Get.find<SettingsService>().locale,
      builder: (context, child) => LockOverlay(child: child),
      initialRoute: showSetup ? Routes.setup : Routes.home,
      getPages: [
        GetPage(name: Routes.pinFlow, page: () => const PinFlowPage()),
        GetPage(name: Routes.reminders, page: () => const RemindersPage()),
        GetPage(
          name: Routes.debts,
          page: () => const DebtsPage(),
          binding: BindingsBuilder(
            () => Get.lazyPut(
              () => DebtsController(
                Get.find<DebtRepository>(),
                Get.find<SettingsService>(),
              ),
            ),
          ),
        ),
        GetPage(
          name: Routes.debtDetail,
          page: () => const DebtDetailPage(),
          binding: BindingsBuilder(
            () => Get.lazyPut(
              () => DebtDetailController(Get.find<DebtRepository>()),
            ),
          ),
        ),
        GetPage(
          name: Routes.debtForm,
          page: () => const DebtFormPage(),
          binding: BindingsBuilder(
            () => Get.lazyPut(
              () => DebtFormController(
                Get.find<DebtRepository>(),
                Get.find<SettingsService>(),
                Get.find<EntryMetaService>(),
              ),
            ),
          ),
        ),
        GetPage(
          name: Routes.netWorth,
          page: () => const NetWorthPage(),
          binding: BindingsBuilder(
            () => Get.lazyPut(
              () => NetWorthController(
                Get.find<WalletRepository>(),
                Get.find<DebtRepository>(),
                Get.find<GoalRepository>(),
                Get.find<SettingsService>(),
              ),
            ),
          ),
        ),
        GetPage(name: Routes.account, page: () => const AccountPage()),
        GetPage(
          name: Routes.bills,
          page: () => const BillsPage(),
          binding: BindingsBuilder(
            () => Get.lazyPut(() => BillsController(Get.find())),
          ),
        ),
        GetPage(
          name: Routes.plans,
          page: () => const PlansPage(),
          binding: PlansBinding(),
        ),
        GetPage(
          name: Routes.setup,
          page: () => const SetupPage(),
          binding: SetupBinding(),
        ),
        GetPage(
          name: Routes.home,
          page: () => const ShellPage(),
          binding: ShellBinding(),
        ),
        GetPage(
          name: Routes.entry,
          page: () => const EntryPage(),
          binding: EntryBinding(),
          fullscreenDialog: true,
        ),
        GetPage(
          name: Routes.planSetup,
          page: () => const PlanSetupPage(),
          binding: PlanSetupBinding(),
        ),
        GetPage(
          name: Routes.goalDetail,
          page: () => const GoalDetailPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(() => GoalDetailController(Get.find<GoalRepository>()));
          }),
        ),
        GetPage(
          name: Routes.goalForm,
          page: () => const GoalFormPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(
              () => GoalFormController(
                Get.find<GoalRepository>(),
                Get.find<SettingsService>(),
              ),
            );
          }),
        ),
        GetPage(
          name: Routes.recurringList,
          page: () => const RecurringListPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(
              () => RecurringListController(Get.find<RecurringRepository>()),
            );
          }),
        ),
        GetPage(
          name: Routes.recurringForm,
          page: () => const RecurringFormPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(
              () => RecurringFormController(
                Get.find<RecurringRepository>(),
                Get.find<CategoryRepository>(),
                Get.find<SettingsService>(),
                Get.find<RecurringService>(),
              ),
            );
          }),
        ),
        GetPage(
          name: Routes.settings,
          page: () => const SettingsPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(
              () => SettingsController(
                Get.find<AppDatabase>(),
                Get.find<SettingsService>(),
                Get.find<BackupService>(),
              ),
            );
          }),
        ),
        GetPage(
          name: Routes.wallets,
          page: () => const WalletsPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(
              () => WalletsController(
                Get.find<WalletRepository>(),
                Get.find<TransferRepository>(),
                Get.find<EntryMetaService>(),
                Get.find<SettingsService>(),
              ),
            );
          }),
        ),
        GetPage(
          name: Routes.walletForm,
          page: () => const WalletFormPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(
              () => WalletFormController(
                Get.find<WalletRepository>(),
                Get.find<SettingsService>(),
              ),
            );
          }),
        ),
        GetPage(
          name: Routes.transferForm,
          page: () => const TransferFormPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(
              () => TransferFormController(
                Get.find<TransferRepository>(),
                Get.find<EntryMetaService>(),
                Get.find<SettingsService>(),
              ),
            );
          }),
        ),
        GetPage(
          name: Routes.tags,
          page: () => const TagsPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(
              () => TagsController(
                Get.find<TagRepository>(),
                Get.find<EntryMetaService>(),
              ),
            );
          }),
        ),
        GetPage(
          name: Routes.categories,
          page: () => const CategoriesPage(),
          binding: BindingsBuilder(() {
            Get.lazyPut(
              () => CategoriesController(Get.find<CategoryRepository>()),
            );
          }),
        ),
      ],
    );
  }
}
