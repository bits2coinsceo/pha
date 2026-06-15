import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'db.dart';
import 'onboarding_hp.dart';

const _uuid = Uuid();

/// Snapshot of an in-progress onboarding draft, used to restore the UI when a
/// user reopens the app after interrupting onboarding.
class OnboardingDraftData {
  final String unitSystem;
  final int? age;
  final int? heightCm;
  final double? weightKg;
  final String? gender;
  final Map<String, double> extraMetrics;
  final int step;
  final bool completed;
  final int healthPoints;

  const OnboardingDraftData({
    required this.unitSystem,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.gender,
    required this.extraMetrics,
    required this.step,
    required this.completed,
    required this.healthPoints,
  });
}

/// Onboarding data collected before sign-up. Persisted to SQLite incrementally
/// (on every quest/page change) so an interrupted onboarding is never repeated,
/// then applied to the profile + health metrics once the user registers.
class OnboardingPrefs {
  // There is only one pre-signup user on a device, so the draft is a singleton.
  static const _id = 'pending';

  static Future<Map<String, Object?>?> _row() async {
    final rows = await Db.instance.raw
        .query('onboarding_drafts', where: 'id = ?', whereArgs: [_id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Upsert the subset of columns in [values] into the singleton draft row.
  static Future<void> _upsert(Map<String, Object?> values) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await _row();
    if (existing == null) {
      await Db.instance.raw.insert('onboarding_drafts', {
        'id': _id,
        'unit_system': 'metric',
        'step': 1,
        'completed': 0,
        ...values,
        'updated_at': now,
      });
    } else {
      await Db.instance.raw.update(
        'onboarding_drafts',
        {...values, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [_id],
      );
    }
  }

  static Future<bool> isComplete() async {
    final r = await _row();
    return r != null && (r['completed'] as int) == 1;
  }

  /// Loads the current draft (completed or in-progress) for restoring the UI.
  static Future<OnboardingDraftData?> load() async {
    final r = await _row();
    if (r == null) return null;
    final metricsJson = r['metrics_json'] as String?;
    final extra = <String, double>{};
    if (metricsJson != null && metricsJson.isNotEmpty) {
      final decoded = jsonDecode(metricsJson) as Map<String, dynamic>;
      decoded.forEach((k, v) => extra[k] = (v as num).toDouble());
    }
    return OnboardingDraftData(
      unitSystem: r['unit_system'] as String? ?? 'metric',
      age: r['age'] as int?,
      heightCm: r['height'] as int?,
      weightKg: (r['weight'] as num?)?.toDouble(),
      gender: r['gender'] as String?,
      extraMetrics: extra,
      step: (r['step'] as int?) ?? 1,
      completed: ((r['completed'] as int?) ?? 0) == 1,
      healthPoints: (r['health_points'] as int?) ?? 0,
    );
  }

  /// Quest 1 done — units chosen. Advances the saved step to 2.
  static Future<void> saveUnit(String unitSystem) =>
      _upsert({'unit_system': unitSystem, 'step': 2});

  /// Ensures the singleton draft row exists (avoids lost saves before quest 1 finishes).
  static Future<void> ensureDraft({String unitSystem = 'metric'}) async {
    if (await _row() != null) return;
    await _upsert({'unit_system': unitSystem, 'step': 1});
  }

  /// Saves age / height / weight as the user types (quest 2), without advancing step.
  static Future<void> saveBasicsProgress({
    required String unitSystem,
    int? age,
    int? heightCm,
    double? weightKg,
    String? gender,
  }) async {
    await ensureDraft(unitSystem: unitSystem);
    final existing = await _row();
    final currentStep = (existing?['step'] as int?) ?? 1;
    final values = <String, Object?>{
      'unit_system': unitSystem,
      if (age != null) 'age': age,
      if (heightCm != null) 'height': heightCm,
      if (weightKg != null) 'weight': weightKg,
      if (gender != null) 'gender': gender,
    };
    if ((age != null || heightCm != null || weightKg != null || gender != null) &&
        currentStep < 3) {
      values['step'] = 2;
    }
    await _upsert(values);
  }

  /// Quest 2 done — core vitals captured. Advances the saved step to 3.
  static Future<void> saveGeneral({
    required String unitSystem,
    required int age,
    required int heightCm,
    required double weightKg,
    required String gender,
  }) =>
      _upsert({
        'unit_system': unitSystem,
        'age': age,
        'height': heightCm,
        'weight': weightKg,
        'gender': gender,
        'step': 3,
      });

  /// Quest 3 done — optional vitals captured and onboarding finished.
  static Future<void> complete({
    required String unitSystem,
    Map<String, double> extraMetrics = const {},
    required int healthPoints,
  }) =>
      _upsert({
        'unit_system': unitSystem,
        'metrics_json': jsonEncode(extraMetrics),
        'step': 4,
        'completed': 1,
        'health_points': healthPoints.clamp(0, maxOnboardingHp),
      });

  /// Copies onboarding draft basics onto a freshly registered user, then clears the draft.
  static Future<void> applyToUser(String userId) async {
    final r = await _row();
    if (r == null) return;
    final completed = (r['completed'] as int) == 1;
    final age = r['age'] as int?;
    final height = r['height'] as int?;
    final weight = (r['weight'] as num?)?.toDouble();
    final gender = r['gender'] as String?;
    if (!completed && age == null && height == null && weight == null && gender == null) {
      return;
    }

    final unit = r['unit_system'] as String? ?? 'metric';

    await Db.instance.raw.update(
      'profiles',
      {
        'unit_system': unit,
        if (age != null) 'age': age,
        if (height != null) 'height': height,
        if (weight != null) 'weight': weight,
        if (gender != null) 'gender': gender,
        if (completed) 'onboarding_completed': 1,
        'health_points': ((r['health_points'] as int?) ?? 0).clamp(0, maxOnboardingHp),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );

    final now = DateTime.now().toUtc().toIso8601String();
    final metrics = <MapEntry<String, double>>[
      if (weight != null) MapEntry('weight', weight),
    ];
    final metricsJson = r['metrics_json'] as String?;
    if (metricsJson != null && metricsJson.isNotEmpty) {
      final decoded = jsonDecode(metricsJson) as Map<String, dynamic>;
      decoded.forEach((k, v) => metrics.add(MapEntry(k, (v as num).toDouble())));
    }
    for (final m in metrics) {
      await Db.instance.raw.insert('health_metrics', {
        'id': _uuid.v4(),
        'user_id': userId,
        'metric_type': m.key,
        'value': m.value,
        'recorded_at': now,
        'created_at': now,
      });
    }

    if (completed) await clear();
  }

  /// For tests / full reset.
  static Future<void> clear() async {
    await Db.instance.raw
        .delete('onboarding_drafts', where: 'id = ?', whereArgs: [_id]);
  }
}
