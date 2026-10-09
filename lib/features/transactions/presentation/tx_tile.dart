import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../core/ui/date_labels.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/transaction_repository.dart';

class TxTile extends StatelessWidget {
  const TxTile({
    super.key,
    required this.item,
    this.onTap,
    this.showDate = false,
    this.extra = '',
  });

  final TxWithCategory item;
  final VoidCallback? onTap;
  final bool showDate;

  /// Wallet and tags, shown under the title.
  final String extra;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tx = item.tx;
    final isIncome = tx.type == 'income';
    final color = colorForCategory(item.category?.id ?? 'none');
    final categoryName = categoryDisplayName(l10n, item.category);
    final hasNote = tx.note.isNotEmpty;

    final subtitleParts = <String>[
      if (hasNote) categoryName,
      if (showDate) dayLabel(l10n, tx.occurredOn),
      if (extra.isNotEmpty) extra,
    ];

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(iconFor(item.category?.icon ?? ''), color: color, size: 22),
      ),
      title: Text(
        hasNote ? tx.note : categoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: Text(
        '${isIncome ? '+' : '-'}${Money.format(tx.amountMinor, tx.currency)}',
        style: theme.textTheme.titleSmall?.copyWith(
          color: isIncome ? theme.colorScheme.primary : null,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
