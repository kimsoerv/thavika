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
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 3,
        shadowColor: Colors.black54,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 80,
            child: Obx(
              () => Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: l10n.tabHome,
                      selected: controller.tab.value == ShellController.homeTab,
                      onTap: () =>
                          controller.tab.value = ShellController.homeTab,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.receipt_long_outlined,
                      selectedIcon: Icons.receipt_long,
                      label: l10n.tabTransactions,
                      selected:
                          controller.tab.value ==
                          ShellController.transactionsTab,
                      onTap: () => controller.tab.value =
                          ShellController.transactionsTab,
                    ),
                  ),
                  // Add sits in the same place on every tab.
                  SizedBox(
                    width: 80,
                    child: Center(
                      child: FloatingActionButton(
                        heroTag: null,
                        tooltip: l10n.addTitle,
                        elevation: 2,
                        highlightElevation: 4,
                        shape: const CircleBorder(),
                        onPressed: () => _add(context),
                        child: const Icon(Icons.add, size: 28),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.track_changes_outlined,
                      selectedIcon: Icons.track_changes,
                      label: l10n.tabPlan,
                      selected: controller.tab.value == ShellController.planTab,
                      onTap: () =>
                          controller.tab.value = ShellController.planTab,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.bar_chart_outlined,
                      selectedIcon: Icons.bar_chart,
                      label: l10n.tabReports,
                      selected:
                          controller.tab.value == ShellController.reportsTab,
                      onTap: () =>
                          controller.tab.value = ShellController.reportsTab,
                    ),
                  ),
                ],
              ),
            ),
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
    final scheme = theme.colorScheme;
    final color = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      // The whole tab is tappable; only the round pill shows the ripple.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              color: selected ? scheme.secondaryContainer : Colors.transparent,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              animationDuration: const Duration(milliseconds: 200),
              child: InkWell(
                onTap: onTap,
                customBorder: const StadiumBorder(),
                child: SizedBox(
                  width: 64,
                  height: 32,
                  child: Icon(selected ? selectedIcon : icon, color: color),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
