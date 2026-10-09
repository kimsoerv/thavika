import 'package:get/get.dart';

import '../../../core/services/settings_service.dart';
import '../../entry/data/category_repository.dart';
import '../../goals/data/goal_repository.dart';
import '../application/reminder_service.dart';
import '../data/plan_repository.dart';
import 'plan_setup_controller.dart';

class PlanSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlanSetupController>(
      () => PlanSetupController(
        Get.find<PlanRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<SettingsService>(),
        Get.find<ReminderService>(),
        Get.find<GoalRepository>(),
      ),
    );
  }
}
