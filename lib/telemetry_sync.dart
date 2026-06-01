import 'package:shared_preferences/shared_preferences.dart';

import 'health_telemetry.dart';
import 'services.dart';

/// Background telemetry sync: one-time permission after sign-up, then on each app open.
class TelemetrySyncService {
  TelemetrySyncService._();

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
      await HealthConnectService.syncFromDevice(userId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
