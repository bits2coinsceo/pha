import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'locale_controller.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/app_logger.dart';
import 'db.dart';
import 'health_index.dart';
import 'health_telemetry.dart';
import 'medical_guidelines.dart';
import 'physical_activity.dart';
import 'services.dart';
import 'l10n/l10n_ext.dart';
import 'l10n/medical_l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// Top-level handler required by iOS when a notification action runs in a
/// background isolate (app terminated / not in foreground).
@pragma('vm:entry-point')
void phaNotificationTapBackground(NotificationResponse response) {
  // Keep empty and crash-safe — no Flutter UI / plugins here.
  // Foreground + cold-start taps are handled via [DailyNotificationService].
}

/// One scheduled in-app / push notification for the current day.
class DailyNotificationItem {
  final String id;
  final String title;
  final String body;
  final int hour;
  final int minute;

  const DailyNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
  });

  DateTime get scheduledAt {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  bool get isPast => !DateTime.now().isBefore(scheduledAt);

  /// Locale-aware clock label (e.g. 20:00 in ru, 8:00 PM in en).
  String localizedTimeLabel(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(
      TimeOfDay(hour: hour, minute: minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
      };

  factory DailyNotificationItem.fromJson(Map<String, dynamic> json) =>
      DailyNotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );
}

/// Twice-daily local notifications (10:30 AM & 8:00 PM) with short localized tips.
class DailyNotificationService {
  DailyNotificationService._();

  static const _morningId = 1001;
  static const _eveningId = 1002;
  /// Fires ~20 min before the morning push so we can sync HealthKit and
  /// rewrite the 10:30 banner with finalized yesterday steps.
  static const _morningPrepId = 1000;
  static const _morningHour = 10;
  static const _morningMinute = 30;
  static const _eveningHour = 20;
  static const _eveningMinute = 0;
  /// Short in-app bodies — details live on Health Insights.
  static const _inAppBodyMax = 280;
  static const _osPushBodyMax = 180;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Last OS notification tap waiting to be consumed by the UI.
  static NotificationResponse? pendingTap;

  static final List<void Function(NotificationResponse)> _tapListeners = [];

  static bool get isInitialized => _initialized;

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static const _heartAlertInboxPrefix = 'heart_rate_alert_inbox_';

  static Future<void> saveHeartRateAlert({
    required String userId,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(
      '$_heartAlertInboxPrefix$userId',
      jsonEncode({
        'id': 'heart-rate-alert',
        'title': title,
        'body': body,
        'hour': hour,
        'minute': minute,
        'date': _dateLabel(now),
      }),
    );
  }

  static Future<bool> ensureReady() async {
    if (kIsWeb) return false;
    if (!_initialized) await init();
    return _initialized;
  }

  static tz.TZDateTime scheduledTodayOrTomorrow(int hour, int minute) =>
      _nextTime(hour, minute);

  static void addTapListener(void Function(NotificationResponse) listener) {
    _tapListeners.add(listener);
  }

  static void removeTapListener(void Function(NotificationResponse) listener) {
    _tapListeners.remove(listener);
  }

  static NotificationResponse? takePendingTap() {
    final tap = pendingTap;
    pendingTap = null;
    return tap;
  }

  static void _onNotificationResponse(NotificationResponse response) {
    try {
      AppLogger.i(
        'Notification tap id=${response.id} payload=${response.payload}',
        category: LogCategory.notifications,
      );
      pendingTap = response;
      for (final listener in List<void Function(NotificationResponse)>.from(
        _tapListeners,
      )) {
        try {
          listener(response);
        } catch (e, st) {
          AppLogger.w(
            'Notification tap listener failed',
            error: e,
            stackTrace: st,
            category: LogCategory.notifications,
          );
        }
      }
    } catch (e, st) {
      AppLogger.e(
        'Notification tap handler crashed (swallowed)',
        error: e,
        stackTrace: st,
        category: LogCategory.notifications,
      );
    }
  }

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final timeZoneName = await FlutterTimezone.getLocalTimezone()
            .timeout(const Duration(seconds: 3));
        // Some devices return IANA names; others return aliases — fall back safely.
        try {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
        } catch (_) {
          _setLocalFromDeviceOffset();
        }
      } catch (_) {
        _setLocalFromDeviceOffset();
      }
      const settings = InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          // Show banners while PHA is open so taps route into our handler.
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin
          .initialize(
            settings,
            onDidReceiveNotificationResponse: _onNotificationResponse,
            onDidReceiveBackgroundNotificationResponse:
                phaNotificationTapBackground,
          )
          .timeout(const Duration(seconds: 5));

      // Cold start: app was launched by tapping a notification.
      try {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true &&
            launch?.notificationResponse != null) {
          _onNotificationResponse(launch!.notificationResponse!);
        }
      } catch (e, st) {
        AppLogger.w(
          'getNotificationAppLaunchDetails failed',
          error: e,
          stackTrace: st,
          category: LogCategory.notifications,
        );
      }

      _initialized = true;
    } catch (e, st) {
      debugPrint('DailyNotificationService.init failed: $e');
      debugPrintStack(stackTrace: st);
      AppLogger.e(
        'DailyNotificationService.init failed',
        error: e,
        stackTrace: st,
        category: LogCategory.notifications,
      );
    }
  }

  static void _setLocalFromDeviceOffset() {
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    if (offsetHours == 0) {
      tz.setLocalLocation(tz.UTC);
      return;
    }
    // Etc/GMT signs are inverted vs ISO offset.
    final sign = offsetHours > 0 ? '-' : '+';
    final etcName = 'Etc/GMT$sign${offsetHours.abs()}';
    try {
      tz.setLocalLocation(tz.getLocation(etcName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  static Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final settings = await ios?.checkPermissions();
      return (settings?.isAlertEnabled ?? false) || (settings?.isEnabled ?? false);
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    return false;
  }

  /// Builds short localized tip text and schedules next morning/evening pushes.
  ///
  /// Bodies are deterministic templates (no AI) so they stay translated, short,
  /// and load instantly. Evening text refreshes when steps move before 20:00.
  /// Morning OS push body is computed for the **delivery calendar day** so
  /// "Yesterday" matches the day before the notification fires (not the day
  /// the schedule was created).
  ///
  /// Before baking the morning banner, yesterday's steps are pulled from
  /// HealthKit / Health Connect. On iOS a background refresh ~20 minutes
  /// before 10:30 rewrites the pending banner with the finalized total.
  static Future<void> scheduleForUser(String userId) async {
    if (!_initialized) await init();
    if (!await hasPermission()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_notif_active_user_id', userId);

    await _syncDeviceQuietly(userId);
    await _refreshBodiesAndSchedule(userId);
  }

  /// Fast path used by the in-app notifications panel (no HealthKit wait).
  static Future<void> ensureTodayContent(String userId) async {
    await _refreshBodiesAndSchedule(userId);
  }

  static Future<void> _refreshBodiesAndSchedule(String userId) async {
    final l10n = await LocaleController.loadLocalizations();
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateLabel(DateTime.now());
    final lastKey = prefs.getString('daily_notif_date_$userId');
    final cachedLocale = prefs.getString('daily_notif_locale_$userId');
    final currentLocale = l10n.localeName;
    final localeChanged = cachedLocale != currentLocale;
    final now = DateTime.now();
    final eveningPassed = now.hour > _eveningHour ||
        (now.hour == _eveningHour && now.minute >= _eveningMinute);

    if (lastKey != todayKey || localeChanged) {
      await prefs.remove('daily_notif_evening_final_$userId');
      await prefs.remove('daily_notif_evening_steps_$userId');
      await prefs.remove('daily_notif_evening_$userId');
      await prefs.remove('daily_notif_morning_$userId');
      await prefs.remove('daily_notif_log_$userId');
      await prefs.setString('daily_notif_locale_$userId', currentLocale);
    }

    // In-app inbox: "yesterday" relative to now (when the user is looking).
    final morningBody = _clip(
      await _localizedMorningBody(userId, l10n),
      _inAppBodyMax,
    );
    await prefs.setString('daily_notif_morning_$userId', morningBody);

    final todaySteps = await _todaySteps(userId);
    final yesterdaySteps = await _stepsOnDay(
      userId,
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final cachedEveningSteps =
        prefs.getInt('daily_notif_evening_steps_$userId');
    final inEveningWindow = now.hour >= _eveningHour - 2;
    final eveningFinalized =
        prefs.getBool('daily_notif_evening_final_$userId') == true;
    final stepsMoved = cachedEveningSteps == null ||
        (todaySteps - cachedEveningSteps).abs() >= 100;
    final cachedEveningBody =
        prefs.getString('daily_notif_evening_$userId') ?? '';
    final needsNewFormat = _looksLikeLegacyBody(cachedEveningBody) ||
        localeChanged ||
        lastKey != todayKey;

    late final String eveningBody;
    final refreshEvening = needsNewFormat ||
        !prefs.containsKey('daily_notif_evening_$userId') ||
        (!eveningPassed && inEveningWindow && (!eveningFinalized || stepsMoved));

    if (refreshEvening) {
      if (!inEveningWindow && !eveningPassed) {
        eveningBody = l10n.notifEveningOpenApp;
        await prefs.setBool('daily_notif_evening_final_$userId', false);
      } else {
        eveningBody = await _localizedEveningBody(
          userId,
          l10n,
          todaySteps: todaySteps,
          yesterdaySteps: yesterdaySteps,
        );
        await prefs.setBool('daily_notif_evening_final_$userId', true);
      }
      final clipped = _clip(eveningBody, _inAppBodyMax);
      await prefs.setString('daily_notif_evening_$userId', clipped);
      await prefs.setInt('daily_notif_evening_steps_$userId', todaySteps);
      await prefs.setString('daily_notif_date_$userId', todayKey);
      await _persistTodayLog(userId, morningBody, clipped);
      await _scheduleOsPushes(
        userId: userId,
        l10n: l10n,
        eveningBody: clipped,
        eveningPassed: eveningPassed,
      );
      return;
    }

    await prefs.setString('daily_notif_date_$userId', todayKey);
    await _persistTodayLog(userId, morningBody, cachedEveningBody);
    await _scheduleOsPushes(
      userId: userId,
      l10n: l10n,
      eveningBody: cachedEveningBody,
      eveningPassed: eveningPassed,
    );
  }

  static Future<void> _scheduleOsPushes({
    required String userId,
    required AppLocalizations l10n,
    required String eveningBody,
    required bool eveningPassed,
  }) async {
    if (!_initialized) return;

    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      android: AndroidNotificationDetails(
        'pha_daily',
        l10n.notifChannelName,
        channelDescription: l10n.notifChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _plugin.cancel(_morningId);
      await _plugin.cancel(_eveningId);
      await _plugin.cancel(_morningPrepId);

      final morningAt = _nextTime(_morningHour, _morningMinute);
      final deliveryDay = DateTime(morningAt.year, morningAt.month, morningAt.day);
      final yesterday = deliveryDay.subtract(const Duration(days: 1));

      // Finalize yesterday from the device before baking the banner.
      await _syncDayForMorningPush(userId, yesterday);

      final osMorningBody = _clip(
        await _localizedMorningBody(
          userId,
          l10n,
          forDeliveryDay: deliveryDay,
          avoidZeroBanner: true,
        ),
        _osPushBodyMax,
      );

      await _plugin.zonedSchedule(
        _morningId,
        l10n.morningNotificationTitle,
        osMorningBody,
        morningAt,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      await _scheduleNativeMorningPrep(
        fireAt: morningAt,
        title: l10n.morningNotificationTitle,
        userId: userId,
        l10n: l10n,
        deliveryDay: deliveryDay,
      );

      if (!eveningPassed) {
        await _plugin.zonedSchedule(
          _eveningId,
          l10n.eveningNotificationTitle,
          _clip(eveningBody, _osPushBodyMax),
          _nextTime(_eveningHour, _eveningMinute),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e, st) {
      debugPrint('DailyNotificationService.scheduleForUser failed: $e\n$st');
    }
  }

  /// Sentinel step count used only to build a replaceable OS body template.
  static const _stepsTemplateSentinel = 912837465;

  static Future<void> _scheduleNativeMorningPrep({
    required tz.TZDateTime fireAt,
    required String title,
    required String userId,
    required AppLocalizations l10n,
    required DateTime deliveryDay,
  }) async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      final yesterday = deliveryDay.subtract(const Duration(days: 1));
      final kcal = await _mealKcalOnDay(userId, yesterday);
      final index = await _indexSnapshot(userId, l10n);
      final withSentinel = l10n.notifMorningShort(
        _stepsTemplateSentinel,
        MedicalGuidelines.stepsGoal,
        kcal,
        index.score,
        index.status,
      );
      final template = withSentinel.replaceAll(
        '$_stepsTemplateSentinel',
        '__STEPS__',
      );
      const channel = MethodChannel('pha.morning_push_prep/methods');
      await channel.invokeMethod<void>('schedule', {
        'fireAtMs': fireAt.millisecondsSinceEpoch,
        'title': title,
        'bodyTemplate': _clip(template, _osPushBodyMax),
      });
    } catch (e, st) {
      debugPrint('Morning push prep schedule failed: $e\n$st');
    }
  }

  /// Old AI / markdown bodies — force rewrite to short localized templates.
  static bool _looksLikeLegacyBody(String body) {
    if (body.isEmpty) return true;
    if (body.contains('**') || body.contains('* ')) return true;
    if (body.length > _inAppBodyMax) return true;
    final lower = body.toLowerCase();
    return lower.contains('good job logging') ||
        (lower.contains('health index') && lower.contains('currently')) ||
        lower.contains('what looks good') ||
        lower.contains('what requires attention');
  }

  /// Call after HealthKit sync so morning/evening tips track real step counts.
  /// Does not sync again — caller already pulled from the device.
  static Future<void> refreshEveningAfterActivitySync(String userId) async {
    if (!await hasPermission()) return;
    if (!_initialized) await init();
    await _refreshBodiesAndSchedule(userId);
  }

  static Future<void> _syncDayForMorningPush(
    String userId,
    DateTime day,
  ) async {
    try {
      if (!HealthTelemetryService.isSupported) return;
      if (!await HealthTelemetryService.hasPermission()) return;
      await HealthConnectService.syncDayFromDevice(userId, day)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Non-fatal — fall back to SQLite / open-app tip.
    }
  }

  static Future<void> _syncDeviceQuietly(String userId) async {
    try {
      if (!HealthTelemetryService.isSupported) return;
      if (!await HealthTelemetryService.hasPermission()) return;
      final morningAt = _nextTime(_morningHour, _morningMinute);
      final deliveryDay =
          DateTime(morningAt.year, morningAt.month, morningAt.day);
      final yesterday = deliveryDay.subtract(const Duration(days: 1));
      // Morning banner needs yesterday; live dashboard needs today.
      await Future.wait([
        _syncDayForMorningPush(userId, yesterday),
        () async {
          try {
            await HealthConnectService.syncFromDevice(userId)
                .timeout(const Duration(seconds: 8));
          } catch (_) {}
        }(),
      ]);
    } catch (_) {
      // Non-fatal — tips fall back to whatever is already in SQLite.
    }
  }

  static Future<int> _todaySteps(String userId) =>
      _stepsOnDay(userId, DateTime.now());

  static Future<int> _stepsOnDay(String userId, DateTime day) async {
    if (!Db.instance.isReady) return 0;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await Db.instance.raw.query(
      'health_metrics',
      where: 'user_id = ? AND metric_type = ?',
      whereArgs: [userId, 'steps'],
      orderBy: 'recorded_at DESC',
    );
    var maxSteps = 0;
    for (final r in rows) {
      final at = DateTime.parse(r['recorded_at'] as String).toLocal();
      if (at.isBefore(start) || !at.isBefore(end)) continue;
      final v = (r['value'] as num).toInt();
      if (v > maxSteps) maxSteps = v;
    }
    return maxSteps;
  }

  static Future<({int score, String status})> _indexSnapshot(
    String userId,
    AppLocalizations l10n,
  ) async {
    try {
      final latest = await HealthIndexService.latest(userId);
      if (latest != null) {
        return (score: latest.score, status: l10n.statusLabel(latest.status));
      }
    } catch (_) {}
    return (score: 0, status: l10n.statusLabel('fair'));
  }

  /// Morning recap for [forDeliveryDay] (defaults to today).
  /// "Yesterday" = calendar day before the delivery day.
  ///
  /// When [avoidZeroBanner] is true (OS push), a zero/empty yesterday falls
  /// back to a short “open PHA” tip so the lock-screen banner is not frozen
  /// with “0 steps” before HealthKit has synced.
  static Future<String> _localizedMorningBody(
    String userId,
    AppLocalizations l10n, {
    DateTime? forDeliveryDay,
    bool avoidZeroBanner = false,
  }) async {
    final delivery = forDeliveryDay ?? DateTime.now();
    final day = DateTime(delivery.year, delivery.month, delivery.day);
    final yesterday = day.subtract(const Duration(days: 1));
    final steps = await _stepsOnDay(userId, yesterday);
    final kcal = await _mealKcalOnDay(userId, yesterday);
    final index = await _indexSnapshot(userId, l10n);
    if (avoidZeroBanner && steps <= 0 && kcal <= 0) {
      return l10n.notifMorningFallbackDetailed;
    }
    return l10n.notifMorningShort(
      steps,
      MedicalGuidelines.stepsGoal,
      kcal,
      index.score,
      index.status,
    );
  }

  static Future<String> _localizedEveningBody(
    String userId,
    AppLocalizations l10n, {
    required int todaySteps,
    required int yesterdaySteps,
  }) async {
    final index = await _indexSnapshot(userId, l10n);
    return l10n.notifEveningShort(
      todaySteps,
      yesterdaySteps,
      index.score,
      index.status,
    );
  }

  static Future<int> _mealKcalOnDay(String userId, DateTime day) async {
    if (!Db.instance.isReady) return 0;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final meals = await Db.instance.raw.query(
      'meal_calorie_checks',
      where: 'user_id = ? AND confirmed = 1',
      whereArgs: [userId],
      orderBy: 'checked_at DESC',
    );
    var total = 0;
    for (final m in meals) {
      final at = DateTime.parse(m['checked_at'] as String).toLocal();
      if (at.isBefore(start) || !at.isBefore(end)) continue;
      total += (m['calories'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  static tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _clip(String text, int max) {
    final t = text.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Notifications that already fired today (not future / scheduled ones).
  static Future<List<DailyNotificationItem>> todayForUser(String userId) async {
    final tips = await _aiTipsForUser(userId);
    final treatment = await _treatmentReminders(userId);
    final activity = await _activityCheckinReminder(userId);
    final incomplete = await _incompleteAssessmentsReminder(userId);
    final heart = await _heartRateAlertReminder(userId);
    final all = [...heart, ...incomplete, ...tips, ...treatment, ...activity]
        .where((n) => n.isPast)
        .toList();
    all.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return all;
  }

  static Future<List<DailyNotificationItem>> _aiTipsForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateLabel(DateTime.now());
    if (prefs.getString('daily_notif_date_$userId') != todayKey) return [];

    final logJson = prefs.getString('daily_notif_log_$userId');
    if (logJson != null && logJson.isNotEmpty) {
      final list = jsonDecode(logJson) as List<dynamic>;
      return list
          .map((e) => DailyNotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final morning = prefs.getString('daily_notif_morning_$userId');
    final evening = prefs.getString('daily_notif_evening_$userId');
    if (morning == null || evening == null) return [];
    final l10n = await LocaleController.loadLocalizations();
    return _itemsFromBodies(morning, evening, l10n);
  }

  static Future<List<DailyNotificationItem>> _treatmentReminders(String userId) async {
    final l10n = await LocaleController.loadLocalizations();
    if (!Db.instance.isReady) return [];
    final rows = await Db.instance.raw.query(
      'treatment_schedule',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    final reminders = <DailyNotificationItem>[];
    for (final row in rows) {
      final itemId = row['id'] as String;
      final name = row['name'] as String;
      final doses = row['doses_per_day'] as int;
      final raw = row['dose_times'] as String? ?? '[]';
      final times = (jsonDecode(raw) as List).cast<String>();
      for (var i = 0; i < times.length; i++) {
        final parts = times[i].split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final doseLabel = doses > 1 ? l10n.notifDoseLabel(i + 1, doses) : '';
        reminders.add(DailyNotificationItem(
          id: 'treatment-$itemId-$i',
          title: l10n.notifMedicationTitle(name),
          body: '$doseLabel${l10n.notifMedicationBody(name)}',
          hour: hour,
          minute: minute,
        ));
      }
    }
    return reminders;
  }

  static Future<List<DailyNotificationItem>> _activityCheckinReminder(
      String userId) async {
    final l10n = await LocaleController.loadLocalizations();
    if (!Db.instance.isReady) return [];
    final rows = await Db.instance.raw.query(
      'physical_activity_programs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return [];
    final label = rows.first['program_label'] as String? ?? l10n.activityYourProgramFallback;
    return [
      DailyNotificationItem(
        id: 'activity-checkin',
        title: l10n.notifActivityTitle,
        body: l10n.notifActivityBody(label),
        hour: 20,
        minute: 0,
      ),
    ];
  }

  /// Reminders to complete habits / wellness / PsychoTest for a fuller Health Index.
  static Future<List<DailyNotificationItem>> _incompleteAssessmentsReminder(
    String userId,
  ) async {
    if (!Db.instance.isReady) return [];
    final l10n = await LocaleController.loadLocalizations();
    final db = Db.instance.raw;
    final missing = <String>[];

    Future<bool> hasRow(String table) async {
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      return rows.isNotEmpty;
    }

    if (!await hasRow('bad_habit_checks')) {
      missing.add(l10n.actionBadHabits);
    }
    if (!await hasRow('stress_tests')) {
      missing.add(l10n.actionWellnessCheck);
    }
    if (!await hasRow('psychotest_results')) {
      missing.add(l10n.actionPsychoTest);
    }
    if (missing.isEmpty) return [];

    return [
      DailyNotificationItem(
        id: 'incomplete-assessments',
        title: l10n.notifIncompleteAssessmentsTitle,
        body: l10n.notifIncompleteAssessmentsBody(missing.join(', ')),
        hour: 0,
        minute: 0,
      ),
    ];
  }

  static Future<List<DailyNotificationItem>> _heartRateAlertReminder(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_heartAlertInboxPrefix$userId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['date'] != _dateLabel(DateTime.now())) return [];
      return [
        DailyNotificationItem(
          id: map['id'] as String? ?? 'heart-rate-alert',
          title: map['title'] as String? ?? '',
          body: map['body'] as String? ?? '',
          hour: (map['hour'] as num?)?.toInt() ?? 0,
          minute: (map['minute'] as num?)?.toInt() ?? 0,
        ),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<int> unreadCount(String userId) async {
    final items = await todayForUser(userId);
    if (items.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    final read = prefs.getStringList(_readKey(userId)) ?? [];
    return items.where((n) => n.isPast && !read.contains(n.id)).length;
  }

  static Future<void> markAllReadToday(String userId) async {
    final items = await todayForUser(userId);
    if (items.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey(userId), items.map((n) => n.id).toList());
  }

  static String _readKey(String userId) =>
      'daily_notif_read_${userId}_${_dateLabel(DateTime.now())}';

  static Future<void> _persistTodayLog(
    String userId,
    String morningBody,
    String eveningBody,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final l10n = await LocaleController.loadLocalizations();
    final items = _itemsFromBodies(morningBody, eveningBody, l10n);
    await prefs.setString(
      'daily_notif_log_$userId',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static List<DailyNotificationItem> _itemsFromBodies(
    String morningBody,
    String eveningBody,
    AppLocalizations l10n,
  ) =>
      [
        DailyNotificationItem(
          id: 'morning',
          title: l10n.morningNotificationTitle,
          body: morningBody,
          hour: _morningHour,
          minute: _morningMinute,
        ),
        DailyNotificationItem(
          id: 'evening',
          title: l10n.eveningNotificationTitle,
          body: eveningBody,
          hour: _eveningHour,
          minute: _eveningMinute,
        ),
      ];
}

/// In-app list of today's Ai Doc push notifications (home screen bell).
class TodayNotificationsPanel extends StatefulWidget {
  final String userId;
  const TodayNotificationsPanel({super.key, required this.userId});

  @override
  State<TodayNotificationsPanel> createState() => _TodayNotificationsPanelState();
}

class _TodayNotificationsPanelState extends State<TodayNotificationsPanel> {
  List<DailyNotificationItem> items = [];
  bool loading = true;
  String? activityAnswer; // yes | no | partially
  bool activitySaving = false;
  bool savedAnything = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await DailyNotificationService.ensureTodayContent(widget.userId);
    final list = await DailyNotificationService.todayForUser(widget.userId);
    final status =
        await PhysicalActivityService.todaysCheckinStatus(widget.userId);
    if (mounted) {
      setState(() {
        items = list;
        activityAnswer = status;
        loading = false;
      });
    }
  }

  Future<void> _answerActivity(String status) async {
    if (activitySaving) return;
    setState(() => activitySaving = true);
    try {
      await PhysicalActivityService.saveCheckin(
        userId: widget.userId,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        activityAnswer = status;
        activitySaving = false;
        savedAnything = true;
      });
    } catch (e, st) {
      debugPrint('activity check-in from notifications failed: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) setState(() => activitySaving = false);
    }
  }

  String _answerLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'yes':
        return l10n.yes;
      case 'no':
        return l10n.no;
      case 'partially':
        return l10n.partially;
      default:
        return status;
    }
  }

  String _localizedTitle(BuildContext context, DailyNotificationItem item) {
    final l10n = context.l10n;
    return switch (item.id) {
      'morning' => l10n.morningNotificationTitle,
      'evening' => l10n.eveningNotificationTitle,
      'incomplete-assessments' => l10n.notifIncompleteAssessmentsTitle,
      'heart-rate-alert' => l10n.hrAlertRiskTitle,
      _ => item.title,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppModal(
      title: l10n.todaysNotifications,
      onClose: () => Navigator.pop(context, savedAnything),
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none, size: 40, color: C.gray400),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noNotificationsToday,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: C.gray500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.notificationsAppearHere,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: C.gray400, height: 1.4),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _notificationCard(items[i]),
                    ],
                  ],
                ),
    );
  }

  Widget _notificationCard(DailyNotificationItem item) {
    final l10n = context.l10n;
    final isTreatment = item.id.startsWith('treatment-');
    final isActivity = item.id == 'activity-checkin';
    final isIncomplete = item.id == 'incomplete-assessments';
    final isHeart = item.id == 'heart-rate-alert';
    final icon = isHeart
        ? Icons.monitor_heart_outlined
        : isIncomplete
            ? Icons.assignment_late_outlined
            : isActivity
                ? Icons.fitness_center_outlined
                : isTreatment
                    ? Icons.medication_outlined
                    : item.id == 'morning'
                        ? Icons.wb_sunny_outlined
                        : Icons.nights_stay_outlined;
    final iconColor = isHeart
        ? C.red600
        : isIncomplete
            ? C.amber700
            : isActivity
                ? C.emerald600
                : isTreatment
                    ? C.teal700
                    : item.id == 'morning'
                        ? C.amber700
                        : C.blue600;
    final iconBg = isHeart
        ? C.red50
        : isIncomplete
            ? C.amber50
            : isActivity
                ? C.emerald50
                : isTreatment
                    ? C.teal50
                    : item.id == 'morning'
                        ? C.amber50
                        : C.blue50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localizedTitle(context, item),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: C.gray900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActivity
                          ? l10n.dailyLabel
                          : item.localizedTimeLabel(context),
                      style: TextStyle(fontSize: 12, color: C.gray400),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.body,
            style: TextStyle(fontSize: 14, color: C.gray700, height: 1.45),
          ),
          if (item.id == 'morning' || item.id == 'evening') ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, 'insights'),
                style: TextButton.styleFrom(
                  foregroundColor: C.blue600,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.insights_outlined, size: 16),
                label: Text(
                  l10n.notifOpenHealthInsights,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          if (isActivity) ...[
            const SizedBox(height: 14),
            if (activityAnswer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: C.emerald50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.emerald600.withValues(alpha: 0.25)),
                ),
                child: Text(
                  l10n.notifActivitySaved(_answerLabel(activityAnswer!, l10n)),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: C.emerald600,
                  ),
                ),
              )
            else if (activitySaving)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _ActivityAnswerChip(
                      label: l10n.yes,
                      color: C.teal600,
                      onTap: () => _answerActivity('yes'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActivityAnswerChip(
                      label: l10n.no,
                      color: C.gray700,
                      outlined: true,
                      onTap: () => _answerActivity('no'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActivityAnswerChip(
                      label: l10n.partially,
                      color: C.blue600,
                      onTap: () => _answerActivity('partially'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivityAnswerChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActivityAnswerChip({
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? C.white : color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: outlined ? C.cardBorder : color,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: outlined ? color : C.white,
            ),
          ),
        ),
      ),
    );
  }
}
