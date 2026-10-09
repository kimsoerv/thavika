import 'dart:async';

import 'package:get/get.dart';

import '../../../core/money/money.dart';
import '../../entry/application/entry_meta_service.dart';
import '../data/transaction_repository.dart';

class TransactionsController extends GetxController {
  TransactionsController(this._repo, this.meta);

  final TransactionRepository _repo;
  final EntryMetaService meta;

  final items = <TxWithCategory>[].obs;
  final month = DateTime(DateTime.now().year, DateTime.now().month).obs;
  final query = ''.obs;

  /// 'all', 'expense' or 'income'
  final typeFilter = 'all'.obs;

  /// Show only entries of one wallet or one tag (null = all).
  final walletFilter = RxnString();
  final tagFilter = RxnString();

  StreamSubscription<List<TxWithCategory>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _listen();
    ever(month, (_) => _listen());
  }

  void _listen() {
    _sub?.cancel();
    final from = month.value;
    final to = DateTime(from.year, from.month + 1);
    _sub = _repo.watchRange(from, to).listen(items.assignAll);
  }

  void shiftMonth(int delta) {
    month.value = DateTime(month.value.year, month.value.month + delta);
  }

  List<TxWithCategory> get filtered {
    final q = query.value.trim().toLowerCase();
    final type = typeFilter.value;
    final wallet = walletFilter.value;
    final tag = tagFilter.value;
    // Reading the links makes the list refresh when tags change.
    final links = meta.tagLinks;
    return items.where((e) {
      if (type != 'all' && e.tx.type != type) return false;
      if (wallet != null && e.tx.walletId != wallet) return false;
      if (tag != null && !(links[e.tx.id]?.contains(tag) ?? false)) {
        return false;
      }
      if (q.isEmpty) return true;
      final digits = q.replaceAll(RegExp(r'[^0-9.]'), '');
      final amount = Money.toInputText(e.tx.amountMinor, e.tx.currency);
      return e.tx.note.toLowerCase().contains(q) ||
          (e.category?.name.toLowerCase().contains(q) ?? false) ||
          meta.tagLabel(e.tx.id).toLowerCase().contains(q) ||
          (digits.isNotEmpty && amount.contains(digits));
    }).toList();
  }

  /// Wallet (when there is more than one) and tags, for the tile.
  String extraFor(TxWithCategory e) {
    final parts = <String>[];
    if (meta.wallets.length > 1) {
      final name = meta.walletById(e.tx.walletId)?.name;
      if (name != null) parts.add(name);
    }
    final tags = meta.tagLabel(e.tx.id);
    if (tags.isNotEmpty) parts.add(tags);
    return parts.join(' · ');
  }

  /// Copies the entry to today. Returns the new entry's id.
  Future<String> duplicate(String id) => _repo.duplicate(id);

  /// Removes the entry from the list at once (so a swipe feels instant),
  /// then deletes it in the database.
  Future<void> delete(String id) async {
    items.removeWhere((e) => e.tx.id == id);
    await _repo.softDelete(id);
  }

  Future<void> restore(String id) => _repo.restore(id);

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
