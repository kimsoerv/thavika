import 'package:get/get.dart';

import '../../goals/data/goal_repository.dart';
import '../../goals/presentation/goals_controller.dart';
import '../../home/presentation/home_controller.dart';
import '../../plan/presentation/plan_controller.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../transactions/presentation/transactions_controller.dart';

class ShellController extends GetxController {
  static const homeTab = 0;
  static const transactionsTab = 1;
  static const planTab = 2;
  static const reportsTab = 3;

  final tab = homeTab.obs;
}

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ShellController());
    Get.lazyPut(() => HomeController(Get.find(), Get.find(), Get.find()));
    Get.lazyPut(() => TransactionsController(Get.find(), Get.find()));
    Get.lazyPut(
      () => PlanController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
      ),
    );
    Get.lazyPut(() => GoalsController(Get.find<GoalRepository>()));
    Get.lazyPut(
      () => ReportsController(Get.find(), Get.find(), Get.find(), Get.find()),
    );
  }
}
