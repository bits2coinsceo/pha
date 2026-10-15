import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_health_access.dart';
import 'health_telemetry.dart';
import 'daily_notifications.dart';
import 'heart_rate_service.dart';
import 'physical_activity.dart';
import 'services.dart';
import 'treatment_notifications.dart';
import 'trial_notifications.dart';

/// Background telemetry sync: permission after auth, on app open, live polling.
class TelemetrySyncService {
  TelemetrySyncService._();

  static Timer? _liveTimer;
  static bool _tickInFlight = false;
  static String? _liveUserId;
  static VoidCallback? _onDataChanged;
  static bool _authPromptInFlight = false;

  static String _needsPromptKey(String userId) => 'telemetry_needs_prompt_$userId';
  static String _promptAttemptedKey(String userId) => 'telemetry_prompt_attempted_$userId';
  static String _notifPromptKey(String userId) => 'notif_prompt_attempted_$userId';

  /// Call once when a new account is created (flag only — prefer [promptAndSyncAfterAuth]).
  static Future<void> markNeedsPromptAfterSignUp(String userId) async {
    if (!HealthTelemetryService.isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_needsPromptKey(userId), true);
  }

  /// Call on sign-in when activity permission may never have been requested.
  static Future<void> markNeedsPromptIfNoActivityAccess(String userId) async {
    if (!HealthTelemetryService.isSupported) return;
    if (await HealthTelemetryService.hasReadEvidence()) return;
    if (await HealthTelemetryService.hasPermission()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_needsPromptKey(userId), true);
    await prefs.setBool(_promptAttemptedKey(userId), false);
  }

  /// Immediately after sign-in / sign-up: one combined Health sheet + fast sync.
  ///
  /// Does not wait for onboarding. Keeps the dashboard path light by skipping
  /// ECG / heavy index work on this first pass.
  static Future<void> promptAndSyncAfterAuth(String userId) async {
    if (!HealthTelemetryService.isSupported) return;
    if (_authPromptInFlight) return;
    _authPromptInFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await DeviceHealthAccess.requestAllPermissionsCombined();
      await prefs.setBool(_promptAttemptedKey(userId), true);
      await prefs.setBool(_needsPromptKey(userId), false);

      // Notification permission in parallel with the first data pull.
      final notifDone = prefs.getBool(_notifPromptKey(userId)) ?? false;
      final notifFuture = notifDone
          ? Future<void>.value()
          : DailyNotificationService.requestPermission().then((_) async {
              await prefs.setBool(_notifPromptKey(userId), true);
            });

      await Future.wait([
        notifFuture,
        _quickDeviceSync(userId),
      ]).timeout(
        const Duration(seconds: 14),
        onTimeout: () => const [],
      );
    } catch (e) {
      debugPrint('TelemetrySyncService.promptAndSyncAfterAuth: $e');
    } finally {
      _authPromptInFlight = false;
    }
  }

  static Future<void> _quickDeviceSync(String userId) async {
    final canSync = Platform.isIOS ||
        await HealthTelemetryService.hasPermission();
    if (!canSync) return;
    await Future.wait([
      HealthConnectService.syncFromDevice(userId, light: true)
          .then((_) {}, onError: (_) {}),
      HeartRateService.syncQuietly(userId, force: true, includeEcg: false)
          .then((_) {}, onError: (_) {}),
    ]);
  }

  /// Runs on app open / resume. Returns true if dashboard data should refresh.
  static Future<bool> onAppOpen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    var needsPrompt = prefs.getBool(_needsPromptKey(userId)) ?? false;
    final attempted = prefs.getBool(_promptAttemptedKey(userId)) ?? false;

    final needsCombinedPrompt = HealthTelemetryService.isSupported &&
        (!await HealthTelemetryService.wasPromptShown() ||
            !await HeartRateService.hasPermission());

    if (needsCombinedPrompt) {
      needsPrompt = true;
      await prefs.setBool(_needsPromptKey(userId), true);
    }

    if (HealthTelemetryService.isSupported &&
        needsPrompt &&
        (!attempted || needsCombinedPrompt)) {
      await DeviceHealthAccess.requestAllPermissionsCombined();
      if (!(prefs.getBool(_notifPromptKey(userId)) ?? false)) {
        await DailyNotificationService.requestPermission();
        await prefs.setBool(_notifPromptKey(userId), true);
      }
      await prefs.setBool(_promptAttemptedKey(userId), true);
      await prefs.setBool(_needsPromptKey(userId), false);
    } else if (!(prefs.getBool(_notifPromptKey(userId)) ?? false)) {
      unawaited(DailyNotificationService.requestPermission().then((_) async {
        await prefs.setBool(_notifPromptKey(userId), true);
      }));
    }

    var synced = false;
    if (HealthTelemetryService.isSupported) {
      final canSync = Platform.isIOS ||
          await HealthTelemetryService.hasPermission();
      if (canSync) {
        try {
          final results = await Future.wait([
            HealthConnectService.syncFromDevice(userId, light: false)
                .then((v) => v, onError: (_) => false),
            HeartRateService.isSupported
                ? HeartRateService.syncQuietly(
                    userId,
                    force: true,
                    includeEcg: true,
                  ).then((v) => v, onError: (_) => false)
                : Future<bool>.value(false),
          ]).timeout(
            const Duration(seconds: 18),
            onTimeout: () => const [false, false],
          );
          synced = results.any((v) => v);
        } catch (_) {
          synced = false;
        }
      }
    }

    // OS pushes — never block the open path.
    unawaited(DailyNotificationService.scheduleForUser(userId));
    unawaited(TreatmentNotificationService.rescheduleForUser(userId));
    unawaited(PhysicalActivityService.scheduleEveningReminder(userId));
    unawaited(TrialNotificationService.scheduleForUser(userId));

    return synced;
  }

  /// Polls Apple Health / Health Connect while the app is active.
  /// 15s keeps the dashboard fresh without thrashing HealthKit + index.
  static void startLiveSync(String userId, VoidCallback onDataChanged) {
    if (!HealthTelemetryService.isSupported) return;
    stopLiveSync();
    _liveUserId = userId;
    _onDataChanged = onDataChanged;
    _liveTick();
    _liveTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _liveTick());
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
      if (Platform.isAndroid &&
          !await HealthTelemetryService.hasPermission()) {
        return;
      }
      final changed =
          await HealthConnectService.syncFromDevice(userId, light: true);
      unawaited(
        HeartRateService.syncQuietly(userId, includeEcg: false).then((hrChanged) {
          if (hrChanged) notify();
        }),
      );
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
