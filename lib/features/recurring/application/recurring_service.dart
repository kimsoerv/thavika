import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../data/recurring_repository.dart';

/// Creates the entries of recurring rules when the app starts and each time
/// it comes back to the front (a new day may have started).
class RecurringService extends GetxService with WidgetsBindingObserver {
  RecurringService(this._repo);

  final RecurringRepository _repo;

  Future<RecurringService> init() async {
    await generateDue();
    WidgetsBinding.instance.addObserver(this);
    return this;
  }

  Future<int> generateDue() => _repo.generateDue(DateTime.now());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) generateDue();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
