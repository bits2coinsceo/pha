import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_notifications.dart';
import 'treatment_schedule.dart';

/// Repeating local notifications for medication / supplement dose times.
class TreatmentNotificationService {
  TreatmentNotificationService._();

  static const _idBase = 3000;
  static const _prefsKey = 'treatment_notif_ids';

  static const _details = NotificationDetails(
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      sound: 'Medication.mp3',
      interruptionLevel: InterruptionLevel.active,
    ),
    android: AndroidNotificationDetails(
      'pha_treatment_med',
      'Medication reminders',
      channelDescription: 'Reminders to take medicines and supplements on time',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('medication'),
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
    ),
  );

  static int _notifId(String itemId, int doseIndex) =>
      _idBase + (Object.hash(itemId, doseIndex).abs() % 17000);

  /// Cancels stale reminders and schedules one repeating alert per dose time.
  static Future<void> rescheduleForUser(String userId) async {
    if (kIsWeb) return;
    if (!await DailyNotificationService.ensureReady()) return;
    if (!await DailyNotificationService.hasPermission()) return;

    final plugin = DailyNotificationService.plugin;
    for (final id in await _loadIds(userId)) {
      await plugin.cancel(id);
    }

    final items = await TreatmentScheduleService.list(userId);
    final scheduledIds = <int>[];

    for (final item in items) {
      for (var i = 0; i < item.doseTimes.length; i++) {
        final dose = item.doseTimes[i];
        final notifId = _notifId(item.id, i);
        final doseLabel =
            item.dosesPerDay > 1 ? ' — dose ${i + 1} of ${item.dosesPerDay}' : '';
        final title = 'Time to take your medication';
        final body = 'Take ${item.name}$doseLabel';

        try {
          await plugin.zonedSchedule(
            notifId,
            title,
            body,
            DailyNotificationService.scheduledTodayOrTomorrow(dose.hour, dose.minute),
            _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: jsonEncode({
              'type': 'treatment',
              'itemId': item.id,
              'dose': i,
              'name': item.name,
            }),
          );
          scheduledIds.add(notifId);
        } catch (e, st) {
          debugPrint('TreatmentNotificationService.schedule failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }
    }

    await _saveIds(userId, scheduledIds);
    debugPrint(
        'TreatmentNotificationService: ${scheduledIds.length} dose reminders scheduled');
  }

  static Future<bool> ensurePermission() async {
    if (await DailyNotificationService.hasPermission()) return true;
    return DailyNotificationService.requestPermission();
  }

  static Future<List<int>> _loadIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_prefsKey}_$userId');
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
  }

  static Future<void> _saveIds(String userId, List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefsKey}_$userId', jsonEncode(ids));
  }
}
