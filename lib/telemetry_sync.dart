import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'health_telemetry.dart';
import 'services.dart';

/// Background telemetry sync: permission after sign-up, on app open, and live polling.
class TelemetrySyncService {
  TelemetrySyncService._();

  static Timer? _liveTimer;
  static bool _tickInFlight = false;
  static String? _liveUserId;
  static VoidCallback? _onDataChanged;

  static String _needsPromptKey(String userId) => 'telemetry_needs_prompt_$userId';
  static String _promptAttemptedKey(String userId) => 'telemetry_prompt_attempted_$userId';

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
      await prefs.setBool(_promptAttemptedKey(userId), true);
      await prefs.setBool(_needsPromptKey(userId), false);
    }

    if (!await HealthTelemetryService.hasPermission()) return false;

    try {
      return await HealthConnectService.syncFromDevice(userId);
    } catch (_) {
      return false;
    }
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
      if (changed) notify();
    } catch (_) {
      // Ignore transient HealthKit errors; next tick retries.
    } finally {
      _tickInFlight = false;
    }
  }
}
