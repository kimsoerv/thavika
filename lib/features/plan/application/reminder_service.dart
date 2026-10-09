import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/money/money.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/ui/category_visuals.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/plan_check.dart';
import '../domain/reminder_planner.dart';

/// Local notifications: a daily "record your spending" nudge and warnings
/// when a category drifts off the plan. Everything runs on the phone.
class ReminderService extends GetxService {
  ReminderService(this._settings);

  final SettingsService _settings;
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _oldDailyId = 1;
  static const _enabledKey = 'reminder_enabled';
  static const _savingsKey = 'reminder_savings';
  static const _monthEndKey = 'reminder_month_end';
  static const _billsKey = 'reminder_bills';
  static const _warningsKey = 'reminder_warnings';
  static const _timeKey = 'reminder_time';
  static const _warnLogKey = 'warn_log';
  static const _maxWarningsPerDay = 2;

  /// Daily "record your spending" reminder.
  final enabled = true.obs;
  final savings = true.obs;
  final monthEnd = true.obs;
  final bills = true.obs;
  final warnings = true.obs;
  final time = const TimeOfDay(hour: 21, minute: 0).obs;

  /// False when the user refused notifications in the system dialog.
  final permissionDenied = false.obs;

  /// Goes up whenever a reminder setting changes, so the scheduler re-plans.
  final changes = 0.obs;

  ReminderPrefs get prefs => ReminderPrefs(
    daily: enabled.value,
    savings: savings.value,
    monthEnd: monthEnd.value,
    bills: bills.value,
    warnings: warnings.value,
    hour: time.value.hour,
    minute: time.value.minute,
  );

  String _warnDay = '';
  final _warnedToday = <String>{};
  var _notificationCounter = 0;

  Future<ReminderService> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to UTC; the daily reminder would then fire at the wrong hour.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    Future<void> load(String key, RxBool target) async {
      final saved = await _settings.getString(key);
      if (saved != null) target.value = saved == '1';
    }

    await load(_enabledKey, enabled);
    await load(_savingsKey, savings);
    await load(_monthEndKey, monthEnd);
    await load(_billsKey, bills);
    await load(_warningsKey, warnings);
    final savedTime = await _settings.getString(_timeKey);
    if (savedTime != null) {
      final parts = savedTime.split(':');
      if (parts.length == 2) {
        time.value = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 21,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    await _loadWarnLog();
    // Older versions scheduled one repeating reminder; the planner replaces it.
    await _plugin.cancel(id: _oldDailyId);
    return this;
  }

  AppLocalizations _l10n() {
    try {
      return lookupAppLocalizations(_settings.locale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }

  /// Asks the system for permission. Returns true when notifications are allowed.
  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosResult = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    final androidResult = await android?.requestNotificationsPermission();
    final granted = iosResult ?? androidResult ?? false;
    permissionDenied.value = !granted;
    return granted;
  }

  Future<void> _set(String key, RxBool target, bool value) async {
    target.value = value;
    await _settings.setString(key, value ? '1' : '0');
    if (value) await requestPermission();
    changes.value++;
  }

  Future<void> setEnabled(bool value) => _set(_enabledKey, enabled, value);
  Future<void> setSavings(bool value) => _set(_savingsKey, savings, value);
  Future<void> setMonthEnd(bool value) => _set(_monthEndKey, monthEnd, value);
  Future<void> setBills(bool value) => _set(_billsKey, bills, value);
  Future<void> setWarnings(bool value) => _set(_warningsKey, warnings, value);

  Future<void> setTime(TimeOfDay value) async {
    time.value = value;
    await _settings.setString(_timeKey, '${value.hour}:${value.minute}');
    changes.value++;
  }

  /// Replaces every scheduled reminder with [planned].
  Future<void> apply(List<PlannedReminder> planned) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      // 1000 and up are immediate warnings, which are never scheduled.
      if (p.id < 1000) await _plugin.cancel(id: p.id);
    }

    final l10n = _l10n();
    final currency = _settings.currency.value;
    for (final r in planned) {
      final String body;
      final String channel;
      switch (r.kind) {
        case ReminderKind.daily:
          body = l10n.notifDailyBody;
          channel = 'daily';
        case ReminderKind.savings:
          body = r.amountMinor == null
              ? l10n.notifSavingsGeneric
              : l10n.notifSavingsBody(Money.format(r.amountMinor!, currency));
          channel = 'savings';
        case ReminderKind.monthEnd:
          body = l10n.notifMonthEndBody;
          channel = 'month_end';
        case ReminderKind.bill:
          body = l10n.notifBillBody(
            r.name ?? '',
            Money.format(r.amountMinor ?? 0, currency),
            DateFormat.MMMd().format(r.dueOn ?? r.at),
          );
          channel = 'bills';
      }
      final when = tz.TZDateTime(
        tz.local,
        r.at.year,
        r.at.month,
        r.at.day,
        r.at.hour,
        r.at.minute,
      );
      await _plugin.zonedSchedule(
        id: r.id,
        title: l10n.appName,
        body: body,
        scheduledDate: when,
        notificationDetails: _details(channel, _channelName(l10n, channel)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  String _channelName(AppLocalizations l10n, String channel) =>
      switch (channel) {
        'daily' => l10n.remindersDaily,
        'savings' => l10n.remindersSavings,
        'month_end' => l10n.remindersMonthEnd,
        _ => l10n.remindersBills,
      };

  NotificationDetails _details(String channelId, String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
  }

  /// Looks at what changed between two checks and warns the user about
  /// categories that moved the wrong way. At most one warning per category
  /// and two warnings in total per day.
  Future<void> evaluate(PlanCheck before, PlanCheck after) async {
    if (!warnings.value) return;
    final l10n = _l10n();
    final currency = _settings.currency.value;
    _rollWarnDay();

    final beforeById = {for (final i in before.items) i.line.id: i};

    final candidates = <ItemCheck>[];
    for (final item in after.items) {
      if (item.isFixed) continue;
      final prev = beforeById[item.line.id];
      if (prev == null) continue;
      final worsened =
          item.status.index > prev.status.index &&
          item.status != PaceStatus.onTrack;
      final crossed80 =
          prev.used < 0.8 && item.used >= 0.8 && item.status != PaceStatus.over;
      if (worsened || crossed80) candidates.add(item);
    }
    candidates.sort((a, b) => b.status.index.compareTo(a.status.index));

    for (final item in candidates) {
      if (_warnedToday.length >= _maxWarningsPerDay) break;
      final key = item.line.categoryId ?? item.line.id;
      if (_warnedToday.contains(key)) continue;

      final name = categoryNameFor(l10n, key, item.line.name);
      final budget = item.line.budgetMinor;
      final left = budget - item.spent;
      final prev = beforeById[item.line.id]!;
      final String body;
      if (item.status == PaceStatus.over) {
        body = l10n.notifOverBody(name, Money.format(-left, currency));
      } else if (item.status.index > prev.status.index) {
        final perDay = after.daysLeft > 0 ? left ~/ after.daysLeft : left;
        body = l10n.notifPaceBody(
          name,
          Money.format(item.spent, currency),
          Money.format(budget, currency),
          Money.format(left, currency),
          Money.format(perDay, currency),
        );
      } else {
        body = l10n.notifNearLimitBody(name);
      }

      _warnedToday.add(key);
      await _saveWarnLog();
      await _plugin.show(
        id: 1000 + (_notificationCounter++ % 1000),
        title: l10n.appName,
        body: body,
        notificationDetails: _details('warnings', 'Spending warnings'),
      );
    }
  }

  String _today() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  void _rollWarnDay() {
    final today = _today();
    if (_warnDay != today) {
      _warnDay = today;
      _warnedToday.clear();
    }
  }

  Future<void> _loadWarnLog() async {
    final raw = await _settings.getString(_warnLogKey);
    if (raw == null) return;
    final parts = raw.split('|');
    if (parts.length == 2 && parts[0] == _today()) {
      _warnDay = parts[0];
      _warnedToday.addAll(parts[1].split(',').where((e) => e.isNotEmpty));
    }
  }

  Future<void> _saveWarnLog() =>
      _settings.setString(_warnLogKey, '$_warnDay|${_warnedToday.join(',')}');
}
