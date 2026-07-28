import 'package:shared_preferences/shared_preferences.dart';

import 'db.dart';

/// How often to show the daily BP / glucose prompt.
enum VitalsPromptMode { daily, every5Days, off }

/// Tracks when BP / glucose were last logged so we only prompt once per calendar day.
class DailyVitalsService {
  static const preSignUpScope = 'pre_signup';

  /// Prevents stacked dialogs when Dashboard remounts (e.g. live sync refresh).
  static bool promptDialogOpen = false;

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _todayKey() => _dateKey(DateTime.now());

  static String _bpKey(String scope) => 'daily_vitals_bp_$scope';
  static String _glucoseKey(String scope) => 'daily_vitals_glucose_$scope';
  static String _bpPromptKey(String scope) => 'daily_vitals_bp_prompt_$scope';
  static String _glucosePromptKey(String scope) => 'daily_vitals_glucose_prompt_$scope';
  static String _modeKey(String scope) => 'daily_vitals_prompt_mode_$scope';
  static String _lastAskKey(String scope) => 'daily_vitals_last_ask_$scope';

  /// Claim today's prompt slot before showing the dialog so remounts do not re-ask.
  static Future<void> claimPromptShown(
    String scope, {
    required bool bp,
    required bool glucose,
  }) async {
    if (bp) await markBpPromptDismissed(scope);
    if (glucose) await markGlucosePromptDismissed(scope);
    await recordPromptHandled(scope);
  }

  static Future<VitalsPromptMode> getPromptMode(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_modeKey(scope))) {
      'off' => VitalsPromptMode.off,
      'every5' => VitalsPromptMode.every5Days,
      _ => VitalsPromptMode.daily,
    };
  }

  static Future<void> setPromptMode(String scope, VitalsPromptMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      VitalsPromptMode.off => 'off',
      VitalsPromptMode.every5Days => 'every5',
      VitalsPromptMode.daily => 'daily',
    };
    await prefs.setString(_modeKey(scope), value);
    if (mode == VitalsPromptMode.every5Days) {
      await _recordAskedToday(scope);
    }
  }

  static Future<void> _recordAskedToday(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAskKey(scope), _todayKey());
  }

  static Future<bool> _shouldPromptMetric(String scope, {required bool isBp}) async {
    await syncFromMetrics(scope);
    final mode = await getPromptMode(scope);
    if (mode == VitalsPromptMode.off) return false;

    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final logKey = isBp ? _bpKey(scope) : _glucoseKey(scope);
    if (prefs.getString(logKey) == today) return false;

    if (mode == VitalsPromptMode.every5Days) {
      final lastAsk = prefs.getString(_lastAskKey(scope));
      if (lastAsk == null) return true;
      final last = DateTime.parse(lastAsk);
      final now = DateTime.now();
      final daysSince = DateTime(now.year, now.month, now.day)
          .difference(DateTime(last.year, last.month, last.day))
          .inDays;
      return daysSince >= 5;
    }

    final promptKey = isBp ? _bpPromptKey(scope) : _glucosePromptKey(scope);
    if (prefs.getString(promptKey) == today) return false;
    return true;
  }

  /// Align prefs with metrics already stored today (e.g. after onboarding or manual log).
  static Future<void> syncFromMetrics(String scope) async {
    if (scope == preSignUpScope) return;
    final db = Db.instance.raw;
    final today = _todayKey();

    final bpRows = await db.query(
      'health_metrics',
      columns: ['recorded_at'],
      where: 'user_id = ? AND metric_type = ?',
      whereArgs: [scope, 'blood_pressure_systolic'],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    if (bpRows.isNotEmpty) {
      final recorded = DateTime.parse(bpRows.first['recorded_at'] as String).toLocal();
      if (_dateKey(recorded) == today) await markBpLogged(scope);
    }

    final glucoseRows = await db.query(
      'health_metrics',
      columns: ['recorded_at'],
      where: 'user_id = ? AND metric_type = ?',
      whereArgs: [scope, 'glucose'],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    if (glucoseRows.isNotEmpty) {
      final recorded = DateTime.parse(glucoseRows.first['recorded_at'] as String).toLocal();
      if (_dateKey(recorded) == today) await markGlucoseLogged(scope);
    }
  }

  static Future<bool> shouldPromptBp(String scope) =>
      _shouldPromptMetric(scope, isBp: true);

  static Future<bool> shouldPromptGlucose(String scope) =>
      _shouldPromptMetric(scope, isBp: false);

  static Future<void> markBpPromptDismissed(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bpPromptKey(scope), _todayKey());
    final mode = await getPromptMode(scope);
    if (mode == VitalsPromptMode.every5Days) await _recordAskedToday(scope);
  }

  static Future<void> markGlucosePromptDismissed(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_glucosePromptKey(scope), _todayKey());
    final mode = await getPromptMode(scope);
    if (mode == VitalsPromptMode.every5Days) await _recordAskedToday(scope);
  }

  static Future<void> recordPromptHandled(String scope) async {
    if (await getPromptMode(scope) == VitalsPromptMode.every5Days) {
      await _recordAskedToday(scope);
    }
  }

  static Future<void> markBpLogged(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bpKey(scope), _todayKey());
  }

  static Future<void> markGlucoseLogged(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_glucoseKey(scope), _todayKey());
  }
}
