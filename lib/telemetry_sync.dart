import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'health_telemetry.dart';
import 'daily_notifications.dart';
import 'physical_activity.dart';
import 'services.dart';
import 'treatment_notifications.dart';

/// Background telemetry sync: permission after sign-up, on app open, and live polling.
class TelemetrySyncService {
  TelemetrySyncService._();

  static Timer? _liveTimer;
  static bool _tickInFlight = false;
  static String? _liveUserId;
  static VoidCallback? _onDataChanged;

  static String _needsPromptKey(String userId) => 'telemetry_needs_prompt_$userId';
  static String _promptAttemptedKey(String userId) => 'telemetry_prompt_attempted_$userId';
  static String _notifPromptKey(String userId) => 'notif_prompt_attempted_$userId';

  /// Call once when a new account is created.
  static Future<void> markNeedsPromptAfterSignUp(String userId) async {
    if (!HealthTelemetryService.isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_needsPromptKey(userId), true);
  }

  /// Runs on app open / resume. Returns true if dashboard data should refresh.
  static Future<bool> onAppOpen(String userId) async {
    if (!HealthTelemetryService.isSupported) return false;

    final prefs = await SharedPreferences.getInstance();
    final needsPrompt = prefs.getBool(_needsPromptKey(userId)) ?? false;
    final attempted = prefs.getBool(_promptAttemptedKey(userId)) ?? false;

    if (needsPrompt && !attempted) {
      await HealthTelemetryService.requestPermission();
      await DailyNotificationService.requestPermission();
      await prefs.setBool(_promptAttemptedKey(userId), true);
      await prefs.setBool(_needsPromptKey(userId), false);
      await prefs.setBool(_notifPromptKey(userId), true);
    } else if (!(prefs.getBool(_notifPromptKey(userId)) ?? false)) {
      await DailyNotificationService.requestPermission();
      await prefs.setBool(_notifPromptKey(userId), true);
    }

    var synced = false;
    if (await HealthTelemetryService.hasPermission()) {
      try {
        synced = await HealthConnectService.syncFromDevice(userId);
      } catch (_) {
        synced = false;
      }
    }

    if (await DailyNotificationService.hasPermission()) {
      // Always (re)schedule after sync so evening copy uses real steps.
      unawaited(DailyNotificationService.scheduleForUser(userId));
      unawaited(TreatmentNotificationService.rescheduleForUser(userId));
      unawaited(PhysicalActivityService.scheduleEveningReminder(userId));
    }

    return synced;
  }

  /// Polls Apple Health / Health Connect every second while the app is active.
  static void startLiveSync(String userId, VoidCallback onDataChanged) {
    if (!HealthTelemetryService.isSupported) return;
    stopLiveSync();
    _liveUserId = userId;
    _onDataChanged = onDataChanged;
    _liveTick();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) => _liveTick());
  }

  static void stopLiveSync() {
    _liveTimer?.cancel();
    _liveTimer = null;
    _liveUserId = null;
    _onDataChanged = null;
  }

  static Future<void> _liveTick() async {
    final userId = _liveUserId;
    final notify = _onDataChanged;
    if (userId == null || notify == null || _tickInFlight) return;
    _tickInFlight = true;
    try {
      if (!await HealthTelemetryService.hasPermission()) return;
      final changed = await HealthConnectService.syncFromDevice(userId);
      if (changed) {
        unawaited(
          DailyNotificationService.refreshEveningAfterActivitySync(userId),
        );
        notify();
      }
    } catch (_) {
      // Ignore transient HealthKit errors; next tick retries.
    } finally {
      _tickInFlight = false;
    }
  }
}
