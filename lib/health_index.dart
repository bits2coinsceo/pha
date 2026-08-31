import 'dart:math';

import 'package:uuid/uuid.dart';

import 'daily_metric_store.dart';
import 'db.dart';
import 'heart_rate.dart';
import 'locale_controller.dart';
import 'l10n/medical_l10n.dart';
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

/// Two-layer Health Index (0–100) from local patient data.
///
/// 1. **Foundation** — age, BMI (height/weight), blood pressure, glucose,
///    and harmful habits (smoking, alcohol, screen time).
/// 2. **Lifestyle** — daily steps & physical-activity check-ins (and meals /
///    wellness / PsychoTest when present) pull that foundation up or down.
/// 3. **Heart rate** — counted as fitness only when there is meaningful
///    activity; without activity, an elevated pulse is treated as stress.
///
/// Missing inputs are skipped; layer weights are renormalized.
class HealthIndexService {
  HealthIndexService._();

  /// Combined map for Insights / gap tools.
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
      summary: await _summaryFor((r['score'] as num).toInt(), r['status'] as String),
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
    final age = (profile?['age'] as num?)?.toInt();

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

    final foundation = <String, double>{};
    final lifestyle = <String, double>{};
    final applied = <String, double>{};
    final allScores = <String, double>{};

    // ── 1. Foundation: vitals, body, habits, age ───────────────────────────
    if (age != null) {
      foundation['age'] = _scoreAgeBaseline(age);
    }

    final heightCm = (profile?['height'] as num?)?.toDouble();
    final weightKg =
        (profile?['weight'] as num?)?.toDouble() ?? latest['weight'];
    if (heightCm != null && heightCm > 0 && weightKg != null) {
      foundation['bmi'] = _scoreBmi(weightKg / pow(heightCm / 100, 2));
    }

    final sys = latest['blood_pressure_systolic'];
    final dia = latest['blood_pressure_diastolic'];
    if (sys != null && dia != null) {
      foundation['blood_pressure'] = _scoreBp(sys, dia);
    }

    final glucose = latest['glucose'];
    if (glucose != null) {
      foundation['glucose'] = _scoreGlucose(glucose);
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
      foundation['smoking'] = _scoreSmoking(
        (h['smokes'] as num).toInt() == 1,
        h['smoking_level'] as String?,
      );
      foundation['alcohol'] = _scoreAlcohol(
        (h['drinks_alcohol'] as num).toInt() == 1,
        h['alcohol_level'] as String?,
      );
      foundation['screen_time'] =
          _scoreScreenTime(h['social_media_level'] as String?);
    }

    // ── 2. Lifestyle: steps / activity, nutrition, wellness, psycho ────────
    final steps = latest['steps'];
    final checkinScore = await _scoreActivityCheckins(userId);
    double? activityScore;
    if (steps != null && checkinScore != null) {
      activityScore = _scoreSteps(steps) * 0.75 + checkinScore * 0.25;
    } else if (steps != null) {
      activityScore = _scoreSteps(steps);
    } else if (checkinScore != null) {
      activityScore = checkinScore;
    }
    if (activityScore != null) {
      lifestyle['activity'] = activityScore;
    }

    final hasActivity = _hasMeaningfulActivity(
      steps: steps,
      checkinScore: checkinScore,
    );

    final meals = await db.query(
      'meal_calorie_checks',
      where: 'user_id = ? AND confirmed = 1',
      whereArgs: [userId],
      orderBy: 'checked_at DESC',
      limit: 5,
    );
    if (meals.isNotEmpty) {
      lifestyle['nutrition'] = _scoreNutrition(meals);
    }

    final wellness = await db.query(
      'stress_tests',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (wellness.isNotEmpty) {
      lifestyle['wellness'] =
          (wellness.first['score'] as num).toDouble().clamp(0, 100);
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
      lifestyle['psychotest'] = PsychoGuidelines.indexContribution(total);
    }

    // Heart rate: fitness only with activity; otherwise elevated = stress.
    final restingHr = latest['resting_heart_rate'];
    final hrv = latest['hrv_sdnn'];
    final avgHr = latest['heart_rate_avg'];
    final irregular = (latest['irregular_rhythm'] ?? 0) > 0;
    final heartScore = HeartRateGuidelines.indexContribution(
      restingBpm: restingHr,
      hrvMs: hrv,
      avgBpm: avgHr,
      irregularRhythm: irregular,
      age: age,
    );
    double? stressScore;
    if (heartScore != null) {
      if (hasActivity) {
        lifestyle['heart_rate'] = heartScore;
      } else if (_looksLikeStress(
        restingBpm: restingHr,
        hrvMs: hrv,
        irregular: irregular,
        heartScore: heartScore,
      )) {
        stressScore = heartScore;
      }
    }

    allScores.addAll(foundation);
    allScores.addAll(lifestyle);
    if (stressScore != null) allScores['stress'] = stressScore;

    // Nothing at all → age seed or neutral baseline.
    if (foundation.isEmpty && lifestyle.isEmpty && stressScore == null) {
      final seed = age == null ? 72.0 : _scoreAgeBaseline(age);
      return HealthIndexResult(
        score: seed.round().clamp(10, 100),
        status: _statusFor(seed.round()),
        summary: await _summaryFor(seed.round(), _statusFor(seed.round())),
        componentScores: {'baseline': seed},
        appliedWeights: {'baseline': 100},
      );
    }

    final foundationScore = foundation.isEmpty
        ? (age == null ? 72.0 : _scoreAgeBaseline(age))
        : _weightedAverage(
            foundation,
            MedicalGuidelines.foundationWeights,
            applied,
          );

    var score = foundationScore;

    if (lifestyle.isNotEmpty) {
      final lifestyleScore = _weightedAverage(
        lifestyle,
        MedicalGuidelines.lifestyleWeights,
        applied,
      );
      final blend = MedicalGuidelines.lifestyleBlend;
      score = foundationScore * (1 - blend) + lifestyleScore * blend;
    }

    // Elevated HR without activity → stress pull on the final score.
    if (stressScore != null) {
      final sb = MedicalGuidelines.stressBlend;
      score = score * (1 - sb) + stressScore * sb;
      applied['stress'] = MedicalGuidelines.indexWeights['stress'] ?? 8;
    }

    // Record foundation weights that actually applied.
    for (final e in foundation.entries) {
      final w = MedicalGuidelines.foundationWeights[e.key] ?? 0;
      if (w > 0) applied.putIfAbsent(e.key, () => w);
    }

    final rounded = score.round().clamp(10, 100);
    final status = _statusFor(rounded);
    return HealthIndexResult(
      score: rounded,
      status: status,
      summary: await _summaryFor(rounded, status),
      componentScores: allScores,
      appliedWeights: applied,
    );
  }

  /// Meaningful movement today / recently — gates heart-rate-as-fitness.
  static bool _hasMeaningfulActivity({
    double? steps,
    double? checkinScore,
  }) {
    if (steps != null && steps >= MedicalGuidelines.stepsBaseline) return true;
    if (steps != null &&
        steps >= MedicalGuidelines.stepsSedentary &&
        checkinScore != null &&
        checkinScore >= 60) {
      return true;
    }
    if (checkinScore != null && checkinScore >= 70) return true;
    return false;
  }

  /// Elevated resting pulse / low HRV / irregular rhythm without activity.
  static bool _looksLikeStress({
    double? restingBpm,
    double? hrvMs,
    required bool irregular,
    required double heartScore,
  }) {
    if (irregular) return true;
    if (restingBpm != null &&
        restingBpm >= MedicalGuidelines.restingHrElevatedCutOff) {
      return true;
    }
    if (hrvMs != null && hrvMs < 40) return true;
    return heartScore < 70;
  }

  static double _weightedAverage(
    Map<String, double> scores,
    Map<String, double> weightTable,
    Map<String, double> appliedOut,
  ) {
    var weightSum = 0.0;
    var weighted = 0.0;
    for (final e in scores.entries) {
      final w = weightTable[e.key] ?? 0;
      if (w <= 0) continue;
      weightSum += w;
      weighted += e.value * w;
      appliedOut[e.key] = w;
    }
    if (weightSum == 0) {
      return scores.values.reduce((a, b) => a + b) / scores.length;
    }
    return weighted / weightSum;
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

  static Future<String> _summaryFor(int score, String status) async {
    final l10n = await LocaleController.loadLocalizations();
    return l10n.indexSummary(status);
  }
}
