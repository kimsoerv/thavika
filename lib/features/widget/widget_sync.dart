import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/money/money.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/settings_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../plan/application/budget_service.dart';

/// Keeps the home-screen widget up to date and opens the add screen when
/// its + button is tapped. Only Android has a widget for now.
class WidgetSync extends GetxService {
  WidgetSync(this._budget, this._settings);

  static const providerName = 'ThavikaWidgetProvider';

  final BudgetService _budget;
  final SettingsService _settings;
  final _workers = <Worker>[];
  StreamSubscription<Uri?>? _clicks;
  Timer? _debounce;

  bool get _supported => Platform.isAndroid;

  Future<WidgetSync> init() async {
    if (!_supported) return this;
    _workers.addAll([
      ever(_budget.check, (_) => _push()),
      ever(_budget.monthTx, (_) => _push()),
      ever(_settings.language, (_) => _push()),
      ever(_settings.currency, (_) => _push()),
    ]);
    _clicks = HomeWidget.widgetClicked.listen(_open);
    _push();
    return this;
  }

  /// Call once the first screen is up, to handle a launch from the widget.
  Future<void> handleLaunch() async {
    if (!_supported) return;
    try {
      _open(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (_) {}
  }

  void _open(Uri? uri) {
    if (uri == null || uri.scheme != 'thavika') return;
    if (uri.host == 'add') Get.toNamed(Routes.entry);
  }

  void _push() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _write);
  }

  Future<void> _write() async {
    try {
      final l10n = lookupAppLocalizations(_settings.locale);
      final currency = _settings.currency.value;
      final check = _budget.check.value;

      final String label;
      final int amount;
      if (check != null) {
        label = l10n.widgetSafeLabel;
        amount = check.safeToSpend;
      } else {
        label = l10n.balanceThisMonth;
        var balance = 0;
        for (final e in _budget.monthTx) {
          balance += e.tx.type == 'income'
              ? e.tx.amountMinor
              : -e.tx.amountMinor;
        }
        amount = balance;
      }
      await HomeWidget.saveWidgetData<String>('widget_label', label);
      await HomeWidget.saveWidgetData<String>(
        'widget_amount',
        Money.format(amount, currency),
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.thavika.thavika.$providerName',
      );
    } catch (_) {
      // The widget is optional; never let it break the app.
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _clicks?.cancel();
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }
}
