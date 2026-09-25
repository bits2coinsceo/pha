import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'auth.dart';
import 'daily_notifications.dart';
import 'db.dart';
import 'locale_controller.dart';

/// One-shot reminders before the 7-day free trial ends.
class TrialNotificationService {
  TrialNotificationService._();

  static const _threeDaysId = 4001;
  static const _twentyFourHoursId = 4002;

  /// Schedules −3 day and −24 hour trial-ending pushes, or cancels if Plus+.
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

    final createdAt =
        DateTime.tryParse(rows.first['created_at'] as String? ?? '');
    if (createdAt == null) return;

    final trialEnd =
        createdAt.toUtc().add(const Duration(days: freeTrialDays));
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

    await plugin.cancel(_threeDaysId);
    await plugin.cancel(_twentyFourHoursId);

    final threeDaysBefore = trialEnd.subtract(const Duration(days: 3));
    final twentyFourHoursBefore =
        trialEnd.subtract(const Duration(hours: 24));

    await _scheduleOneShot(
      plugin: plugin,
      id: _threeDaysId,
      title: l10n.trialNotifThreeDaysTitle,
      body: l10n.trialNotifThreeDaysBody,
      fireAtUtc: threeDaysBefore,
      details: details,
    );
    await _scheduleOneShot(
      plugin: plugin,
      id: _twentyFourHoursId,
      title: l10n.trialNotifTwentyFourHoursTitle,
      body: l10n.trialNotifTwentyFourHoursBody,
      fireAtUtc: twentyFourHoursBefore,
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
      await plugin.cancel(_threeDaysId);
      await plugin.cancel(_twentyFourHoursId);
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
