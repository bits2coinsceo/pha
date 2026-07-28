import 'dart:math';

import 'package:uuid/uuid.dart';

import 'daily_metric_store.dart';
import 'db.dart';
import 'medical_guidelines.dart';

const _uuid = Uuid();

/// Result of a Health Index calculation.
class HealthIndexResult {
  final int score;
  final String status;
  final String summary;
  final Map<String, double> componentScores;
  final Map<String, double> appliedWeights;

  const HealthIndexResult({
    required this.score,
    required this.status,
    required this.summary,
    required this.componentScores,
    required this.appliedWeights,
  });
}

/// Evidence-weighted Health Index (0–100) from all local patient data.
///
/// Relative impact follows WHO STEPS / Global Burden of Disease ranking of
/// major NCD risk factors (raised BP, tobacco, raised glucose, overweight,
/// physical inactivity, harmful alcohol, unhealthy diet), plus app wellness
/// signals (stress check, PsychoTest, screen-time habits).
///
/// Only factors with available data are used; their weights are renormalized
/// so missing inputs do not unfairly lower the score.
class HealthIndexService {
  HealthIndexService._();

  /// Relative impact weights — single source: [MedicalGuidelines.indexWeights].
  static const weights = MedicalGuidelines.indexWeights;

  /// Recalculate from SQLite and upsert today's Health Index row.
  ///
  /// Past days stay frozen (last value of that local calendar day).
  static Future<HealthIndexResult> recalculate(String userId) async {
    final result = await compute(userId);
    final now = DateTime.now().toUtc().toIso8601String();
    final bounds = DailyMetricStore.localDayBounds();
    final existing = await Db.instance.raw.query(
      'health_index',
      columns: ['id'],
      where: 'user_id = ? AND calculated_at >= ? AND calculated_at < ?',
      whereArgs: [userId, bounds.startIso, bounds.endIso],
      orderBy: 'calculated_at DESC',
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await Db.instance.raw.update(
        'health_index',
        {
          'score': result.score,
          'status': result.status,
          'calculated_at': now,
          'created_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await Db.instance.raw.insert('health_index', {
        'id': _uuid.v4(),
        'user_id': userId,
        'score': result.score,
        'status': result.status,
        'calculated_at': now,
        'created_at': now,
      });
    }
    return result;
  }

  /// Latest stored score, or null if never calculated.
  static Future<HealthIndexResult?> latest(String userId) async {
    final rows = await Db.instance.raw.query(
      'health_index',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'calculated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return HealthIndexResult(
      score: (r['score'] as num).toInt(),
      status: r['status'] as String,
      summary: _summaryFor((r['score'] as num).toInt(), r['status'] as String),
      componentScores: const {},
      appliedWeights: const {},
    );
  }

  /// Pure computation from current DB state (no write).
  static Future<HealthIndexResult> compute(String userId) async {
    final db = Db.instance.raw;
    final profiles =
        await db.query('profiles', where: 'id = ?', whereArgs: [userId], limit: 1);
    final profile = profiles.isEmpty ? null : profiles.first;

    final metrics = await db.query(
      'health_metrics',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recorded_at DESC',
      limit: 80,
    );
    final latest = <String, double>{};
    for (final m in metrics) {
      latest.putIfAbsent(
        m['metric_type'] as String,
        () => (m['value'] as num).toDouble(),
      );
    }

    final scores = <String, double>{};

    // BMI from profile / weight metric
    final heightCm = (profile?['height'] as num?)?.toDouble();
    final weightKg =
        (profile?['weight'] as num?)?.toDouble() ?? latest['weight'];
    if (heightCm != null && heightCm > 0 && weightKg != null) {
      scores['bmi'] = _scoreBmi(weightKg / pow(heightCm / 100, 2));
    }

    final sys = latest['blood_pressure_systolic'];
    final dia = latest['blood_pressure_diastolic'];
    if (sys != null && dia != null) {
      scores['blood_pressure'] = _scoreBp(sys, dia);
    }

    final glucose = latest['glucose'];
    if (glucose != null) {
      scores['glucose'] = _scoreGlucose(glucose);
    }

    // Activity: steps + recent program check-ins
    final steps = latest['steps'];
    final activityParts = <double>[];
    if (steps != null) activityParts.add(_scoreSteps(steps));
    final checkinScore = await _scoreActivityCheckins(userId);
    if (checkinScore != null) activityParts.add(checkinScore);
    if (activityParts.isNotEmpty) {
      scores['activity'] =
          activityParts.reduce((a, b) => a + b) / activityParts.length;
    }

    final habits = await db.query(
      'bad_habit_checks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (habits.isNotEmpty) {
      final h = habits.first;
      scores['smoking'] = _scoreSmoking(
        (h['smokes'] as num).toInt() == 1,
        h['smoking_level'] as String?,
      );
      scores['alcohol'] = _scoreAlcohol(
        (h['drinks_alcohol'] as num).toInt() == 1,
        h['alcohol_level'] as String?,
      );
      scores['screen_time'] =
          _scoreScreenTime(h['social_media_level'] as String?);
    }

    final wellness = await db.query(
      'stress_tests',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (wellness.isNotEmpty) {
      scores['wellness'] = (wellness.first['score'] as num).toDouble().clamp(0, 100);
    }

    final psycho = await db.query(
      'psychotest_results',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (psycho.isNotEmpty) {
      final total = (psycho.first['total_score'] as num).toInt();
      scores['psychotest'] = PsychoGuidelines.indexContribution(total);
    }

    final meals = await db.query(
      'meal_calorie_checks',
      where: 'user_id = ? AND confirmed = 1',
      whereArgs: [userId],
      orderBy: 'checked_at DESC',
      limit: 5,
    );
    if (meals.isNotEmpty) {
      scores['nutrition'] = _scoreNutrition(meals);
    }

    // If almost nothing yet, seed from age alone (primary onboarding)
    if (scores.isEmpty) {
      final age = (profile?['age'] as num?)?.toInt();
      final seed = age == null ? 72.0 : _scoreAgeBaseline(age);
      return HealthIndexResult(
        score: seed.round().clamp(10, 100),
        status: _statusFor(seed.round()),
        summary: _summaryFor(seed.round(), _statusFor(seed.round())),
        componentScores: {'baseline': seed},
        appliedWeights: {'baseline': 100},
      );
    }

    var weightSum = 0.0;
    var weighted = 0.0;
    final applied = <String, double>{};
    for (final e in scores.entries) {
      final w = weights[e.key] ?? 0;
      if (w <= 0) continue;
      weightSum += w;
      weighted += e.value * w;
      applied[e.key] = w;
    }

    final raw = weightSum == 0 ? 70.0 : weighted / weightSum;
    final score = raw.round().clamp(10, 100);
    final status = _statusFor(score);
    return HealthIndexResult(
      score: score,
      status: status,
      summary: _summaryFor(score, status),
      componentScores: scores,
      appliedWeights: applied,
    );
  }

  // ── Component scorers — delegated to MedicalGuidelines ───────────────────

  static double _scoreAgeBaseline(int age) =>
      MedicalGuidelines.ageBaselineScore(age);

  static double _scoreBmi(double bmi) => BmiGuidelines.scoreFromBmi(bmi);

  static double _scoreBp(double s, double d) => BloodPressure.score(s, d);

  static double _scoreGlucose(double g) => GlucoseGuidelines.score(g);

  static double _scoreSteps(double steps) => StepsGuidelines.score(steps);

  static Future<double?> _scoreActivityCheckins(String userId) async {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    final rows = await Db.instance.raw.query(
      'physical_activity_checkins',
      where: 'user_id = ? AND created_at >= ?',
      whereArgs: [userId, since],
      orderBy: 'created_at DESC',
    );
    if (rows.isEmpty) return null;
    var points = 0.0;
    for (final r in rows) {
      switch (r['status'] as String) {
        case 'yes':
          points += 100;
        case 'partially':
          points += 60;
        default:
          points += 20;
      }
    }
    return points / rows.length;
  }

  static double _scoreSmoking(bool smokes, String? level) =>
      HabitGuidelines.smokingScore(smokes, level);

  static double _scoreAlcohol(bool drinks, String? level) =>
      HabitGuidelines.alcoholScore(drinks, level);

  static double _scoreScreenTime(String? level) =>
      HabitGuidelines.screenScore(level);

  static double _scoreNutrition(List<Map<String, dynamic>> meals) =>
      HabitGuidelines.nutritionFromMeals(meals);

  static String _statusFor(int score) => MedicalGuidelines.indexStatus(score);

  static String _summaryFor(int score, String status) =>
      MedicalGuidelines.indexSummary(score, status);
}
