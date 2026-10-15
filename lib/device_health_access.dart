import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import 'health_telemetry.dart';
import 'heart_rate_service.dart';
import 'services.dart';

/// Result of an in-app Health / Health Connect access check or request.
enum HealthAccessOutcome {
  /// System permission sheet was shown (or Android grant flow ran).
  prompted,

  /// Access already looks granted — no system UI needed.
  alreadyGranted,

  /// Access updated and a sync was attempted.
  synced,

  unsupported,
  failed,
}

/// Profile + post-auth Health / Health Connect access.
///
/// Never opens the iPhone Health app or system Settings from these APIs —
/// only checks status and, when needed, shows the OS permission sheet.
class DeviceHealthAccess {
  DeviceHealthAccess._();

  static final Health _health = Health();
  static bool _configured = false;

  static bool get isSupported => HealthTelemetryService.isSupported;

  /// Platform-safe READ types — one sheet covers activity + heart (+ ECG on iOS).
  static List<HealthDataType> get _allTypes {
    final types = <HealthDataType>[
      HealthDataType.STEPS,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.WALKING_HEART_RATE,
      HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    ];
    if (Platform.isIOS) {
      types.addAll([
        HealthDataType.IRREGULAR_HEART_RATE_EVENT,
        HealthDataType.ELECTROCARDIOGRAM,
      ]);
    }
    return types;
  }

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure().timeout(const Duration(seconds: 5));
    _configured = true;
  }

  static Future<bool> activityAccessLikely() async {
    if (!isSupported) return false;
    if (await HealthTelemetryService.hasReadEvidence()) return true;
    return HealthTelemetryService.hasPermission();
  }

  static Future<bool> heartAccessLikely() async {
    if (!HeartRateService.isSupported) return false;
    return HeartRateService.hasPermission();
  }

  static Future<bool> allAccessLikely() async {
    return await activityAccessLikely() && await heartAccessLikely();
  }

  /// Single HealthKit / Health Connect sheet for steps, distance, HR, HRV, ECG.
  ///
  /// Safe to call right after sign-in / sign-up. If already prompted, returns
  /// [HealthAccessOutcome.alreadyGranted] without leaving the app.
  static Future<HealthAccessOutcome> requestAllPermissionsCombined() async {
    if (!isSupported) return HealthAccessOutcome.unsupported;
    try {
      await _ensureConfigured();
      if (await allAccessLikely()) {
        return HealthAccessOutcome.alreadyGranted;
      }

      final types = _allTypes;
      final permissions = List<HealthDataAccess>.filled(
        types.length,
        HealthDataAccess.READ,
      );
      final granted = await _health
          .requestAuthorization(types, permissions: permissions)
          .timeout(const Duration(seconds: 60));

      await HealthTelemetryService.markPromptShown();
      await HeartRateService.markPromptShown(includeEcg: Platform.isIOS);

      return (granted || Platform.isIOS)
          ? HealthAccessOutcome.prompted
          : HealthAccessOutcome.failed;
    } catch (e) {
      debugPrint('DeviceHealthAccess.requestAllPermissionsCombined: $e');
      if (Platform.isIOS) {
        await HealthTelemetryService.markPromptShown();
        await HeartRateService.markPromptShown(includeEcg: true);
      }
      return HealthAccessOutcome.failed;
    }
  }

  /// Check / request steps + distance. Never opens Health settings.
  static Future<HealthAccessOutcome> requestActivityAccess({
    String? userId,
  }) async {
    if (!HealthTelemetryService.isSupported) {
      return HealthAccessOutcome.unsupported;
    }
    try {
      if (await activityAccessLikely()) {
        if (userId != null) await _syncActivity(userId, light: true);
        return HealthAccessOutcome.alreadyGranted;
      }
      final outcome = await requestAllPermissionsCombined();
      if (userId != null) await _syncActivity(userId, light: true);
      if (await activityAccessLikely()) {
        return outcome == HealthAccessOutcome.prompted
            ? HealthAccessOutcome.prompted
            : HealthAccessOutcome.alreadyGranted;
      }
      return outcome;
    } catch (e) {
      debugPrint('DeviceHealthAccess.requestActivityAccess: $e');
      return HealthAccessOutcome.failed;
    }
  }

  /// Check / request heart Health types. Never opens Health settings.
  static Future<HealthAccessOutcome> requestHeartAccess({
    String? userId,
  }) async {
    if (!HeartRateService.isSupported) {
      return HealthAccessOutcome.unsupported;
    }
    try {
      if (await heartAccessLikely()) {
        if (userId != null) {
          await HeartRateService.syncQuietly(
            userId,
            force: true,
            includeEcg: false,
          );
        }
        return HealthAccessOutcome.alreadyGranted;
      }
      final outcome = await requestAllPermissionsCombined();
      if (userId != null) {
        await HeartRateService.syncQuietly(
          userId,
          force: true,
          includeEcg: false,
        );
      }
      if (await heartAccessLikely()) {
        return outcome == HealthAccessOutcome.prompted
            ? HealthAccessOutcome.prompted
            : HealthAccessOutcome.alreadyGranted;
      }
      return outcome;
    } catch (e) {
      debugPrint('DeviceHealthAccess.requestHeartAccess: $e');
      return HealthAccessOutcome.failed;
    }
  }

  /// Check all access; request missing types in-app only (no Health app jump).
  static Future<HealthAccessOutcome> requestMissingAccess({
    required String userId,
  }) async {
    if (!isSupported) return HealthAccessOutcome.unsupported;
    if (await allAccessLikely()) {
      await _fastSync(userId);
      return HealthAccessOutcome.alreadyGranted;
    }
    final outcome = await requestAllPermissionsCombined();
    await _fastSync(userId);
    if (await allAccessLikely()) {
      return outcome == HealthAccessOutcome.prompted
          ? HealthAccessOutcome.prompted
          : HealthAccessOutcome.alreadyGranted;
    }
    return outcome;
  }

  static Future<void> _fastSync(String userId) async {
    await Future.wait([
      _syncActivity(userId, light: true),
      HeartRateService.syncQuietly(userId, force: true, includeEcg: false)
          .then((_) {}, onError: (_) {}),
    ]);
  }

  static Future<void> _syncActivity(String userId, {bool light = false}) async {
    try {
      await HealthConnectService.syncFromDevice(userId, light: light);
    } catch (_) {}
  }
}
