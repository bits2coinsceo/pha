import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _iosAuthKey = 'health_telemetry_authorized';

class DeviceTelemetrySnapshot {
  final int steps;
  final double distanceMeters;

  const DeviceTelemetrySnapshot({
    required this.steps,
    required this.distanceMeters,
  });
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

  static Future<bool> hasPermission() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    // iOS never confirms READ access — Apple returns null for privacy reasons.
    if (Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_iosAuthKey) ?? false;
    }
    final permitted = await _health.hasPermissions(_types, permissions: _permissions);
    return permitted ?? false;
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    // iOS 26+: calling requestAuthorization again after the user already
    // decided can present a blank undismissable sheet (looks like a white
    // screen). Skip the system prompt if we already asked once.
    if (Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_iosAuthKey) ?? false) {
        return true;
      }
    }
    try {
      final granted =
          await _health.requestAuthorization(_types, permissions: _permissions);
      if (granted && Platform.isIOS) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_iosAuthKey, true);
      }
      return granted;
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

    final steps = await _health.getTotalStepsInInterval(start, end) ?? 0;

    var distanceMeters = 0.0;
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

    return DeviceTelemetrySnapshot(
      steps: steps,
      distanceMeters: distanceMeters,
    );
  }
}
