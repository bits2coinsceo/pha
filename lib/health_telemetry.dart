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
    final granted =
        await _health.requestAuthorization(_types, permissions: _permissions);
    if (granted && Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_iosAuthKey, true);
    }
    return granted;
  }

  static Future<DeviceTelemetrySnapshot?> fetchToday() async {
    if (!isSupported) return null;
    await _ensureConfigured();
    if (Platform.isAndroid && !await hasPermission()) return null;

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    final steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;

    var distanceMeters = 0.0;
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.DISTANCE_WALKING_RUNNING],
      startTime: midnight,
      endTime: now,
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
