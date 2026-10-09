import 'dart:async';

import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../entry/application/entry_meta_service.dart';
import '../data/transfer_repository.dart';
import '../data/wallet_repository.dart';

class WalletsController extends GetxController {
  WalletsController(this._wallets, this._transfers, this.meta, this.settings);

  final WalletRepository _wallets;
  final TransferRepository _transfers;
  final EntryMetaService meta;
  final SettingsService settings;

  /// Includes hidden (archived) wallets.
  final all = <WalletRow>[].obs;
  final transfers = <TransferRow>[].obs;

  final _subs = <StreamSubscription<Object?>>[];

  String get currency => settings.currency.value;

  @override
  void onInit() {
    super.onInit();
    _subs.addAll([
      _wallets.watchAll(includeArchived: true).listen(all.assignAll),
      _transfers.watchRecent().listen(transfers.assignAll),
    ]);
  }

  /// Money in the wallets that are not hidden.
  int get total => all
      .where((w) => !w.isArchived)
      .fold(0, (sum, w) => sum + (meta.balances[w.id] ?? 0));

  String walletName(String id) =>
      all.firstWhereOrNull((w) => w.id == id)?.name ?? '';

  /// Removes the transfer from the list at once, then deletes it.
  Future<void> deleteTransfer(String id) async {
    transfers.removeWhere((t) => t.id == id);
    await _transfers.softDelete(id);
  }

  Future<void> restoreTransfer(String id) => _transfers.restore(id);

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }
}
