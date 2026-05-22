import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';

const _kComplete = 'pre_onboarding_complete';
const _kUnit = 'pending_unit_system';
const _kAge = 'pending_age';
const _kHeight = 'pending_height';
const _kMetrics = 'pending_metrics_json';

const _uuid = Uuid();

/// Onboarding data collected before sign-up; applied to profile on registration.
class OnboardingPrefs {
  static Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kComplete) ?? false;
  }

  static Future<void> save({
    required String unitSystem,
    required int age,
    required int heightCm,
    required double weightKg,
    Map<String, double> extraMetrics = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final metrics = <Map<String, dynamic>>[
      {'metric_type': 'weight', 'value': weightKg},
      for (final e in extraMetrics.entries) {'metric_type': e.key, 'value': e.value},
    ];
    await prefs.setBool(_kComplete, true);
    await prefs.setString(_kUnit, unitSystem);
    await prefs.setInt(_kAge, age);
    await prefs.setInt(_kHeight, heightCm);
    await prefs.setString(_kMetrics, jsonEncode(metrics));
  }

  static Future<void> applyToUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kComplete) ?? false)) return;

    final unit = prefs.getString(_kUnit) ?? 'metric';
    final age = prefs.getInt(_kAge);
    final height = prefs.getInt(_kHeight);
    final metricsJson = prefs.getString(_kMetrics);

    await Db.instance.raw.update(
      'profiles',
      {
        'unit_system': unit,
        if (age != null) 'age': age,
        if (height != null) 'height': height,
        'onboarding_completed': 1,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (metricsJson != null) {
      final list = jsonDecode(metricsJson) as List<dynamic>;
      final now = DateTime.now().toUtc().toIso8601String();
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        await Db.instance.raw.insert('health_metrics', {
          'id': _uuid.v4(),
          'user_id': userId,
          'metric_type': m['metric_type'] as String,
          'value': (m['value'] as num).toDouble(),
          'recorded_at': now,
          'created_at': now,
        });
      }
    }

    await prefs.remove(_kUnit);
    await prefs.remove(_kAge);
    await prefs.remove(_kHeight);
    await prefs.remove(_kMetrics);
  }

  /// For tests / full reset.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kComplete);
    await prefs.remove(_kUnit);
    await prefs.remove(_kAge);
    await prefs.remove(_kHeight);
    await prefs.remove(_kMetrics);
  }
}
