import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../application/sync_service.dart';

/// A small cloud on the home screen: saved, waiting, offline or a problem.
/// Not shown to guests.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = Get.find<SyncService>();
    final theme = Theme.of(context);
    return Obx(() {
      final state = sync.state.value;
      if (state == SyncState.off || state == SyncState.signedOut) {
        return const SizedBox.shrink();
      }
      final IconData icon;
      Color color = theme.colorScheme.onSurfaceVariant;
      switch (state) {
        case SyncState.syncing:
          icon = Icons.sync;
        case SyncState.offline:
          icon = Icons.cloud_off_outlined;
        case SyncState.error:
          icon = Icons.sync_problem_outlined;
          color = theme.colorScheme.error;
        default:
          icon = sync.pending.value > 0
              ? Icons.cloud_upload_outlined
              : Icons.cloud_done_outlined;
      }
      return IconButton(
        icon: Icon(icon, color: color),
        onPressed: () => Get.toNamed(Routes.account),
      );
    });
  }
}
