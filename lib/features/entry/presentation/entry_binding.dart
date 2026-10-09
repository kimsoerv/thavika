import 'package:get/get.dart';

import '../../../core/services/settings_service.dart';
import '../../receipts/receipt_service.dart';
import '../../tags/data/tag_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../application/entry_meta_service.dart';
import '../application/voice_input.dart';
import '../data/category_repository.dart';
import 'entry_controller.dart';

class EntryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EntryController>(
      () => EntryController(
        Get.find<TransactionRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<SettingsService>(),
        Get.find<TagRepository>(),
        Get.find<EntryMetaService>(),
        Get.find<ReceiptService>(),
        SpeechVoiceInput(),
      ),
    );
  }
}
