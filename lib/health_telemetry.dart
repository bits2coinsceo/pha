import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set only after the system Health permission sheet was actually presented.
/// v2: older builds set `health_telemetry_authorized` on empty reads, which
/// blocked the sheet forever — bump so affected installs get one real prompt.
const _iosPromptShownKey = 'health_telemetry_prompt_shown_v2';

/// Soft evidence that HealthKit READ for steps/distance works (saw non-zero data).
const _iosReadEvidenceKey = 'health_telemetry_read_evidence';

class DeviceTelemetrySnapshot {
  final int steps;
  final double distanceMeters;

  const DeviceTelemetrySnapshot({
    required this.steps,
    required this.distanceMeters,
  });

  bool get hasActivity => steps > 0 || distanceMeters >= 1;
}

/// Reads steps and walking/running distance from Apple Health (iOS) or
/// Health Connect (Android).
class HealthTelemetryService {
  HealthTelemetryService._();

  static final Health _health = Health();
  static bool _configured = false;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// True when we believe activity reads are allowed.
  ///
  /// iOS never confirms READ grants — Apple returns null for privacy reasons.
  /// We treat "prompt shown" or "saw real data" as soft permission.
  static Future<bool> hasPermission() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    if (Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getBool(_iosPromptShownKey) ?? false) ||
          (prefs.getBool(_iosReadEvidenceKey) ?? false);
    }
    final permitted =
        await _health.hasPermissions(_types, permissions: _permissions);
    return permitted ?? false;
  }

  /// Whether we have ever observed non-zero steps/distance from HealthKit.
  static Future<bool> hasReadEvidence() async {
    if (!isSupported) return false;
    if (Platform.isAndroid) return hasPermission();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_iosReadEvidenceKey) ?? false;
  }

  /// Whether the iOS Health activity permission sheet was shown (v2 key).
  static Future<bool> wasPromptShown() async {
    if (!isSupported) return false;
    if (Platform.isAndroid) return hasPermission();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_iosPromptShownKey) ?? false;
  }

  /// Called after a combined Health sheet that included activity types.
  static Future<void> markPromptShown() async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_iosPromptShownKey, true);
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    // iOS 26+: calling requestAuthorization again after the user already
    // decided can present a blank undismissable sheet (looks like a white
    // screen). Skip the system prompt if we already asked once (v2 key).
    if (Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_iosPromptShownKey) ?? false) {
        return true;
      }
    }
    try {
      final granted =
          await _health.requestAuthorization(_types, permissions: _permissions);
      if (Platform.isIOS) {
        final prefs = await SharedPreferences.getInstance();
        // Mark the sheet as shown regardless of the boolean — iOS often returns
        // true even when the user denied individual read types.
        await prefs.setBool(_iosPromptShownKey, true);
      }
      return granted || Platform.isIOS;
    } catch (e) {
      debugPrint('HealthTelemetryService.requestPermission failed: $e');
      return false;
    }
  }

  static Future<DeviceTelemetrySnapshot?> fetchToday() async {
    final now = DateTime.now();
    return fetchForDay(DateTime(now.year, now.month, now.day));
  }

  /// Steps + walking distance for a local calendar [day] (00:00 → next midnight).
  /// For today, the end bound is [DateTime.now] so totals stay live.
  static Future<DeviceTelemetrySnapshot?> fetchForDay(DateTime day) async {
    if (!isSupported) return null;
    await _ensureConfigured();
    if (Platform.isAndroid && !await hasPermission()) return null;

    final start = DateTime(day.year, day.month, day.day);
    final dayEnd = start.add(const Duration(days: 1));
    final now = DateTime.now();
    final end = dayEnd.isAfter(now) ? now : dayEnd;
    if (!end.isAfter(start)) {
      return const DeviceTelemetrySnapshot(steps: 0, distanceMeters: 0);
    }

    var steps = 0;
    try {
      steps = await _health.getTotalStepsInInterval(start, end) ?? 0;
    } catch (e) {
      debugPrint('HealthTelemetryService getTotalStepsInInterval failed: $e');
    }
    // Fallback: sum discrete step samples when the aggregate query is empty
    // (seen after HealthKit re-auth or delayed Watch sync).
    if (steps <= 0) {
      try {
        final stepPoints = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: start,
          endTime: end,
        );
        var sum = 0.0;
        for (final point in stepPoints) {
          if (point.type != HealthDataType.STEPS) continue;
          final value = point.value;
          if (value is NumericHealthValue) {
            sum += value.numericValue.toDouble();
          }
        }
        if (sum > 0) steps = sum.round();
      } catch (e) {
        debugPrint('HealthTelemetryService steps fallback failed: $e');
      }
    }

    var distanceMeters = 0.0;
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_WALKING_RUNNING],
        startTime: start,
        endTime: end,
      );
      for (final point in points) {
        if (point.type != HealthDataType.DISTANCE_WALKING_RUNNING) continue;
        final value = point.value;
        if (value is NumericHealthValue) {
          distanceMeters += value.numericValue.toDouble();
        }
      }
    } catch (e) {
      debugPrint('HealthTelemetryService distance read failed: $e');
    }

    final snapshot = DeviceTelemetrySnapshot(
      steps: steps,
      distanceMeters: distanceMeters,
    );

    // Only record evidence when HealthKit returns real activity — never mark
    // "authorized" on an empty/denied read (that permanently blocked the sheet).
    if (Platform.isIOS && snapshot.hasActivity) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_iosReadEvidenceKey) ?? false)) {
        await prefs.setBool(_iosReadEvidenceKey, true);
      }
      if (!(prefs.getBool(_iosPromptShownKey) ?? false)) {
        await prefs.setBool(_iosPromptShownKey, true);
      }
    }

    return snapshot;
  }
}
