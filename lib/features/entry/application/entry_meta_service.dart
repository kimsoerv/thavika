import 'dart:async';

import 'package:get/get.dart';

import '../../../core/db/app_database.dart';
import '../../tags/data/tag_repository.dart';
import '../../wallets/data/wallet_repository.dart';

/// Wallets and tags, kept in memory so any screen can show an entry's wallet
/// and tags without its own database query.
class EntryMetaService extends GetxService {
  EntryMetaService(this._wallets, this._tags);

  final WalletRepository _wallets;
  final TagRepository _tags;

  final wallets = <WalletRow>[].obs;
  final balances = <String, int>{}.obs;
  final tags = <TagRow>[].obs;

  /// Entry id -> ids of its tags.
  final tagLinks = <String, List<String>>{}.obs;

  final _subs = <StreamSubscription<Object?>>[];

  Future<EntryMetaService> init() async {
    _subs.addAll([
      _wallets.watchAll().listen(wallets.assignAll),
      _wallets.watchBalances().listen((b) {
        balances
          ..clear()
          ..addAll(b);
      }),
      _tags.watchAll().listen(tags.assignAll),
      _tags.watchLinks().listen((m) {
        tagLinks
          ..clear()
          ..addAll(m);
      }),
    ]);
    return this;
  }

  WalletRow? walletById(String? id) =>
      id == null ? null : wallets.firstWhereOrNull((w) => w.id == id);

  TagRow? tagById(String id) => tags.firstWhereOrNull((t) => t.id == id);

  Set<String> tagIdsFor(String entryId) => {...?tagLinks[entryId]};

  /// "#trip #wedding" (without deleted tags), or an empty string.
  String tagLabel(String entryId) {
    final names = [
      for (final id in tagLinks[entryId] ?? const <String>[])
        if (tagById(id) != null) '#${tagById(id)!.name}',
    ];
    return names.join(' ');
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }
}
