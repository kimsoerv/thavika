import 'dart:async';

import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../data/goal_repository.dart';

class GoalDetailController extends GetxController {
  GoalDetailController(this._repo);

  final GoalRepository _repo;

  late final String goalId = Get.arguments as String;

  final goal = Rxn<GoalWithSaved>();
  final contributions = <GoalContributionRow>[].obs;

  StreamSubscription<List<GoalWithSaved>>? _goalSub;
  StreamSubscription<List<GoalContributionRow>>? _contribSub;

  @override
  void onInit() {
    super.onInit();
    _goalSub = _repo.watchGoals().listen((all) {
      goal.value = all.firstWhereOrNull((g) => g.goal.id == goalId);
    });
    _contribSub = _repo
        .watchContributions(goalId)
        .listen(contributions.assignAll);
  }

  Future<void> addMoney(int amountMinor) {
    return _repo.addContribution(
      goalId: goalId,
      amountMinor: amountMinor,
      date: DateTime.now(),
    );
  }

  /// Removes the entry from the list at once, then deletes it.
  Future<void> removeContribution(String id) async {
    contributions.removeWhere((c) => c.id == id);
    await _repo.deleteContribution(id);
  }

  Future<void> restoreContribution(String id) => _repo.restoreContribution(id);

  Future<void> deleteGoal() => _repo.deleteGoal(goalId);

  @override
  void onClose() {
    _goalSub?.cancel();
    _contribSub?.cancel();
    super.onClose();
  }
}
