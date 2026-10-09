import 'dart:async';

import 'package:get/get.dart';

import '../data/goal_repository.dart';

/// The list of goals shown in the Plan tab.
class GoalsController extends GetxController {
  GoalsController(this._repo);

  final GoalRepository _repo;

  final goals = <GoalWithSaved>[].obs;
  StreamSubscription<List<GoalWithSaved>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _repo.watchGoals().listen(goals.assignAll);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
