import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'api.dart';
import 'core/app_logger.dart';
import 'db.dart';
import 'health_telemetry.dart';
import 'medical_guidelines.dart';
import 'physical_activity.dart';
import 'services.dart';
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

  String get timeLabel {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $suffix';
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

/// Twice-daily local notifications (10:30 AM & 8:00 PM) with Gemini-generated tips.
class DailyNotificationService {
  DailyNotificationService._();

  static const _morningId = 1001;
  static const _eveningId = 1002;
  static const _morningHour = 10;
  static const _morningMinute = 30;
  static const _eveningHour = 20;
  static const _eveningMinute = 0;
  static const _morningTitle = 'Good morning — your health recap';
  static const _eveningTitle = 'Evening check-in';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Last OS notification tap waiting to be consumed by the UI.
  static NotificationResponse? pendingTap;

  static final List<void Function(NotificationResponse)> _tapListeners = [];

  static bool get isInitialized => _initialized;

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

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

  /// Syncs device activity, builds fresh tip text, and schedules the next
  /// morning/evening one-shot notifications (not a repeating template).
  ///
  /// Evening body is regenerated whenever today's steps change before 20:00,
  /// so the push uses current HealthKit data — not a morning snapshot.
  static Future<void> scheduleForUser(String userId) async {
    if (!_initialized) await init();
    if (!await hasPermission()) return;

    await _syncDeviceQuietly(userId);

    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateLabel(DateTime.now());
    final lastKey = prefs.getString('daily_notif_date_$userId');
    final now = DateTime.now();
    final eveningPassed = now.hour > _eveningHour ||
        (now.hour == _eveningHour && now.minute >= _eveningMinute);

    if (lastKey != todayKey) {
      await prefs.remove('daily_notif_evening_ai_$userId');
      await prefs.remove('daily_notif_evening_final_$userId');
      await prefs.remove('daily_notif_evening_steps_$userId');
    }

    String morningBody;
    String eveningBody;

    final morningCached = lastKey == todayKey &&
        prefs.containsKey('daily_notif_morning_$userId');
    if (morningCached) {
      morningBody = prefs.getString('daily_notif_morning_$userId')!;
    } else {
      try {
        morningBody = await _generateMorningAdvice(userId);
      } catch (_) {
        morningBody =
            'Check PHA: yesterday\'s steps, meal calories, and a nutrition tip for today.';
      }
      morningBody = _clip(morningBody, 200);
      await prefs.setString('daily_notif_morning_$userId', morningBody);
    }

    final todaySteps = await _todaySteps(userId);
    final yesterdaySteps = await _stepsOnDay(
      userId,
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final cachedEveningSteps =
        prefs.getInt('daily_notif_evening_steps_$userId');
    final eveningCached = lastKey == todayKey &&
        prefs.containsKey('daily_notif_evening_$userId');
    // Finalize step-based copy only in the evening window (from 18:00), so we
    // don't lock in a morning "0 steps" body for the 20:00 push.
    final inEveningWindow = now.hour >= _eveningHour - 2;
    final eveningFinalized =
        prefs.getBool('daily_notif_evening_final_$userId') == true;
    final stepsMoved = cachedEveningSteps == null ||
        (todaySteps - cachedEveningSteps).abs() >= 100;

    var refreshEvening = false;
    if (!eveningPassed) {
      if (!inEveningWindow) {
        refreshEvening = !eveningCached;
      } else {
        refreshEvening = !eveningFinalized || stepsMoved;
      }
    } else if (!eveningCached) {
      refreshEvening = true;
    }

    if (refreshEvening) {
      if (!inEveningWindow && !eveningPassed) {
        eveningBody =
            'Open PHA for your evening check-in — see how today compared to yesterday.';
        await prefs.setBool('daily_notif_evening_final_$userId', false);
      } else {
        final alreadyAi =
            prefs.getBool('daily_notif_evening_ai_$userId') == true;
        final shouldCallAi = !alreadyAi ||
            (cachedEveningSteps != null &&
                cachedEveningSteps == 0 &&
                todaySteps >= 100);
        if (shouldCallAi) {
          try {
            eveningBody = await _generateEveningAdvice(userId);
            await prefs.setBool('daily_notif_evening_ai_$userId', true);
          } catch (_) {
            eveningBody =
                _deterministicEvening(todaySteps, yesterdaySteps);
          }
        } else {
          eveningBody = _deterministicEvening(todaySteps, yesterdaySteps);
        }
        await prefs.setBool('daily_notif_evening_final_$userId', true);
      }
      eveningBody = _clip(eveningBody, 200);
      await prefs.setString('daily_notif_evening_$userId', eveningBody);
      await prefs.setInt('daily_notif_evening_steps_$userId', todaySteps);
    } else {
      eveningBody = prefs.getString('daily_notif_evening_$userId')!;
    }

    await prefs.setString('daily_notif_date_$userId', todayKey);
    await _persistTodayLog(userId, morningBody, eveningBody);

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      android: AndroidNotificationDetails(
        'pha_daily',
        'Daily health tips',
        channelDescription: 'Morning and evening health advice from Ai Doc',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _plugin.cancel(_morningId);
      await _plugin.cancel(_eveningId);

      // One-shot next fire only — body is refreshed on each scheduleForUser /
      // sync, so we never keep a stale repeating template.
      await _plugin.zonedSchedule(
        _morningId,
        _morningTitle,
        morningBody,
        _nextTime(_morningHour, _morningMinute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // Only schedule tonight's evening push while it still lies ahead.
      // After 20:00, tomorrow's body is filled on the next day's schedule run.
      if (!eveningPassed) {
        await _plugin.zonedSchedule(
          _eveningId,
          _eveningTitle,
          eveningBody,
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

  /// Call after HealthKit sync so tonight's tip tracks real step counts.
  static Future<void> refreshEveningAfterActivitySync(String userId) async {
    if (!await hasPermission()) return;
    final now = DateTime.now();
    final eveningPassed = now.hour > _eveningHour ||
        (now.hour == _eveningHour && now.minute >= _eveningMinute);
    if (eveningPassed) return;
    await scheduleForUser(userId);
  }

  static Future<void> _syncDeviceQuietly(String userId) async {
    try {
      if (!HealthTelemetryService.isSupported) return;
      if (!await HealthTelemetryService.hasPermission()) return;
      await HealthConnectService.syncFromDevice(userId);
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

  static String _deterministicEvening(int todaySteps, int yesterdaySteps) {
    if (todaySteps <= 0) {
      return 'Open PHA for your evening check-in — see how today compared to yesterday.';
    }
    if (yesterdaySteps <= 0) {
      return 'Today you logged $todaySteps steps. Keep building the habit — open PHA for your full check-in.';
    }
    if (todaySteps >= yesterdaySteps) {
      return 'Today you logged $todaySteps steps, up from yesterday\'s $yesterdaySteps. Nice progress — keep it going.';
    }
    return 'You slipped today with $todaySteps steps, down from yesterday\'s $yesterdaySteps. '
        'Let\'s get moving again tomorrow; even a short walk helps.';
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

  static Future<String> _generateMorningAdvice(String userId) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dayData = await _dayHealthReport(userId, yesterday);
    final profile = await AiConsultationService.buildFullPatientContext(userId);

    final prompt =
        'You are Ai Doc in the PHA app. Write the body of a SHORT morning push '
        'notification (max 40 words, 2 short sentences). '
        'MUST mention: (1) yesterday\'s steps vs ${MedicalGuidelines.stepsGoal} goal, '
        '(2) yesterday\'s TOTAL meal calories eaten (number), '
        '(3) one concrete nutrition tip for TODAY. '
        'No greeting, no quotes.\n\n'
        'Patient context:\n$profile\n\n'
        'Yesterday (${_dateLabel(yesterday)}):\n$dayData';

    return ApiClient.chat(userId: userId, message: prompt, complexity: 'simple');
  }

  static Future<String> _generateEveningAdvice(String userId) async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final todayData = await _dayHealthReport(userId, today);
    final yesterdayData = await _dayHealthReport(userId, yesterday);
    final profile = await AiConsultationService.buildFullPatientContext(userId);

    final prompt =
        'You are Ai Doc in the PHA app. Write the body of a SHORT evening push '
        'notification (max 35 words, 1–2 sentences). '
        'Compare TODAY vs YESTERDAY: steps, meals, activity. '
        'Did the patient improve or slip? One encouraging or corrective tip. '
        'No greeting, no quotes.\n\n'
        'Patient context:\n$profile\n\n'
        'Today (${_dateLabel(today)}):\n$todayData\n\n'
        'Yesterday (${_dateLabel(yesterday)}):\n$yesterdayData';

    return ApiClient.chat(userId: userId, message: prompt, complexity: 'simple');
  }

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<String> _dayHealthReport(String userId, DateTime day) async {
    final db = Db.instance.raw;
    final localStart = DateTime(day.year, day.month, day.day);
    final localEnd = localStart.add(const Duration(days: 1));

    final metrics = await db.query(
      'health_metrics',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recorded_at DESC',
    );

    final dayMetrics = <String, double>{};
    for (final m in metrics) {
      final recorded = DateTime.parse(m['recorded_at'] as String).toLocal();
      if (recorded.isBefore(localStart) || !recorded.isBefore(localEnd)) continue;
      final type = m['metric_type'] as String;
      final value = (m['value'] as num).toDouble();
      // Steps/distance/calories: keep the peak reading for the day (syncs climb).
      if (type == 'steps' || type == 'distance' || type == 'calories') {
        final prev = dayMetrics[type];
        if (prev == null || value > prev) dayMetrics[type] = value;
      } else {
        dayMetrics.putIfAbsent(type, () => value);
      }
    }

    final meals = await db.query(
      'meal_calorie_checks',
      where: 'user_id = ? AND confirmed = 1',
      whereArgs: [userId],
      orderBy: 'checked_at DESC',
    );
    final dayMeals = <String>[];
    var mealKcalTotal = 0;
    for (final m in meals) {
      final at = DateTime.parse(m['checked_at'] as String).toLocal();
      if (at.isBefore(localStart) || !at.isBefore(localEnd)) continue;
      final kcal = (m['calories'] as num?)?.toInt();
      if (kcal != null) mealKcalTotal += kcal;
      final cat = m['category_label'] ?? m['category'];
      final name = (m['meal_name'] as String?)?.trim();
      final label = (name != null && name.isNotEmpty)
          ? name
          : _clip(m['analysis'] as String, 80);
      dayMeals.add(
        '$label — $cat${kcal != null ? ', $kcal kcal' : ''}',
      );
    }

    final buf = StringBuffer();
    if (dayMetrics.isEmpty) {
      buf.writeln('- No activity metrics logged this day.');
    } else {
      for (final e in dayMetrics.entries) {
        buf.writeln('- ${e.key}: ${e.value}');
      }
    }
    if (dayMeals.isEmpty) {
      buf.writeln('- Meals eaten: none confirmed.');
      buf.writeln('- Total meal calories eaten: 0 kcal');
    } else {
      buf.writeln('- Meals eaten (${dayMeals.length}), total: $mealKcalTotal kcal');
      for (final meal in dayMeals) {
        buf.writeln('  · $meal');
      }
    }
    return buf.toString();
  }

  static Future<void> ensureTodayContent(String userId) async {
    // Only ensure OS schedules exist; inbox shows delivered items only.
    await scheduleForUser(userId);
  }

  /// Notifications that already fired today (not future / scheduled ones).
  static Future<List<DailyNotificationItem>> todayForUser(String userId) async {
    final tips = await _aiTipsForUser(userId);
    final treatment = await _treatmentReminders(userId);
    final activity = await _activityCheckinReminder(userId);
    final all = [...tips, ...treatment, ...activity]
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
    return _itemsFromBodies(morning, evening);
  }

  static Future<List<DailyNotificationItem>> _treatmentReminders(String userId) async {
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
        final doseLabel = doses > 1 ? 'Dose ${i + 1} of $doses — ' : '';
        reminders.add(DailyNotificationItem(
          id: 'treatment-$itemId-$i',
          title: 'Medication: $name',
          body: '${doseLabel}Take $name',
          hour: hour,
          minute: minute,
        ));
      }
    }
    return reminders;
  }

  static Future<List<DailyNotificationItem>> _activityCheckinReminder(
      String userId) async {
    if (!Db.instance.isReady) return [];
    final rows = await Db.instance.raw.query(
      'physical_activity_programs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return [];
    final label = rows.first['program_label'] as String? ?? 'your program';
    return [
      DailyNotificationItem(
        id: 'activity-checkin',
        title: 'Physical activity check-in',
        body: 'Did you complete $label today?',
        hour: 20,
        minute: 0,
      ),
    ];
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
    final items = _itemsFromBodies(morningBody, eveningBody);
    await prefs.setString(
      'daily_notif_log_$userId',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static List<DailyNotificationItem> _itemsFromBodies(
    String morningBody,
    String eveningBody,
  ) =>
      [
        DailyNotificationItem(
          id: 'morning',
          title: _morningTitle,
          body: morningBody,
          hour: _morningHour,
          minute: _morningMinute,
        ),
        DailyNotificationItem(
          id: 'evening',
          title: _eveningTitle,
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

  String _answerLabel(String status) {
    switch (status) {
      case 'yes':
        return 'Yes';
      case 'no':
        return 'No';
      case 'partially':
        return 'Partial';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      title: "Today's notifications",
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
                        'No notifications for today yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: C.gray500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Notifications that already arrived today appear here.',
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
    final isTreatment = item.id.startsWith('treatment-');
    final isActivity = item.id == 'activity-checkin';
    final icon = isActivity
        ? Icons.fitness_center_outlined
        : isTreatment
            ? Icons.medication_outlined
            : item.id == 'morning'
                ? Icons.wb_sunny_outlined
                : Icons.nights_stay_outlined;
    final iconColor = isActivity
        ? C.emerald600
        : isTreatment
            ? C.teal700
            : item.id == 'morning'
                ? C.amber700
                : C.blue600;
    final iconBg = isActivity
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
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: C.gray900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActivity ? 'Daily' : item.timeLabel,
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
                  'Saved: ${_answerLabel(activityAnswer!)} — Health Index updated',
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
                      label: 'Yes',
                      color: C.teal600,
                      onTap: () => _answerActivity('yes'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActivityAnswerChip(
                      label: 'No',
                      color: C.gray700,
                      outlined: true,
                      onTap: () => _answerActivity('no'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActivityAnswerChip(
                      label: 'Partial',
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
