import 'package:shared_preferences/shared_preferences.dart';

import 'db.dart';

/// Tracks when BP / glucose were last logged so we only prompt once per calendar day.
class DailyVitalsService {
  static const preSignUpScope = 'pre_signup';

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _todayKey() => _dateKey(DateTime.now());

  static String _bpKey(String scope) => 'daily_vitals_bp_$scope';
  static String _glucoseKey(String scope) => 'daily_vitals_glucose_$scope';
  static String _bpPromptKey(String scope) => 'daily_vitals_bp_prompt_$scope';
  static String _glucosePromptKey(String scope) => 'daily_vitals_glucose_prompt_$scope';

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

  static Future<bool> shouldPromptBp(String scope) async {
    await syncFromMetrics(scope);
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    if (prefs.getString(_bpKey(scope)) == today) return false;
    if (prefs.getString(_bpPromptKey(scope)) == today) return false;
    return true;
  }

  static Future<bool> shouldPromptGlucose(String scope) async {
    await syncFromMetrics(scope);
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    if (prefs.getString(_glucoseKey(scope)) == today) return false;
    if (prefs.getString(_glucosePromptKey(scope)) == today) return false;
    return true;
  }

  static Future<void> markBpPromptDismissed(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bpPromptKey(scope), _todayKey());
  }

  static Future<void> markGlucosePromptDismissed(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_glucosePromptKey(scope), _todayKey());
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
