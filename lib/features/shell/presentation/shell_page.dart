import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../home/presentation/home_page.dart';
import '../../plan/presentation/plan_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/presentation/transactions_page.dart';
import 'shell_controller.dart';

class ShellPage extends GetView<ShellController> {
  const ShellPage({super.key});

  Future<void> _add(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    // GetX can't type the route result, so read it as dynamic.
    final result = await Get.toNamed(Routes.entry);
    final id = result is String ? result : null;
    if (id == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          persist: false,
          duration: const Duration(seconds: 5),
          content: Text(l10n.entrySaved),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => Get.find<TransactionRepository>().softDelete(id),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Obx(
        () => IndexedStack(
          index: controller.tab.value,
          children: const [
            HomePage(),
            TransactionsPage(),
            PlanPage(),
            ReportsPage(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Obx(
          () => Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: l10n.tabHome,
                  selected: controller.tab.value == ShellController.homeTab,
                  onTap: () => controller.tab.value = ShellController.homeTab,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: l10n.tabTransactions,
                  selected:
                      controller.tab.value == ShellController.transactionsTab,
                  onTap: () =>
                      controller.tab.value = ShellController.transactionsTab,
                ),
              ),
              const SizedBox(width: 72),
              Expanded(
                child: _NavItem(
                  icon: Icons.track_changes_outlined,
                  selectedIcon: Icons.track_changes,
                  label: l10n.tabPlan,
                  selected: controller.tab.value == ShellController.planTab,
                  onTap: () => controller.tab.value = ShellController.planTab,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.bar_chart_outlined,
                  selectedIcon: Icons.bar_chart,
                  label: l10n.tabReports,
                  selected: controller.tab.value == ShellController.reportsTab,
                  onTap: () =>
                      controller.tab.value = ShellController.reportsTab,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, color: color),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
