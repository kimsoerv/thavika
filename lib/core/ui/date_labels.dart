import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Yesterday", or a short date such as "Mon, Oct 5".
String dayLabel(AppLocalizations l10n, DateTime date) {
  final today = dateOnly(DateTime.now());
  final d = dateOnly(date);
  final diff = today.difference(d).inDays;
  if (diff == 0) return l10n.today;
  if (diff == 1) return l10n.yesterday;
  return DateFormat.MMMEd().format(d);
}
