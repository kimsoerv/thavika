import 'package:flutter/material.dart';

import '../../../core/ui/category_visuals.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/plan_check.dart';

String groupLabel(AppLocalizations l10n, String group) {
  switch (group) {
    case 'needs':
      return l10n.groupNeeds;
    case 'wants':
      return l10n.groupWants;
    case 'savings':
      return l10n.groupSavings;
    case 'giving':
      return l10n.groupGiving;
    case 'spending':
      return l10n.groupSpending;
    default:
      return group;
  }
}

Color groupColor(String group) {
  switch (group) {
    case 'needs':
    case 'spending':
      return const Color(0xFF185FA5);
    case 'wants':
      return const Color(0xFFBA7517);
    case 'savings':
      return const Color(0xFF0F6E56);
    case 'giving':
      return const Color(0xFF534AB7);
    default:
      return const Color(0xFF5F5E5A);
  }
}

/// Name shown for a plan line. Built-in lines store a key, custom lines
/// store the text the user typed.
String planItemLabel(AppLocalizations l10n, String name) {
  switch (name) {
    case 'emergency_fund':
      return l10n.itemEmergencyFund;
    case 'goals':
      return l10n.itemGoals;
    case 'giving':
      return l10n.itemGiving;
    case 'debt_payment':
      return l10n.itemDebtPayment;
  }
  if (name.startsWith('cat_')) return categoryNameFor(l10n, name, name);
  return name;
}

String templateName(AppLocalizations l10n, String id) {
  switch (id) {
    case 'balanced':
      return l10n.tplBalanced;
    case 'seventy':
      return l10n.tplSeventy;
    case 'eighty':
      return l10n.tplEighty;
    default:
      return l10n.tplCustom;
  }
}

String templateHint(AppLocalizations l10n, String id) {
  switch (id) {
    case 'balanced':
      return l10n.tplBalancedHint;
    case 'seventy':
      return l10n.tplSeventyHint;
    case 'eighty':
      return l10n.tplEightyHint;
    default:
      return l10n.tplCustomHint;
  }
}

Color paceColor(PaceStatus status, ColorScheme scheme) {
  switch (status) {
    case PaceStatus.onTrack:
      return const Color(0xFF2E7D32);
    case PaceStatus.slightlyAhead:
      return const Color(0xFFB26A00);
    case PaceStatus.offTrack:
    case PaceStatus.over:
      return scheme.error;
  }
}

String paceLabel(AppLocalizations l10n, PaceStatus status) {
  switch (status) {
    case PaceStatus.onTrack:
      return l10n.checkOnTrack;
    case PaceStatus.slightlyAhead:
      return l10n.checkSlightlyAhead;
    case PaceStatus.offTrack:
      return l10n.checkOffTrack;
    case PaceStatus.over:
      return l10n.checkOver;
  }
}
