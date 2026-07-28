import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import 'daily_notifications.dart';
import 'db.dart';
import 'health_index.dart';
import 'theme.dart';
import 'widgets.dart';

const _uuid = Uuid();

/// Active physical-activity program + daily 20:00 Europe check-in.
class PhysicalActivityService {
  PhysicalActivityService._();

  static const notifId = 2003;
  static const checkHour = 20;
  static const checkMinute = 0;
  /// Europe Standard / Central European time (CET/CEST).
  static const europeTzName = 'Europe/Berlin';

  static tz.Location get _europe {
    try {
      return tz.getLocation(europeTzName);
    } catch (_) {
      return tz.local;
    }
  }

  static tz.TZDateTime nowEurope() => tz.TZDateTime.now(_europe);

  static String europeDateKey([tz.TZDateTime? when]) {
    final d = when ?? nowEurope();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, dynamic>?> activeProgram(String userId) async {
    if (!Db.instance.isReady) return null;
    final rows = await Db.instance.raw.query(
      'physical_activity_programs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<bool> hasCheckinToday(String userId) async {
    return (await todaysCheckinStatus(userId)) != null;
  }

  /// Today's answer: `yes` | `no` | `partially`, or null if unanswered.
  static Future<String?> todaysCheckinStatus(String userId) async {
    if (!Db.instance.isReady) return null;
    final rows = await Db.instance.raw.query(
      'physical_activity_checkins',
      columns: ['status'],
      where: 'user_id = ? AND checkin_date = ?',
      whereArgs: [userId, europeDateKey()],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['status'] as String?;
  }

  /// Prompt after 20:00 Europe time if a program is active and today is unanswered.
  static Future<bool> shouldPromptCheckin(String userId) async {
    final program = await activeProgram(userId);
    if (program == null) return false;
    final now = nowEurope();
    if (now.hour < checkHour) return false;
    return !(await hasCheckinToday(userId));
  }

  /// Persists today's check-in (upsert) and recalculates Health Index.
  /// Status: `yes` | `no` | `partially`.
  static Future<void> saveCheckin({
    required String userId,
    required String status, // yes | no | partially
  }) async {
    final program = await activeProgram(userId);
    if (program == null) return;
    final date = europeDateKey();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final existing = await Db.instance.raw.query(
      'physical_activity_checkins',
      columns: ['id'],
      where: 'user_id = ? AND checkin_date = ?',
      whereArgs: [userId, date],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await Db.instance.raw.update(
        'physical_activity_checkins',
        {
          'status': status,
          'program_id': program['program_id'],
          'program_label': program['program_label'],
          'created_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await Db.instance.raw.insert('physical_activity_checkins', {
        'id': _uuid.v4(),
        'user_id': userId,
        'program_id': program['program_id'],
        'program_label': program['program_label'],
        'status': status,
        'checkin_date': date,
        'created_at': nowIso,
      });
    }
    await HealthIndexService.recalculate(userId);
  }

  /// Daily repeating reminder at 20:00 Europe/Berlin.
  static Future<void> scheduleEveningReminder(String userId) async {
    if (kIsWeb) return;
    if (!await DailyNotificationService.ensureReady()) return;
    if (!await DailyNotificationService.hasPermission()) return;

    final program = await activeProgram(userId);
    final plugin = DailyNotificationService.plugin;
    await plugin.cancel(notifId);
    if (program == null) return;

    final label = program['program_label'] as String? ?? 'your program';
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        sound: 'default',
        // Avoid .timeSensitive — requires a paid entitlement; can crash open on device.
        interruptionLevel: InterruptionLevel.active,
      ),
      android: AndroidNotificationDetails(
        'pha_activity',
        'Physical activity check-in',
        channelDescription: 'Daily reminder to log whether you completed your workout',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
      ),
    );

    try {
      await plugin.zonedSchedule(
        notifId,
        'Physical activity check-in',
        'Did you complete $label today?',
        _nextEuropeTime(checkHour, checkMinute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'physical_activity_checkin',
      );
      debugPrint('PhysicalActivityService: evening check-in scheduled (20:00 Europe/Berlin)');
    } catch (e, st) {
      debugPrint('PhysicalActivityService.scheduleEveningReminder failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  static tz.TZDateTime _nextEuropeTime(int hour, int minute) {
    final now = nowEurope();
    var scheduled = tz.TZDateTime(
      _europe,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// In-app Yes / No / Partially prompt for today's workout.
class PhysicalActivityCheckinDialog extends StatefulWidget {
  final String userId;
  final String programLabel;

  const PhysicalActivityCheckinDialog({
    super.key,
    required this.userId,
    required this.programLabel,
  });

  @override
  State<PhysicalActivityCheckinDialog> createState() =>
      _PhysicalActivityCheckinDialogState();
}

class _PhysicalActivityCheckinDialogState
    extends State<PhysicalActivityCheckinDialog> {
  bool saving = false;

  Future<void> _answer(String status) async {
    setState(() => saving = true);
    await PhysicalActivityService.saveCheckin(
      userId: widget.userId,
      status: status,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      title: 'Physical activity today',
      onClose: () => Navigator.pop(context, false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Did you complete ${widget.programLabel} today?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: C.gray900,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your answer is saved to your health history.',
            style: TextStyle(fontSize: 13, color: C.gray500, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (saving)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            PrimaryButton(
              label: 'Yes',
              color: C.teal600,
              onPressed: () => _answer('yes'),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Partial',
              color: C.blue600,
              onPressed: () => _answer('partially'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _answer('no'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: C.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'No',
                style: TextStyle(fontWeight: FontWeight.w600, color: C.gray700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
