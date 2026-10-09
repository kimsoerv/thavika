import '../../../core/money/money.dart';

/// A category the typed line can be matched against.
class CategoryHint {
  const CategoryHint({
    required this.id,
    required this.name,
    required this.isIncome,
  });

  final String id;

  /// The name as the user sees it.
  final String name;
  final bool isIncome;
}

/// What was understood from a typed line such as "coffee 2.5".
class QuickLine {
  const QuickLine({
    this.amountMinor,
    required this.note,
    this.isIncome = false,
    this.categoryId,
  });

  /// Null when the line had no amount.
  final int? amountMinor;
  final String note;
  final bool isIncome;
  final String? categoryId;
}

const _incomeWords = {
  'salary',
  'income',
  'bonus',
  'wage',
  'wages',
  'refund',
  'earned',
  'received',
};

const _symbols = r'$៛€£¥฿₫₩';

/// Understands "coffee 2.5", "rent $400", "+salary 2000", "1,000 school".
///
/// The last number is the amount, the other words are the note. A leading
/// "+" or a word like "salary" makes it income. The category comes from a
/// note used before ([knownNotes], lower-case note to category id) or from a
/// category name written in the line.
QuickLine parseQuickLine(
  String text, {
  required String currency,
  List<CategoryHint> categories = const [],
  Map<String, String> knownNotes = const {},
}) {
  final tokens = text.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  final words = tokens.toList();
  if (words.isEmpty) return const QuickLine(note: '');

  var income = words.first.startsWith('+');

  int? amount;
  var amountIndex = -1;
  for (var i = words.length - 1; i >= 0; i--) {
    final minor = _parseAmount(words[i], currency);
    if (minor != null) {
      amount = minor;
      amountIndex = i;
      break;
    }
  }

  final noteWords = <String>[];
  for (var i = 0; i < words.length; i++) {
    if (i == amountIndex) continue;
    var w = words[i];
    if (i == 0 && w.startsWith('+')) w = w.substring(1);
    if (w.isEmpty) continue;
    noteWords.add(w);
  }
  final note = noteWords.join(' ');
  final lower = note.toLowerCase();

  if (noteWords.any((w) => _incomeWords.contains(w.toLowerCase()))) {
    income = true;
  }

  String? categoryId;
  final known = knownNotes[lower];
  if (known != null) {
    categoryId = known;
  } else if (lower.isNotEmpty) {
    // The longest category name that appears as a whole word wins.
    var bestLength = 0;
    final padded =
        ' ${lower.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')} ';
    for (final c in categories) {
      if (c.isIncome != income) continue;
      final name = c.name.toLowerCase().trim();
      if (name.isEmpty) continue;
      if (padded.contains(' $name ') && name.length > bestLength) {
        bestLength = name.length;
        categoryId = c.id;
      }
    }
  }

  return QuickLine(
    amountMinor: amount,
    note: note,
    isIncome: income,
    categoryId: categoryId,
  );
}

/// "2.5", "$2.5", "2.5$", "1,000", "2,5" -> minor units. Null if not a number.
int? _parseAmount(String token, String currency) {
  var t = token;
  for (final s in _symbols.split('')) {
    t = t.replaceAll(s, '');
  }
  if (t.startsWith('+') || t.startsWith('-')) t = t.substring(1);
  if (t.isEmpty || !RegExp(r'^\d[\d.,]*$').hasMatch(t)) return null;

  if (t.contains('.') && t.contains(',')) {
    t = t.replaceAll(',', '');
  } else if (t.contains(',')) {
    // "1,000" is a thousand; "2,5" is two and a half.
    t = RegExp(r',\d{3}$').hasMatch(t)
        ? t.replaceAll(',', '')
        : t.replaceAll(',', '.');
  }
  if ('.'.allMatches(t).length > 1) return null;

  final minor = Money.parseMinor(t, currency);
  return minor > 0 ? minor : null;
}
