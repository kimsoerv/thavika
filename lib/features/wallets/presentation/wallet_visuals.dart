import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

const walletKinds = ['cash', 'bank', 'ewallet', 'other'];

IconData walletIcon(String kind) {
  switch (kind) {
    case 'cash':
      return Icons.payments_outlined;
    case 'bank':
      return Icons.account_balance_outlined;
    case 'ewallet':
      return Icons.smartphone;
    default:
      return Icons.account_balance_wallet_outlined;
  }
}

String walletKindLabel(AppLocalizations l10n, String kind) {
  switch (kind) {
    case 'cash':
      return l10n.walletKindCash;
    case 'bank':
      return l10n.walletKindBank;
    case 'ewallet':
      return l10n.walletKindEwallet;
    default:
      return l10n.walletKindOther;
  }
}
