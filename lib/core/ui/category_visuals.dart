import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../db/app_database.dart';

const Map<String, IconData> categoryIcons = {
  'home': Icons.home,
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'receipt_long': Icons.receipt_long,
  'favorite': Icons.favorite,
  'people': Icons.people,
  'shopping_cart': Icons.shopping_cart,
  'movie': Icons.movie,
  'spa': Icons.spa,
  'more_horiz': Icons.more_horiz,
  'payments': Icons.payments,
  'card_giftcard': Icons.card_giftcard,
  'add_circle': Icons.add_circle,
  'coffee': Icons.coffee,
  'pets': Icons.pets,
  'school': Icons.school,
  'fitness_center': Icons.fitness_center,
  'phone_android': Icons.phone_android,
  'directions_car': Icons.directions_car,
  'flight': Icons.flight,
  'savings': Icons.savings,
  'work': Icons.work,
  'child_care': Icons.child_care,
  'build': Icons.build,
  'local_gas_station': Icons.local_gas_station,
  'wifi': Icons.wifi,
};

/// Icons a user can pick when creating their own category.
const List<String> customIconKeys = [
  'coffee',
  'pets',
  'school',
  'card_giftcard',
  'fitness_center',
  'phone_android',
  'directions_car',
  'flight',
  'savings',
  'work',
  'child_care',
  'build',
  'local_gas_station',
  'wifi',
];

IconData iconFor(String key) => categoryIcons[key] ?? Icons.category;

const _palette = <Color>[
  Color(0xFF0F6E56),
  Color(0xFF185FA5),
  Color(0xFFBA7517),
  Color(0xFF993556),
  Color(0xFF534AB7),
  Color(0xFF993C1D),
  Color(0xFF3B6D11),
  Color(0xFF5F5E5A),
];

/// Stable colour per category id (same on every device and every run).
Color colorForCategory(String id) {
  var sum = 0;
  for (final unit in id.codeUnits) {
    sum += unit;
  }
  return _palette[sum % _palette.length];
}

/// Default categories are translated; custom ones show the name the user typed.
String categoryDisplayName(AppLocalizations l10n, CategoryRow? category) {
  if (category == null) return l10n.uncategorized;
  return categoryNameFor(l10n, category.id, category.name);
}

/// Same as [categoryDisplayName] when only the id and a fallback name are known.
String categoryNameFor(AppLocalizations l10n, String id, String fallback) {
  switch (id) {
    case 'cat_housing':
      return l10n.catHousing;
    case 'cat_food':
      return l10n.catFood;
    case 'cat_transport':
      return l10n.catTransport;
    case 'cat_bills':
      return l10n.catBills;
    case 'cat_health':
      return l10n.catHealth;
    case 'cat_family':
      return l10n.catFamily;
    case 'cat_shopping':
      return l10n.catShopping;
    case 'cat_fun':
      return l10n.catFun;
    case 'cat_personal':
      return l10n.catPersonal;
    case 'cat_other':
      return l10n.catOther;
    case 'cat_salary':
      return l10n.catSalary;
    case 'cat_bonus':
      return l10n.catBonus;
    case 'cat_other_income':
      return l10n.catOtherIncome;
    default:
      return fallback;
  }
}
