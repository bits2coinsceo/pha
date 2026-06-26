import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'db.dart';
import 'health_telemetry.dart';
import 'models.dart';

const _uuid = Uuid();
final _rng = Random();

// ── AI consultation ──────────────────────────────────────────────────────────
// Ported from supabase/functions/ai-consultation.
class AiConsultationService {
  static const _responses = <String, List<String>>{
    'sleep': [
      "Getting adequate sleep is crucial for your health. Aim for 7-9 hours per night. Try maintaining a consistent sleep schedule and creating a relaxing bedtime routine.",
      "Sleep affects your immune system, mood, and metabolism. If you're having trouble sleeping, consider limiting screen time before bed and avoiding caffeine late in the day.",
    ],
    'exercise': [
      "Regular physical activity is key to good health. Aim for at least 150 minutes of moderate exercise per week. Find activities you enjoy!",
      "Exercise improves cardiovascular health, mood, and energy levels. Start with activities you enjoy and gradually increase intensity.",
    ],
    'stress': [
      "Managing stress is important for your well-being. Try meditation, deep breathing exercises, or activities you find relaxing.",
      "High stress can affect your physical and mental health. Consider talking to someone you trust or seeking professional support if needed.",
    ],
    'nutrition': [
      "A balanced diet with plenty of fruits, vegetables, and whole grains supports your health. Stay hydrated and limit processed foods.",
      "Good nutrition provides energy and supports all body functions. Consider consulting a nutritionist for personalized advice.",
    ],
    'weight': [
      "Maintaining a healthy weight requires balanced diet and regular exercise. Small, sustainable changes are more effective than drastic ones.",
      "Your weight is just one aspect of health. Focus on how you feel and building healthy habits rather than the number on the scale.",
    ],
    'default': [
      "That's a great health question! Focus on balanced nutrition, regular exercise, adequate sleep, and stress management for overall wellness.",
      "Taking care of your physical and mental health is important. Don't hesitate to consult with healthcare professionals for personalized advice.",
    ],
  };

  /// Asks the backend (Vertex AI Gemini) for a reply. Falls back to the local
  /// keyword responder if the backend is unreachable, so the chat keeps working
  /// offline. Budget-exhausted (402) is rethrown so the UI can prompt upgrade.
  static Future<String> reply(String userId, String message) async {
    try {
      return await ApiClient.chat(userId: userId, message: message);
    } on ApiException catch (e) {
      if (e.isBudgetExhausted) rethrow;
      return _localReply(message);
    } catch (_) {
      return _localReply(message);
    }
  }

  static String _localReply(String message) {
    final lower = message.toLowerCase();
    for (final entry in _responses.entries) {
      if (entry.key == 'default') continue;
      if (lower.contains(entry.key)) {
        return entry.value[_rng.nextInt(entry.value.length)];
      }
    }
    final d = _responses['default']!;
    return d[_rng.nextInt(d.length)];
  }

  static Future<void> save(String userId, String message, String response) async {
    await Db.instance.raw.insert('ai_consultations', {
      'id': _uuid.v4(),
      'user_id': userId,
      'message': message,
      'response': response,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

// ── Health analysis ──────────────────────────────────────────────────────────
// Ported from supabase/functions/health-analysis.
class HealthAnalysisService {
  static Finding _bp(double s, double d) {
    final v = '${s.toInt()}/${d.toInt()} mmHg';
    if (s < 90 || d < 60) {
      return Finding(category: 'Blood Pressure', status: 'warning', value: v, message: 'Your blood pressure is below normal (hypotension). Stay hydrated and consult your doctor if symptoms occur.');
    }
    if (s < 120 && d < 80) {
      return Finding(category: 'Blood Pressure', status: 'good', value: v, message: 'Blood pressure is in the optimal range. Keep up the healthy lifestyle.');
    }
    if (s < 130 && d < 80) {
      return Finding(category: 'Blood Pressure', status: 'info', value: v, message: 'Blood pressure is elevated (Stage 0). Monitor regularly and reduce sodium intake.');
    }
    if (s < 140 || d < 90) {
      return Finding(category: 'Blood Pressure', status: 'warning', value: v, message: 'Blood pressure is in Stage 1 hypertension range. Lifestyle changes are recommended — reduce salt, exercise regularly.');
    }
    return Finding(category: 'Blood Pressure', status: 'critical', value: v, message: 'Blood pressure is in Stage 2 hypertension range. Please consult a healthcare provider promptly.');
  }

  static Finding _glucose(double g) {
    final v = '${g.toStringAsFixed(g == g.roundToDouble() ? 0 : 1)} mg/dL';
    if (g < 70) {
      return Finding(category: 'Blood Glucose', status: 'critical', value: v, message: 'Blood glucose is low (hypoglycemia). Eat something with fast-acting carbohydrates and consult your doctor.');
    }
    if (g <= 99) {
      return Finding(category: 'Blood Glucose', status: 'good', value: v, message: 'Fasting blood glucose is in the normal range. Good metabolic health.');
    }
    if (g <= 125) {
      return Finding(category: 'Blood Glucose', status: 'warning', value: v, message: 'Blood glucose is in the prediabetes range. Reduce sugar intake, increase fiber and physical activity.');
    }
    return Finding(category: 'Blood Glucose', status: 'critical', value: v, message: 'Blood glucose is in the diabetes range. Please consult a healthcare provider for evaluation.');
  }

  static Finding _weight(double weight, double? heightCm) {
    if (heightCm == null) {
      return Finding(category: 'Weight', status: 'info', value: '${weight.toStringAsFixed(1)} kg', message: 'Weight is recorded. Add your height in your profile to calculate BMI.');
    }
    final bmi = weight / pow(heightCm / 100, 2);
    final s = bmi.toStringAsFixed(1);
    if (bmi < 18.5) return Finding(category: 'Weight / BMI', status: 'warning', value: 'BMI $s', message: 'BMI of $s indicates underweight. Ensure adequate caloric and nutrient intake.');
    if (bmi < 25.0) return Finding(category: 'Weight / BMI', status: 'good', value: 'BMI $s', message: 'BMI of $s is in the healthy range. Well done!');
    if (bmi < 30.0) return Finding(category: 'Weight / BMI', status: 'warning', value: 'BMI $s', message: 'BMI of $s indicates overweight. Gradual diet and exercise improvements can help.');
    return Finding(category: 'Weight / BMI', status: 'critical', value: 'BMI $s', message: 'BMI of $s indicates obesity. This increases risk for several conditions — consult a healthcare provider.');
  }

  static Finding _steps(double steps) {
    final v = '${steps.toInt()} steps';
    if (steps >= 10000) {
      return Finding(category: 'Daily Activity', status: 'good', value: v, message: 'Excellent activity level! You are meeting the recommended 10,000 steps per day.');
    }
    if (steps >= 7500) {
      return Finding(category: 'Daily Activity', status: 'info', value: v, message: 'Good activity level. A little more movement can get you to the 10,000-step goal.');
    }
    if (steps >= 5000) {
      return Finding(category: 'Daily Activity', status: 'warning', value: v, message: 'Moderate activity. Aim for 10,000 steps daily — try short walks throughout your day.');
    }
    return Finding(category: 'Daily Activity', status: 'warning', value: v, message: 'Low activity level. Sedentary lifestyle increases cardiovascular and metabolic risk. Start with 15-minute daily walks.');
  }

  static Finding _calories(double calories, double steps) {
    final expMin = steps * 0.04;
    final expMax = steps * 0.06;
    if (calories >= expMin && calories <= expMax * 1.5) {
      return Finding(category: 'Calorie Burn', status: 'good', value: '${calories.toInt()} kcal', message: 'Calorie expenditure is appropriate for your activity level.');
    }
    return Finding(category: 'Calorie Burn', status: 'info', value: '${calories.toInt()} kcal', message: 'You burned ${calories.toInt()} kcal. Combine with balanced nutrition to meet your health goals.');
  }

  static Finding _wellness(int score) {
    if (score >= 80) return Finding(category: 'Mental Wellness', status: 'good', value: '$score/100', message: 'Excellent wellness score. Low stress and good mental resilience.');
    if (score >= 60) return Finding(category: 'Mental Wellness', status: 'info', value: '$score/100', message: 'Moderate wellness. Consider stress-reducing activities like meditation or light exercise.');
    if (score >= 40) return Finding(category: 'Mental Wellness', status: 'warning', value: '$score/100', message: 'Wellness score indicates elevated stress. Prioritize sleep, social connection, and relaxation.');
    return Finding(category: 'Mental Wellness', status: 'critical', value: '$score/100', message: 'High stress level detected. Consider speaking with a mental health professional.');
  }

  static List<Recommendation> _recommendations(List<Finding> findings) {
    final recs = <Recommendation>[];
    for (final f in findings) {
      if (f.status == 'critical') recs.add(Recommendation(priority: 'high', text: 'Address ${f.category}: ${f.message}'));
      else if (f.status == 'warning') recs.add(Recommendation(priority: 'medium', text: 'Improve ${f.category}: ${f.message}'));
    }
    if (recs.isEmpty) {
      recs.add(Recommendation(priority: 'low', text: 'All key metrics look healthy. Continue your current habits and check in regularly.'));
    }
    return recs.take(5).toList();
  }

  static int _score(List<Finding> findings) {
    var score = 100;
    for (final f in findings) {
      if (f.status == 'critical') score -= 20;
      else if (f.status == 'warning') score -= 10;
      else if (f.status == 'info') score -= 3;
    }
    return score.clamp(10, 100);
  }

  static String _status(int score) {
    if (score >= 85) return 'excellent';
    if (score >= 70) return 'good';
    if (score >= 50) return 'fair';
    return 'needs_attention';
  }

  static String _summary(String status, List<Finding> findings) {
    final criticals = findings.where((f) => f.status == 'critical').toList();
    final warnings = findings.where((f) => f.status == 'warning').toList();
    final good = findings.where((f) => f.status == 'good').toList();
    const phrases = {
      'excellent': 'Your overall health picture is excellent.',
      'good': 'Your overall health is in good shape.',
      'fair': 'Your health metrics show some areas worth improving.',
      'needs_attention': 'Several health metrics require your attention.',
    };
    var s = phrases[status] ?? 'Here is your health summary.';
    if (good.isNotEmpty) {
      s += ' ${good.map((f) => f.category).join(", ")} ${good.length == 1 ? "is" : "are"} within healthy ranges.';
    }
    if (warnings.isNotEmpty) s += ' Keep an eye on ${warnings.map((f) => f.category).join(" and ")}.';
    if (criticals.isNotEmpty) {
      s += ' Immediate attention is recommended for ${criticals.map((f) => f.category).join(" and ")}.';
    }
    return s;
  }

  static Future<HealthAnalysis?> latest(String userId) async {
    final rows = await Db.instance.raw.query('health_analysis',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'analyzed_at DESC', limit: 1);
    return rows.isEmpty ? null : HealthAnalysis.fromRow(rows.first);
  }

  /// Runs a fresh analysis. Throws if no metrics exist.
  static Future<HealthAnalysis> run(String userId) async {
    final db = Db.instance.raw;
    final metrics = await db.query('health_metrics',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'recorded_at DESC', limit: 50);
    final wellnessRows = await db.query('stress_tests',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC', limit: 1);
    final profileRows = await db.query('profiles', where: 'id = ?', whereArgs: [userId]);

    final latest = <String, double>{};
    for (final m in metrics) {
      final t = m['metric_type'] as String;
      if (!latest.containsKey(t)) latest[t] = (m['value'] as num).toDouble();
    }

    final findings = <Finding>[];
    final sys = latest['blood_pressure_systolic'];
    final dia = latest['blood_pressure_diastolic'];
    if (sys != null && dia != null) findings.add(_bp(sys, dia));
    final glucose = latest['glucose'];
    if (glucose != null) findings.add(_glucose(glucose));
    final weight = latest['weight'];
    if (weight != null) {
      final h = profileRows.isNotEmpty ? profileRows.first['height'] as num? : null;
      findings.add(_weight(weight, h?.toDouble()));
    }
    final steps = latest['steps'];
    if (steps != null) findings.add(_steps(steps));
    final calories = latest['calories'];
    if (calories != null && steps != null) findings.add(_calories(calories, steps));
    if (wellnessRows.isNotEmpty) findings.add(_wellness((wellnessRows.first['score'] as num).toInt()));

    if (findings.isEmpty) {
      throw Exception('No health data found. Please log some metrics first.');
    }

    final score = _score(findings);
    final status = _status(score);
    final analyzedAt = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    await db.insert('health_analysis', {
      'id': id,
      'user_id': userId,
      'overall_status': status,
      'overall_score': score,
      'summary': _summary(status, findings),
      'findings': jsonEncode(findings.map((f) => f.toJson()).toList()),
      'recommendations': jsonEncode(_recommendations(findings).map((r) => r.toJson()).toList()),
      'analyzed_at': analyzedAt,
    });
    return (await latest_(id))!;
  }

  static Future<HealthAnalysis?> latest_(String id) async {
    final rows = await Db.instance.raw.query('health_analysis', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : HealthAnalysis.fromRow(rows.first);
  }
}

// ── Health Connect sync ──────────────────────────────────────────────────────
// Ported from supabase/functions/health-connect-sync.
class HealthConnectService {
  static double _calories(int steps, double distanceMeters, double weightKg) {
    final distanceKm = distanceMeters / 1000;
    final durationHours = distanceKm / 5;
    final met = steps > 0 && distanceKm > 0
        ? (distanceKm / (steps * 0.000762)) * 3.5
        : 3.5;
    final clamped = met.clamp(2.5, 8.0);
    return (clamped * weightKg * durationHours * 10).round() / 10;
  }

  static Future<LastSync?> last(String userId) async {
    final rows = await Db.instance.raw.query('health_connect_syncs',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'synced_at DESC', limit: 1);
    return rows.isEmpty ? null : LastSync.fromRow(rows.first);
  }

  static Future<void> sync(String userId, {required int steps, required double distanceMeters}) async {
    final db = Db.instance.raw;
    final weightRows = await db.query('health_metrics',
        where: 'user_id = ? AND metric_type = ?',
        whereArgs: [userId, 'weight'],
        orderBy: 'recorded_at DESC',
        limit: 1);
    final weightKg = weightRows.isEmpty ? 70.0 : (weightRows.first['value'] as num).toDouble();
    final calories = _calories(steps, distanceMeters, weightKg);
    final distanceKm = (distanceMeters / 1000 * 100).round() / 100;
    final now = DateTime.now().toUtc().toIso8601String();

    for (final m in [
      {'metric_type': 'steps', 'value': steps.toDouble()},
      {'metric_type': 'distance', 'value': distanceKm},
      {'metric_type': 'calories', 'value': calories},
    ]) {
      await db.insert('health_metrics', {
        'id': _uuid.v4(),
        'user_id': userId,
        'metric_type': m['metric_type'],
        'value': m['value'],
        'recorded_at': now,
        'source': 'health_connect',
        'created_at': now,
      });
    }
    await db.insert('health_connect_syncs', {
      'id': _uuid.v4(),
      'user_id': userId,
      'synced_at': now,
      'steps': steps,
      'distance_meters': distanceMeters,
      'calories_calculated': calories,
      'raw_payload': jsonEncode({'steps': steps, 'distance_meters': distanceMeters}),
    });
  }

  /// Reads today's steps and distance from the device, then stores them locally.
  /// Returns true when new data was written.
  static Future<bool> syncFromDevice(String userId) async {
    if (!HealthTelemetryService.isSupported) {
      throw Exception('Device activity sync is only available on iOS and Android.');
    }
    if (Platform.isAndroid && !await HealthTelemetryService.hasPermission()) {
      throw Exception('Activity permission not granted.');
    }
    final snapshot = await HealthTelemetryService.fetchToday();
    if (snapshot == null) {
      throw Exception(
        'Could not read activity data. Enable Steps and Walking + Running Distance '
        'in the Health permission sheet.',
      );
    }
    final previous = await last(userId);
    if (previous != null) {
      final prevDay = previous.syncedAt.toLocal();
      final today = DateTime.now();
      final sameDay = prevDay.year == today.year &&
          prevDay.month == today.month &&
          prevDay.day == today.day;
      if (sameDay &&
          previous.steps == snapshot.steps &&
          (previous.distanceMeters - snapshot.distanceMeters).abs() < 0.5) {
        return false;
      }
    }
    await sync(
      userId,
      steps: snapshot.steps,
      distanceMeters: snapshot.distanceMeters,
    );
    return true;
  }
}
