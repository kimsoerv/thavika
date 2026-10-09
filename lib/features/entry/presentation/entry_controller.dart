import 'dart:async';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:get/get.dart' hide Value;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../../receipts/receipt_service.dart';
import '../../tags/data/tag_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../application/entry_meta_service.dart';
import '../application/voice_input.dart';
import '../data/category_repository.dart';
import '../domain/quick_line.dart';

enum EntryError {
  amountRequired,
  categoryRequired,
  splitNeedAmount,
  splitIncomplete,
  splitMismatch,
}

/// One part of a purchase that is split between categories.
class SplitPart {
  SplitPart({String? category}) {
    categoryId.value = category;
  }

  final categoryId = RxnString();
  final amountCtrl = TextEditingController();
  final minor = 0.obs;

  void dispose() => amountCtrl.dispose();
}

class EntryController extends GetxController {
  EntryController(
    this._transactions,
    this._categories,
    this._settings,
    this._tagRepo,
    this.meta,
    this._receipts,
    this._voice,
  );

  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  final SettingsService _settings;
  final TagRepository _tagRepo;
  final EntryMetaService meta;
  final ReceiptService _receipts;
  final VoiceInput _voice;

  static const _lastWalletKey = 'last_wallet_id';

  /// Set when an existing entry is being edited.
  TxWithCategory? editing;

  final type = 'expense'.obs;
  final amountText = ''.obs;
  final categoryId = RxnString();
  final date = DateTime.now().obs;
  final categories = <CategoryRow>[].obs;
  final allCategories = <CategoryRow>[].obs;
  final error = Rxn<EntryError>();
  final saving = false.obs;
  final noteCtrl = TextEditingController();
  final quickCtrl = TextEditingController();

  final walletId = RxnString();
  final tagIds = <String>{}.obs;
  final receipt = RxnString();
  final splitMode = false.obs;
  final splits = <SplitPart>[].obs;
  final suggestions = <NoteSuggestion>[].obs;
  final recents = <TxRow>[].obs;

  /// The typed line and repeat chips, opened with the bolt button.
  final showQuick = false.obs;

  /// True while the microphone is open, and after a failed start.
  final listening = false.obs;
  final voiceUnavailable = false.obs;

  StreamSubscription<List<CategoryRow>>? _catSub;
  StreamSubscription<List<CategoryRow>>? _allSub;
  Timer? _suggestTimer;
  String? _originalReceipt;
  var _saved = false;
  var _usage = <String, int>{};
  final _known = <String, Map<String, String>>{};

  bool get isEditing => editing != null;
  String get currency => editing?.tx.currency ?? _settings.currency.value;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is TxWithCategory) {
      editing = args;
      final tx = args.tx;
      type.value = tx.type;
      amountText.value = Money.toInputText(tx.amountMinor, tx.currency);
      categoryId.value = tx.categoryId;
      date.value = tx.occurredOn;
      noteCtrl.text = tx.note;
      walletId.value = tx.walletId;
      receipt.value = tx.receiptPath;
      _originalReceipt = tx.receiptPath;
      tagIds.addAll(meta.tagIdsFor(tx.id));
    } else {
      _initWallet();
      _loadRecents();
    }
    _listenCategories();
    _allSub = _categories.watchAllVisible().listen(allCategories.assignAll);
    _loadKnown();
    noteCtrl.addListener(_scheduleSuggest);
  }

  Future<void> _initWallet() async {
    final saved = await _settings.getString(_lastWalletKey);
    final usable = meta.wallets.any((w) => w.id == saved);
    walletId.value = usable
        ? saved
        : (meta.wallets.isEmpty ? null : meta.wallets.first.id);
  }

  Future<void> _loadKnown() async {
    for (final kind in const ['expense', 'income']) {
      _known[kind] = await _transactions.knownNotes(kind);
    }
  }

  Future<void> _loadRecents() async {
    final kind = type.value;
    final list = await _transactions.recentDistinct(kind);
    if (kind == type.value) recents.assignAll(list);
  }

  void _listenCategories() {
    _catSub?.cancel();
    final kind = type.value;
    _transactions.categoryUsage(kind).then((usage) {
      if (kind == type.value) {
        _usage = usage;
        categories.assignAll(_byUsage(categories));
      }
    });
    _catSub = _categories
        .watch(kind)
        .listen((list) => categories.assignAll(_byUsage(list)));
  }

  List<CategoryRow> _byUsage(Iterable<CategoryRow> list) {
    final indexed = list.toList();
    final order = {for (var i = 0; i < indexed.length; i++) indexed[i].id: i};
    indexed.sort((a, b) {
      final byUse = (_usage[b.id] ?? 0).compareTo(_usage[a.id] ?? 0);
      return byUse != 0 ? byUse : order[a.id]!.compareTo(order[b.id]!);
    });
    return indexed;
  }

  void setType(String value) {
    if (type.value == value) return;
    type.value = value;
    categoryId.value = null;
    error.value = null;
    suggestions.clear();
    _listenCategories();
    if (!isEditing) _loadRecents();
  }

  void selectCategory(String id) {
    categoryId.value = id;
    if (error.value == EntryError.categoryRequired) error.value = null;
    _scheduleSuggest();
  }

  void setDate(DateTime value) => date.value = value;

  void setWallet(String id) => walletId.value = id;

  // ---- amount keypad

  /// Keypad input: digits, '.', or 'back'.
  void press(String key) {
    final decimals = Money.decimalsFor(currency);
    var text = amountText.value;
    if (key == 'back') {
      if (text.isNotEmpty) text = text.substring(0, text.length - 1);
    } else if (key == 'clear') {
      text = '';
    } else if (key == '.') {
      if (decimals == 0 || text.contains('.')) return;
      text = text.isEmpty ? '0.' : '$text.';
    } else {
      final dot = text.indexOf('.');
      if (dot == -1) {
        if (text.length >= 9) return;
        text = text == '0' ? key : '$text$key';
      } else {
        if (text.length - dot - 1 >= decimals) return;
        text = '$text$key';
      }
    }
    amountText.value = text;
    if (error.value == EntryError.amountRequired ||
        error.value == EntryError.splitNeedAmount ||
        error.value == EntryError.splitMismatch) {
      error.value = null;
    }
  }

  // ---- categories

  Future<String> addCategory(String name, String icon) async {
    final id = await _categories.add(name: name, icon: icon, kind: type.value);
    categoryId.value = id;
    return id;
  }

  // ---- tags

  void toggleTag(String id) {
    if (!tagIds.remove(id)) tagIds.add(id);
  }

  Future<void> createTag(String name) async {
    final id = await _tagRepo.add(name.trim());
    tagIds.add(id);
  }

  // ---- receipt

  Future<void> pickReceipt(ImageSource source) async {
    final name = await _receipts.pick(source);
    if (name == null) return;
    _dropUnsavedReceipt();
    receipt.value = name;
  }

  void removeReceipt() {
    _dropUnsavedReceipt();
    receipt.value = null;
  }

  /// A photo taken in this screen and replaced before saving is deleted.
  void _dropUnsavedReceipt() {
    final current = receipt.value;
    if (current != null && current != _originalReceipt) {
      _receipts.delete(current);
    }
  }

  // ---- split

  int get splitAssigned => splits.fold(0, (sum, p) => sum + p.minor.value);
  int get total => Money.parseMinor(amountText.value, currency);

  void toggleSplit() {
    if (splitMode.value) {
      splitMode.value = false;
      for (final p in splits) {
        p.dispose();
      }
      splits.clear();
    } else {
      splitMode.value = true;
      splits.assignAll([SplitPart(category: categoryId.value), SplitPart()]);
    }
    if (error.value == EntryError.splitIncomplete ||
        error.value == EntryError.splitMismatch) {
      error.value = null;
    }
  }

  void addPart() => splits.add(SplitPart());

  void removePart(SplitPart part) {
    if (splits.length <= 2) return;
    splits.remove(part);
    part.dispose();
  }

  void setPartAmount(SplitPart part, String text) {
    part.minor.value = Money.parseMinor(text, currency);
    if (error.value == EntryError.splitMismatch ||
        error.value == EntryError.splitIncomplete) {
      error.value = null;
    }
  }

  // ---- typed line, suggestions, repeat

  /// Fills the form from a line such as "coffee 2.5".
  void applyQuickLine(List<CategoryHint> hints) {
    final text = quickCtrl.text.trim();
    if (text.isEmpty) return;
    final first = parseQuickLine(
      text,
      currency: currency,
      categories: hints,
      knownNotes: _known[type.value] ?? const {},
    );
    if (first.isIncome != (type.value == 'income')) {
      setType(first.isIncome ? 'income' : 'expense');
    }
    final parsed = first.isIncome == (type.value == 'income')
        ? parseQuickLine(
            text,
            currency: currency,
            categories: hints,
            knownNotes: _known[type.value] ?? const {},
          )
        : first;
    if (parsed.amountMinor != null) {
      amountText.value = Money.toInputText(parsed.amountMinor!, currency);
      error.value = null;
    }
    noteCtrl.text = parsed.note;
    if (parsed.categoryId != null) selectCategory(parsed.categoryId!);
    quickCtrl.clear();
  }

  void _scheduleSuggest() {
    _suggestTimer?.cancel();
    _suggestTimer = Timer(const Duration(milliseconds: 200), _suggest);
  }

  Future<void> _suggest() async {
    final prefix = noteCtrl.text.trim();
    final category = categoryId.value;
    if (prefix.isEmpty && category == null) {
      suggestions.clear();
      return;
    }
    final list = await _transactions.suggestNotes(
      type: type.value,
      prefix: prefix,
      categoryId: category,
      limit: 4,
    );
    suggestions.assignAll(
      list.where((s) => s.note.toLowerCase() != prefix.toLowerCase()),
    );
  }

  void useSuggestion(NoteSuggestion s) {
    noteCtrl.text = s.note;
    noteCtrl.selection = TextSelection.collapsed(offset: s.note.length);
    categoryId.value ??= s.categoryId;
    suggestions.clear();
  }

  /// Fills the form from an earlier entry.
  void useRecent(TxRow r) {
    amountText.value = Money.toInputText(r.amountMinor, r.currency);
    categoryId.value = r.categoryId;
    noteCtrl.text = r.note;
    if (r.walletId != null && meta.walletById(r.walletId) != null) {
      walletId.value = r.walletId;
    }
    tagIds
      ..clear()
      ..addAll(meta.tagIdsFor(r.id));
    error.value = null;
  }

  // ---- voice

  /// Starts or stops speaking an entry ("coffee two and a half").
  Future<void> toggleVoice(List<CategoryHint> hints, {String? localeId}) async {
    if (listening.value) {
      await _voice.stop();
      listening.value = false;
      return;
    }
    voiceUnavailable.value = false;
    final ok = await _voice.start((text, isFinal) {
      quickCtrl.text = text;
      quickCtrl.selection = TextSelection.collapsed(offset: text.length);
      if (isFinal) {
        listening.value = false;
        applyQuickLine(hints);
      }
    }, localeId: localeId);
    if (ok) {
      listening.value = true;
    } else {
      voiceUnavailable.value = true;
    }
  }

  // ---- save

  /// Saves the entry (or all parts of a split). Returns the id of the first
  /// entry saved, or null when something is missing.
  Future<String?> save() async {
    if (saving.value) return null;
    final minor = total;
    if (minor <= 0) {
      error.value = splitMode.value
          ? EntryError.splitNeedAmount
          : EntryError.amountRequired;
      return null;
    }
    final note = noteCtrl.text.trim();
    final day = DateTime(date.value.year, date.value.month, date.value.day);
    final wallet = walletId.value;

    if (splitMode.value && !isEditing) {
      final incomplete =
          splits.length < 2 ||
          splits.any((p) => p.categoryId.value == null || p.minor.value <= 0);
      if (incomplete) {
        error.value = EntryError.splitIncomplete;
        return null;
      }
      if (splitAssigned != minor) {
        error.value = EntryError.splitMismatch;
        return null;
      }
      saving.value = true;
      try {
        final group = const Uuid().v4();
        String? first;
        for (var i = 0; i < splits.length; i++) {
          final p = splits[i];
          final id = await _transactions.add(
            type: type.value,
            amountMinor: p.minor.value,
            currency: currency,
            categoryId: p.categoryId.value!,
            note: note,
            date: day,
            walletId: wallet,
            receiptPath: i == 0 ? receipt.value : null,
            splitGroup: group,
            tagIds: tagIds.toSet(),
          );
          first ??= id;
        }
        await _afterSave(wallet);
        return first;
      } finally {
        saving.value = false;
      }
    }

    final cat = categoryId.value;
    if (cat == null) {
      error.value = EntryError.categoryRequired;
      return null;
    }
    saving.value = true;
    try {
      final existing = editing;
      final String id;
      if (existing != null) {
        await _transactions.update(
          existing.tx.id,
          type: type.value,
          amountMinor: minor,
          currency: currency,
          categoryId: cat,
          note: note,
          date: day,
          walletId: wallet,
          receiptPath: Value<String?>(receipt.value),
          tagIds: tagIds.toSet(),
        );
        id = existing.tx.id;
        final old = _originalReceipt;
        if (old != null && old != receipt.value) await _receipts.delete(old);
      } else {
        id = await _transactions.add(
          type: type.value,
          amountMinor: minor,
          currency: currency,
          categoryId: cat,
          note: note,
          date: day,
          walletId: wallet,
          receiptPath: receipt.value,
          tagIds: tagIds.toSet(),
        );
      }
      await _afterSave(wallet);
      return id;
    } finally {
      saving.value = false;
    }
  }

  Future<void> _afterSave(String? wallet) async {
    _saved = true;
    if (wallet != null) await _settings.setString(_lastWalletKey, wallet);
  }

  @override
  void onClose() {
    if (listening.value) _voice.stop();
    // A photo taken here but never saved is not kept.
    if (!_saved) _dropUnsavedReceipt();
    _suggestTimer?.cancel();
    _catSub?.cancel();
    _allSub?.cancel();
    noteCtrl
      ..removeListener(_scheduleSuggest)
      ..dispose();
    quickCtrl.dispose();
    for (final p in splits) {
      p.dispose();
    }
    super.onClose();
  }
}
