import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'auth.dart';
import 'daily_notifications.dart';
import 'db.dart';
import 'locale_controller.dart';

/// One-shot reminders before the 24h install trial ends.
class TrialNotificationService {
  TrialNotificationService._();

  static const _sixHoursId = 4001;
  static const _oneHourId = 4002;

  /// Schedules −6h and −1h trial-ending pushes, or cancels if Plus+.
  static Future<void> scheduleForUser(String userId) async {
    if (kIsWeb) return;
    if (!DailyNotificationService.isInitialized) {
      await DailyNotificationService.init();
    }
    if (!await DailyNotificationService.hasPermission()) {
      final granted = await DailyNotificationService.requestPermission();
      if (!granted) return;
    }

    final rows = await Db.instance.raw.query(
      'profiles',
      columns: ['is_plus', 'created_at'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final isPlus = (rows.first['is_plus'] as int?) == 1;
    if (isPlus) {
      await cancelAll();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final installRaw = prefs.getString('pha_install_trial_started_at');
    final start = DateTime.tryParse(installRaw ?? '')?.toUtc() ??
        DateTime.tryParse(rows.first['created_at'] as String? ?? '')?.toUtc();
    if (start == null) return;

    final trialEnd = start.add(freeTrialDuration);
    if (!DateTime.now().toUtc().isBefore(trialEnd)) {
      await cancelAll();
      return;
    }

    final l10n = await LocaleController.loadLocalizations();
    final plugin = DailyNotificationService.plugin;
    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.active,
      ),
      android: AndroidNotificationDetails(
        'pha_trial',
        l10n.trialNotifChannelName,
        channelDescription: l10n.trialNotifChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
      ),
    );

    await plugin.cancel(_sixHoursId);
    await plugin.cancel(_oneHourId);

    await _scheduleOneShot(
      plugin: plugin,
      id: _sixHoursId,
      title: l10n.trialNotifSixHoursTitle,
      body: l10n.trialNotifSixHoursBody,
      fireAtUtc: trialEnd.subtract(const Duration(hours: 6)),
      details: details,
    );
    await _scheduleOneShot(
      plugin: plugin,
      id: _oneHourId,
      title: l10n.trialNotifOneHourTitle,
      body: l10n.trialNotifOneHourBody,
      fireAtUtc: trialEnd.subtract(const Duration(hours: 1)),
      details: details,
    );
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      if (!DailyNotificationService.isInitialized) {
        await DailyNotificationService.init();
      }
      final plugin = DailyNotificationService.plugin;
      await plugin.cancel(_sixHoursId);
      await plugin.cancel(_oneHourId);
      // Legacy 7-day trial ids.
      await plugin.cancel(4001);
      await plugin.cancel(4002);
    } catch (e, st) {
      debugPrint('TrialNotificationService.cancelAll failed: $e\n$st');
    }
  }

  static Future<void> _scheduleOneShot({
    required FlutterLocalNotificationsPlugin plugin,
    required int id,
    required String title,
    required String body,
    required DateTime fireAtUtc,
    required NotificationDetails details,
  }) async {
    final local = tz.TZDateTime.from(fireAtUtc.toLocal(), tz.local);
    if (!local.isAfter(tz.TZDateTime.now(tz.local))) return;
    try {
      await plugin.zonedSchedule(
        id,
        title,
        body,
        local,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'trial_reminder',
      );
    } catch (e, st) {
      debugPrint(
        'TrialNotificationService schedule id=$id failed: $e\n$st',
      );
    }
  }
}
