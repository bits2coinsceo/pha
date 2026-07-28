import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'daily_metric_store.dart';
import 'db.dart';
import 'health_index.dart';
import 'health_telemetry.dart';
import 'image_compress.dart';
import 'medical_guidelines.dart';
import 'models.dart';
import 'units.dart';

const _uuid = Uuid();
final _rng = Random();

const _aiDocResponseStyle =
    'RESPONSE STYLE (mandatory): Be clear, practical, and a little more detailed. '
    'Start with a short direct answer (2–3 sentences). '
    'Then add a short section with what looks good, what needs attention, and why. '
    'Finish with concrete next steps (3–6 bullets). '
    'Aim for roughly 150–250 words — enough to explain, not a lecture. '
    'Use plain patient-friendly language. No greetings, no fluff, no repeated disclaimers. '
    'Remind once that this is wellness guidance, not a formal medical diagnosis.';

/// Optional messages injected when opening Ai Doc (e.g. after an analysis upload).
class AiChatSeedMessage {
  final bool isUser;
  final String text;
  const AiChatSeedMessage(this.isUser, this.text);
}

/// Health data collected during onboarding and stored on the profile / metrics.
class OnboardingHealthSnapshot {
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final double? systolic;
  final double? diastolic;
  final double? glucoseMgdl;
  final double? steps;
  final String unitSystem;

  const OnboardingHealthSnapshot({
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.systolic,
    this.diastolic,
    this.glucoseMgdl,
    this.steps,
    this.unitSystem = 'metric',
  });

  bool get hasAnyData =>
      age != null ||
      heightCm != null ||
      weightKg != null ||
      systolic != null ||
      diastolic != null ||
      glucoseMgdl != null ||
      steps != null;

  String toDiagnosisPrompt() {
    final buf = StringBuffer(
      'You are Ai Doc, a personal health assistant in the PHA app. '
      'The patient agreed to use their onboarding health data. '
      'Review the metrics below and give a clear wellness assessment.\n\n'
      'Patient health data:\n',
    );
    void line(String label, String? value) {
      buf.writeln('- $label: ${value ?? 'not provided'}');
    }

    line('Age', age != null ? '$age years' : null);
    line('Gender', gender);
    if (heightCm != null) {
      final h = formatHeight(heightCm, unitSystem);
      line('Height', '${h.value} ${h.unit}'.trim());
    } else {
      line('Height', null);
    }
    if (weightKg != null) {
      final w = formatWeight(weightKg, unitSystem);
      line('Weight', '${w.value} ${w.unit}');
    } else {
      line('Weight', null);
    }
    if (systolic != null && diastolic != null) {
      line('Blood pressure', '${systolic!.round()}/${diastolic!.round()} mmHg');
    } else {
      line('Blood pressure', null);
    }
    if (glucoseMgdl != null) {
      final g = formatGlucose(glucoseMgdl, unitSystem);
      line('Blood glucose (fasting)', '${g.value} ${g.unit}');
    } else {
      line('Blood glucose (fasting)', null);
    }
    if (steps != null) {
      line('Daily steps', '${steps!.round()} steps');
    } else {
      line('Daily steps', null);
    }

    buf.writeln(
      '\nProvide:\n'
      '1. Overall summary (2–3 sentences)\n'
      '2. What looks OK vs what needs attention, with brief reasons\n'
      '3. Concrete next steps for the next few days\n\n'
      '$_aiDocResponseStyle '
      'This is general wellness guidance, not a formal medical diagnosis.',
    );
    return buf.toString();
  }
}

// ── AI consultation ──────────────────────────────────────────────────────────
// Ported from supabase/functions/ai-consultation.
class AiConsultationService {
  static const _responseStyle = _aiDocResponseStyle;

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
  /// keyword responder only when the backend is unreachable (network/timeout).
  /// Auth failures (401) and budget exhaustion (402) are rethrown for the UI.
  static Future<String> reply(
    String userId,
    String message, {
    String complexity = 'simple',
    bool includeContext = true,
  }) async {
    final payload = includeContext
        ? await _wrapWithPatientContext(userId, message)
        : message;
    try {
      return await ApiClient.chat(
        userId: userId,
        message: payload,
        complexity: complexity,
      );
    } on ApiException catch (e) {
      if (e.isBudgetExhausted || e.isAuthError) rethrow;
      return _localReply(message);
    } catch (_) {
      return _localReply(message);
    }
  }

  /// Chat photo: compress, then analyze with full patient context.
  static Future<String> replyWithPhoto({
    required String userId,
    required String filePath,
    String caption = '',
  }) async {
    final context = await buildFullPatientContext(userId);
    final note = caption.trim().isEmpty
        ? ''
        : '\nPatient note with the photo: "${caption.trim()}"\n';
    final prompt = '''
$context
$note
The patient shared a photo in Ai Doc chat.
Look carefully at the image (meal, lab report, skin, medication, wound, etc.).
Explain what you see, how it may relate to their health data in the app, and give practical advice.
$_responseStyle
''';
    final uploadPath = await compressImageForUpload(
      filePath,
      quality: 60,
      maxWidth: 800,
      maxHeight: 800,
    );
    return ApiClient.analyze(
      userId: userId,
      filePath: uploadPath,
      textLogs: prompt,
      complexity: 'complex',
    );
  }

  /// Builds a full patient picture for Gemini: profile, metric trends,
  /// previous Ai Doc chats, uploaded analyses, and health assessments.
  static Future<String> buildFullPatientContext(String userId) async {
    final db = Db.instance.raw;
    final buf = StringBuffer(
      'You are Ai Doc, the patient\'s personal health assistant in PHA. '
      'Below is their complete history stored in the app. '
      'Compare past and current health indicators when relevant and maintain '
      'continuity with previous consultations.\n\n'
      '$_responseStyle\n',
    );

    final snapshot = await gatherOnboardingHealthData(userId);
    if (snapshot != null && snapshot.hasAnyData) {
      buf.writeln('\n## Profile & latest vitals');
      final s = snapshot;
      if (s.age != null) buf.writeln('- Age: ${s.age} years');
      if (s.gender != null) buf.writeln('- Gender: ${s.gender}');
      if (s.heightCm != null) {
        final h = formatHeight(s.heightCm, s.unitSystem);
        buf.writeln('- Height: ${h.value} ${h.unit}'.trim());
      }
      if (s.weightKg != null) {
        final w = formatWeight(s.weightKg, s.unitSystem);
        buf.writeln('- Weight: ${w.value} ${w.unit}');
      }
      if (s.systolic != null && s.diastolic != null) {
        buf.writeln(
            '- Blood pressure (latest): ${s.systolic!.round()}/${s.diastolic!.round()} mmHg');
      }
      if (s.glucoseMgdl != null) {
        final g = formatGlucose(s.glucoseMgdl, s.unitSystem);
        buf.writeln('- Blood glucose (latest): ${g.value} ${g.unit}');
      }
      if (s.steps != null) {
        buf.writeln('- Daily steps (latest): ${s.steps!.round()}');
      }
    }

    final metrics = await db.query(
      'health_metrics',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recorded_at DESC',
      limit: 120,
    );
    if (metrics.isNotEmpty) {
      buf.writeln('\n## Health indicator history (newest first, per type)');
      final byType = <String, List<Map<String, dynamic>>>{};
      for (final m in metrics) {
        final t = m['metric_type'] as String;
        byType.putIfAbsent(t, () => []).add(m);
      }
      for (final entry in byType.entries) {
        buf.writeln('- ${entry.key}:');
        for (final row in entry.value.take(6)) {
          final at = (row['recorded_at'] as String?)?.substring(0, 10) ?? '';
          buf.writeln('  · $at — ${row['value']}');
        }
      }
    }

    final chats = await db.query(
      'ai_consultations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
      limit: 25,
    );
    if (chats.isNotEmpty) {
      buf.writeln('\n## Previous Ai Doc consultations');
      for (final c in chats) {
        final at = (c['created_at'] as String?)?.substring(0, 16) ?? '';
        buf.writeln('[$at] Patient: ${_clip(c['message'] as String, 500)}');
        buf.writeln('[$at] Ai Doc: ${_clip(c['response'] as String, 800)}');
      }
    }

    final uploads = await db.query(
      'analysis_uploads',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'uploaded_at DESC',
      limit: 5,
    );
    if (uploads.isNotEmpty) {
      buf.writeln('\n## Uploaded medical analyses');
      for (final u in uploads) {
        final at = (u['uploaded_at'] as String?)?.substring(0, 10) ?? '';
        final name = u['file_path'] as String? ?? 'file';
        final analysis = u['analysis'] as String? ?? '';
        buf.writeln('- $at ($name): ${_clip(analysis, 900)}');
      }
    }

    final analyses = await db.query(
      'health_analysis',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'analyzed_at DESC',
      limit: 3,
    );
    if (analyses.isNotEmpty) {
      buf.writeln('\n## In-app health assessments');
      for (final a in analyses) {
        final at = (a['analyzed_at'] as String?)?.substring(0, 10) ?? '';
        buf.writeln(
          '- $at — score ${a['overall_score']}/100 (${a['overall_status']}): '
          '${_clip(a['summary'] as String, 400)}',
        );
      }
    }

    final stress = await db.query(
      'stress_tests',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 5,
    );
    if (stress.isNotEmpty) {
      buf.writeln('\n## Wellness / stress checks');
      for (final s in stress) {
        final at = (s['created_at'] as String?)?.substring(0, 10) ?? '';
        buf.writeln('- $at — score ${s['score']}: ${s['result']}');
      }
    }

    final meals = await db.query(
      'meal_calorie_checks',
      where: 'user_id = ? AND confirmed = 1',
      whereArgs: [userId],
      orderBy: 'checked_at DESC',
      limit: 10,
    );
    if (meals.isNotEmpty) {
      buf.writeln('\n## Recent meal calorie checks');
      for (final m in meals) {
        final at = (m['checked_at'] as String?)?.substring(0, 16) ?? '';
        final kcal = m['calories'];
        final cat = m['category_label'] ?? m['category'];
        buf.writeln(
          '- $at — $cat${kcal != null ? ', ~$kcal kcal' : ''}: '
          '${_clip(m['analysis'] as String, 300)}',
        );
      }
    }

    return buf.toString();
  }

  static Future<String> _wrapWithPatientContext(
    String userId,
    String newMessage,
  ) async {
    final context = await buildFullPatientContext(userId);
    return '$context\n\n---\n\n'
        'Patient\'s new message:\n$newMessage\n\n'
        'Reply now. $_responseStyle';
  }

  static String _clip(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}…';
  }

  /// Loads profile + latest vitals captured during onboarding.
  static Future<OnboardingHealthSnapshot?> gatherOnboardingHealthData(
    String userId,
  ) async {
    final db = Db.instance.raw;
    final profiles =
        await db.query('profiles', where: 'id = ?', whereArgs: [userId]);
    if (profiles.isEmpty) return null;
    final p = profiles.first;

    final metrics = await db.query(
      'health_metrics',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recorded_at DESC',
      limit: 50,
    );
    final latest = <String, double>{};
    for (final m in metrics) {
      latest.putIfAbsent(
        m['metric_type'] as String,
        () => (m['value'] as num).toDouble(),
      );
    }

    var weightKg = (p['weight'] as num?)?.toDouble();
    weightKg ??= latest['weight'];

    return OnboardingHealthSnapshot(
      age: (p['age'] as num?)?.toInt(),
      gender: p['gender'] as String?,
      heightCm: (p['height'] as num?)?.toDouble(),
      weightKg: weightKg,
      systolic: latest['blood_pressure_systolic'],
      diastolic: latest['blood_pressure_diastolic'],
      glucoseMgdl: latest['glucose'],
      steps: latest['steps'],
      unitSystem: p['unit_system'] as String? ?? 'metric',
    );
  }

  /// Sends onboarding health data to Gemini for a quick wellness assessment.
  static Future<String> diagnoseFromOnboarding(String userId) async {
    final data = await gatherOnboardingHealthData(userId);
    if (data == null || !data.hasAnyData) {
      return 'I could not find your onboarding health data yet. '
          'Complete onboarding or log your vitals on the dashboard, then say "yes" again.';
    }

    try {
      return await reply(
        userId,
        data.toDiagnosisPrompt(),
        complexity: 'complex',
      );
    } on ApiException {
      rethrow;
    }
  }

  static bool isAffirmativeConsent(String text) {
    final t = text.toLowerCase().trim();
    const exact = {
      'yes',
      'yeah',
      'yep',
      'yup',
      'sure',
      'ok',
      'okay',
      'please',
      'y',
      'да',
    };
    if (exact.contains(t)) return true;
    return RegExp(
      r'^(yes|yeah|yep|yup|sure|ok|okay|please|use my data|go ahead)(\s|!|\.)?',
    ).hasMatch(t);
  }

  static bool isNegativeConsent(String text) {
    final t = text.toLowerCase().trim();
    const exact = {'no', 'nope', 'nah', 'not now', 'skip', 'нет'};
    if (exact.contains(t)) return true;
    return RegExp(r'^(no|nope|nah|skip|not now)(\s|!|\.)?').hasMatch(t);
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

  /// Persists an uploaded analysis as a chat exchange for history.
  static Future<void> recordAnalysisInChat(
    String userId, {
    required String fileName,
    required String analysis,
  }) async {
    await save(
      userId,
      'I uploaded my analysis: $fileName',
      analysis,
    );
  }

  /// Profile + recent vitals sent with `/analyze` so the backend has context.
  static Future<String> buildProfileTextLogs(String userId) async {
    final db = Db.instance.raw;
    final profiles =
        await db.query('profiles', where: 'id = ?', whereArgs: [userId]);
    final metrics = await db.query(
      'health_metrics',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recorded_at DESC',
      limit: 20,
    );
    final buf = StringBuffer();
    if (profiles.isNotEmpty) {
      final p = profiles.first;
      final parts = <String>[];
      final age = p['age'];
      if (age != null) parts.add('age $age');
      final gender = p['gender'];
      if (gender != null) parts.add('gender $gender');
      final height = p['height'];
      if (height != null) parts.add('height ${height}cm');
      final weight = p['weight'];
      if (weight != null) parts.add('weight ${weight}kg');
      if (parts.isNotEmpty) buf.writeln('Profile: ${parts.join(', ')}.');
    }
    final latest = <String, double>{};
    for (final m in metrics) {
      final t = m['metric_type'] as String;
      latest.putIfAbsent(t, () => (m['value'] as num).toDouble());
    }
    if (latest.isNotEmpty) {
      buf.write(
        'Recent metrics: ${latest.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
      );
    }
    return buf.toString();
  }
}

// ── Health analysis ──────────────────────────────────────────────────────────
// Narrative layer on top of Health Index: same score/status, richer findings
// and actionable advice across every Index component that has data.
class HealthAnalysisService {
  static Finding _bp(double s, double d, {int? age, String? gender}) {
    final c = BloodPressure.classify(s, d, age: age, gender: gender);
    return Finding(
      category: 'Blood Pressure',
      status: c.status,
      value: c.label,
      message: c.message,
    );
  }

  static Finding _glucose(double gMgdl, UnitSystem sys) {
    final c = GlucoseGuidelines.classify(gMgdl, sys);
    return Finding(
      category: 'Blood Glucose',
      status: c.status,
      value: c.label,
      message: c.message,
    );
  }

  static Finding _weight(double weight, double? heightCm) {
    final c = BmiGuidelines.classify(weight, heightCm);
    return Finding(
      category: c.band == 'weight_only' ? 'Weight' : 'Weight / BMI',
      status: c.status,
      value: c.label,
      message: c.message,
    );
  }

  static Finding _steps(double steps) {
    final c = StepsGuidelines.classify(steps);
    return Finding(
      category: 'Daily Activity',
      status: c.status,
      value: c.label,
      message: c.message,
    );
  }

  static Finding _calories(double calories, double steps) {
    final expMin = steps * 0.04;
    final expMax = steps * 0.06;
    if (calories >= expMin && calories <= expMax * 1.5) {
      return Finding(
        category: 'Calorie Burn',
        status: 'good',
        value: '${calories.toInt()} kcal',
        message:
            'Calorie expenditure looks consistent with your steps. Pair it with '
            'balanced meals to support recovery.',
      );
    }
    return Finding(
      category: 'Calorie Burn',
      status: 'info',
      value: '${calories.toInt()} kcal',
      message:
          'You burned ${calories.toInt()} kcal from activity. Use meal logging '
          'to match intake to your goals.',
    );
  }

  static Finding _wellness(int score) {
    final c = WellnessGuidelines.classify(score);
    return Finding(
      category: 'Mental Wellness',
      status: c.status,
      value: c.label,
      message: c.message,
    );
  }

  static Finding? _smoking(Map<String, dynamic> h) {
    final smokes = (h['smokes'] as num).toInt() == 1;
    if (!smokes) {
      return Finding(
        category: 'Smoking',
        status: 'good',
        value: 'Non-smoker',
        message:
            'No smoking reported — one of the strongest protective factors for '
            'heart and lung health.',
      );
    }
    final level = h['smoking_level'] as String?;
    final label = switch (level) {
      'less_than_one_pack' => '<1 pack/day',
      'one_pack' => '~1 pack/day',
      'more_than_one_pack' => '>1 pack/day',
      _ => 'Active smoker',
    };
    return Finding(
      category: 'Smoking',
      status: level == 'less_than_one_pack' ? 'warning' : 'critical',
      value: label,
      message:
          'Smoking is a top Health Index risk factor. Set a quit date, remove '
          'triggers, and use Plus+ → Check Your Bad Habits to track progress.',
    );
  }

  static Finding? _alcohol(Map<String, dynamic> h) {
    final drinks = (h['drinks_alcohol'] as num).toInt() == 1;
    if (!drinks) {
      return Finding(
        category: 'Alcohol',
        status: 'good',
        value: 'None',
        message:
            'No alcohol use reported — helpful for BP, sleep, and liver health.',
      );
    }
    final level = h['alcohol_level'] as String?;
    final (status, label, tip) = switch (level) {
      'occasionally' => (
          'info',
          'Occasional',
          'Keep alcohol occasional and alcohol-free most days of the week.',
        ),
      'regularly' => (
          'warning',
          'Regular',
          'Cut toward fewer drinking days; alcohol raises BP and calorie load.',
        ),
      'heavy' => (
          'critical',
          'Heavy',
          'Heavy use strongly hurts your Health Index — seek support to cut down safely.',
        ),
      _ => (
          'warning',
          'Drinks alcohol',
          'Track frequency this week and aim for several alcohol-free days.',
        ),
    };
    return Finding(category: 'Alcohol', status: status, value: label, message: tip);
  }

  static Finding? _screenTime(Map<String, dynamic> h) {
    final level = h['social_media_level'] as String?;
    if (level == null) return null;
    final (status, label, tip) = switch (level) {
      'rarely' => (
          'good',
          'Rarely',
          'Low social-media load — good for sleep and focus.',
        ),
      'under_hour' => (
          'info',
          '<1 h/day',
          'Reasonable screen habit. Keep phones out of the bedroom if sleep slips.',
        ),
      'one_to_two_hours' => (
          'info',
          '1–2 h/day',
          'Moderate use. Try a 30-minute evening cutoff to protect recovery.',
        ),
      'constantly' => (
          'warning',
          'Constant',
          'High screen time crowds out movement and sleep. Set app limits and '
              'swap one scroll block for a walk.',
        ),
      _ => (
          'info',
          level,
          'Review screen habits — small evening limits often help wellness scores.',
        ),
    };
    return Finding(
      category: 'Screen Time',
      status: status,
      value: label,
      message: tip,
    );
  }

  static Finding? _nutrition(List<Map<String, dynamic>> meals) {
    if (meals.isEmpty) return null;
    var excellent = 0, ok = 0, attention = 0;
    for (final m in meals) {
      switch (m['category'] as String?) {
        case 'excellent':
          excellent++;
        case 'satisfactory':
          ok++;
        case 'attention':
          attention++;
      }
    }
    final n = meals.length;
    final value = '$n recent meals';
    if (attention >= (n + 1) ~/ 2) {
      return Finding(
        category: 'Nutrition',
        status: 'warning',
        value: value,
        message:
            'Several recent meals need attention. Favor vegetables, protein, and '
            'fewer ultra-processed snacks; log the next meal for feedback.',
      );
    }
    if (excellent >= ok && attention == 0) {
      return Finding(
        category: 'Nutrition',
        status: 'good',
        value: value,
        message:
            'Recent meal quality looks strong. Keep the pattern — it supports '
            'glucose and weight in your Health Index.',
      );
    }
    return Finding(
      category: 'Nutrition',
      status: 'info',
      value: value,
      message:
          'Mixed meal quality lately. Aim for one upgrade per day (more fiber '
          'or protein, less sugary drinks).',
    );
  }

  static Finding? _psychotest(Map<String, dynamic> row) {
    final total = (row['total_score'] as num).toInt();
    final c = PsychoGuidelines.classifyLoad(total);
    return Finding(
      category: 'PsychoTest',
      status: c.status,
      value: 'Load $total · ${c.label}',
      message: c.message,
    );
  }

  /// Map Index status → Insights card status (`poor` → `needs_attention`).
  static String _uiStatus(String indexStatus) {
    if (indexStatus == 'poor') return 'needs_attention';
    return indexStatus;
  }

  static String _summary({
    required String uiStatus,
    required int score,
    required List<Finding> findings,
    required HealthIndexResult index,
  }) {
    const openers = {
      'excellent': 'Your Health Index is excellent.',
      'good': 'Your Health Index looks good overall.',
      'fair': 'Your Health Index is fair — a few levers will move it up.',
      'needs_attention':
          'Your Health Index needs attention — focus on the highest-impact gaps below.',
    };
    var s = '${openers[uiStatus] ?? 'Here is your health summary.'} Score $score/100 matches the Home Health Index.';

    final ranked = _rankedGaps(index);
    final strengths = findings.where((f) => f.status == 'good').toList();
    if (strengths.isNotEmpty) {
      final names = strengths.take(3).map((f) => f.category).join(', ');
      s += ' Strengths: $names.';
    }
    if (ranked.isNotEmpty) {
      final focus = ranked.take(3).map((e) => _componentLabel(e.key)).join(', ');
      s += ' Biggest Index drag right now: $focus.';
    }
    return s;
  }

  static List<MapEntry<String, double>> _rankedGaps(HealthIndexResult index) {
    final gaps = <MapEntry<String, double>>[];
    for (final e in index.componentScores.entries) {
      final w = index.appliedWeights[e.key] ?? 0;
      if (w <= 0) continue;
      final gap = (100 - e.value).clamp(0, 100) * w;
      if (e.value >= 85) continue;
      gaps.add(MapEntry(e.key, gap));
    }
    gaps.sort((a, b) => b.value.compareTo(a.value));
    return gaps;
  }

  static String _componentLabel(String key) => switch (key) {
        'blood_pressure' => 'Blood Pressure',
        'smoking' => 'Smoking',
        'glucose' => 'Blood Glucose',
        'bmi' => 'Weight / BMI',
        'activity' => 'Activity',
        'alcohol' => 'Alcohol',
        'nutrition' => 'Nutrition',
        'wellness' => 'Mental Wellness',
        'psychotest' => 'PsychoTest',
        'screen_time' => 'Screen Time',
        _ => key,
      };

  static List<Recommendation> _recommendations({
    required HealthIndexResult index,
    required List<Finding> findings,
  }) {
    final recs = <Recommendation>[];
    final seen = <String>{};

    void add(String priority, String text) {
      final key = text.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      recs.add(Recommendation(priority: priority, text: text));
    }

    for (final gap in _rankedGaps(index)) {
      final score = index.componentScores[gap.key] ?? 100;
      final priority = score < 45
          ? 'high'
          : score < 70
              ? 'medium'
              : 'low';
      for (final tip in _adviceForComponent(gap.key, score)) {
        add(priority, tip);
        if (recs.length >= 8) break;
      }
      if (recs.length >= 8) break;
    }

    // Always include one concrete next action from critical findings.
    for (final f in findings.where((f) => f.status == 'critical')) {
      add('high', '${f.category}: ${f.message}');
      if (recs.length >= 8) break;
    }

    if (recs.isEmpty) {
      add(
        'low',
        'All scored Health Index factors look solid. Keep logging vitals, '
        'meals, and activity so trends stay visible.',
      );
    } else if (index.score >= 70) {
      add(
        'low',
        'Protect what works: keep today’s activity and meal pattern, and '
        're-check BP/glucose on a consistent schedule.',
      );
    }

    return recs.take(8).toList();
  }

  static List<String> _adviceForComponent(String key, double score) {
    switch (key) {
      case 'blood_pressure':
        return [
          'Blood pressure: measure at the same time of day, seated and rested. '
              'Cut packaged salt, and walk most days — lifestyle is first-line '
              'before medication decisions.',
          if (score < 60)
            'If readings stay ≥140/90 on repeat checks, book a clinician visit '
                'with your home log.',
        ];
      case 'smoking':
        return [
          'Smoking: pick a quit day this week, tell someone, and remove cigarettes '
              'from easy reach. Update Plus+ → Check Your Bad Habits after you cut down.',
        ];
      case 'glucose':
        return [
          'Glucose: swap sugary drinks for water, add fiber/protein to breakfast, '
              'and take a 10–15 minute walk after your largest meal.',
          if (score < 50)
            'If fasting glucose stays high, ask your clinician about labs '
                '(HbA1c) rather than relying on one reading.',
        ];
      case 'bmi':
        return [
          'Weight: target a gentle weekly change, not a crash diet — prioritize '
              'protein, vegetables, and your step habit from Health Insights.',
          'Log meals with Calorie Check so nutrition advice matches what you actually eat.',
        ];
      case 'activity':
        return [
          'Activity: schedule two fixed walk slots (e.g. after lunch and evening). '
              'Answer the physical-activity check-in so adherence counts in your Index.',
        ];
      case 'alcohol':
        return [
          'Alcohol: plan alcohol-free days first, then shrink portion size on '
              'drinking days. This often improves sleep and next-day BP.',
        ];
      case 'nutrition':
        return [
          'Nutrition: upgrade one meal today — more plants and protein, less '
              'ultra-processed snacks. Re-scan a meal for fresh feedback.',
        ];
      case 'wellness':
        return [
          'Wellness: protect a consistent sleep window and do one short recovery '
              'block daily (breathing, stretch, or outdoor light). Retake the '
              'Wellness Check after a few days.',
        ];
      case 'psychotest':
        return [
          'PsychoTest load: reduce stacked stressors where you can, and use brief '
              'body-calming routines. Retake PsychoTest when life is calmer to '
              'see the Index move.',
        ];
      case 'screen_time':
        return [
          'Screen time: set a hard evening cutoff and replace one scroll session '
              'with movement — it supports both activity and wellness scores.',
        ];
      default:
        return [
          'Review ${_componentLabel(key)} in the app and make one small change today.',
        ];
    }
  }

  static Future<HealthAnalysis?> latest(String userId) async {
    final rows = await Db.instance.raw.query(
      'health_analysis',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'analyzed_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : HealthAnalysis.fromRow(rows.first);
  }

  /// Fresh narrative analysis aligned with Health Index (same score/status).
  static Future<HealthAnalysis> run(String userId) async {
    final db = Db.instance.raw;

    // Single source of truth for the headline number.
    final index = await HealthIndexService.recalculate(userId);

    final metrics = await db.query(
      'health_metrics',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'recorded_at DESC',
      limit: 80,
    );
    final wellnessRows = await db.query(
      'stress_tests',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    final profileRows =
        await db.query('profiles', where: 'id = ?', whereArgs: [userId]);
    final habitRows = await db.query(
      'bad_habit_checks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    final psychoRows = await db.query(
      'psychotest_results',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    final meals = await db.query(
      'meal_calorie_checks',
      where: 'user_id = ? AND confirmed = 1',
      whereArgs: [userId],
      orderBy: 'checked_at DESC',
      limit: 5,
    );

    final unitSystem = profileRows.isNotEmpty
        ? (profileRows.first['unit_system'] as String?) ?? 'metric'
        : 'metric';
    final age = profileRows.isNotEmpty
        ? (profileRows.first['age'] as num?)?.toInt()
        : null;
    final gender =
        profileRows.isNotEmpty ? profileRows.first['gender'] as String? : null;
    final heightCm = profileRows.isNotEmpty
        ? (profileRows.first['height'] as num?)?.toDouble()
        : null;

    final latest = <String, double>{};
    for (final m in metrics) {
      latest.putIfAbsent(
        m['metric_type'] as String,
        () => (m['value'] as num).toDouble(),
      );
    }

    final findings = <Finding>[];
    final sys = latest['blood_pressure_systolic'];
    final dia = latest['blood_pressure_diastolic'];
    if (sys != null && dia != null) {
      findings.add(_bp(sys, dia, age: age, gender: gender));
    }
    final glucose = latest['glucose'];
    if (glucose != null) findings.add(_glucose(glucose, unitSystem));

    final weight =
        latest['weight'] ?? (profileRows.isNotEmpty
            ? (profileRows.first['weight'] as num?)?.toDouble()
            : null);
    if (weight != null) findings.add(_weight(weight, heightCm));

    final steps = latest['steps'];
    if (steps != null) findings.add(_steps(steps));
    final calories = latest['calories'];
    if (calories != null && steps != null) {
      findings.add(_calories(calories, steps));
    }
    if (wellnessRows.isNotEmpty) {
      findings.add(_wellness((wellnessRows.first['score'] as num).toInt()));
    }
    if (habitRows.isNotEmpty) {
      final smoking = _smoking(habitRows.first);
      if (smoking != null) findings.add(smoking);
      final alcohol = _alcohol(habitRows.first);
      if (alcohol != null) findings.add(alcohol);
      final screens = _screenTime(habitRows.first);
      if (screens != null) findings.add(screens);
    }
    final nutrition = _nutrition(meals);
    if (nutrition != null) findings.add(nutrition);
    if (psychoRows.isNotEmpty) {
      final psycho = _psychotest(psychoRows.first);
      if (psycho != null) findings.add(psycho);
    }

    // Cross-parameter cardiometabolic correlations (AHA/ADA/ESC/IDF).
    final correlation = ClinicalCorrelationEngine.analyze(ClinicalInput(
      age: age,
      heightCm: heightCm,
      weightKg: weight,
      gender: gender,
      systolic: sys,
      diastolic: dia,
      fastingGlucoseMgdl: glucose,
    ));
    final correlationFindings = correlation.toFindings();
    bool hasWeightFinding(String category) =>
        category == 'weight' || category == 'weight / bmi';
    final existingCategories =
        findings.map((f) => f.category.toLowerCase()).toSet();
    final bpIsGood = findings.any(
      (f) =>
          f.category.toLowerCase() == 'blood pressure' &&
          (f.status == 'good' || f.status == 'info'),
    );
    for (final f in correlationFindings) {
      final cat = f.category.toLowerCase();
      // Never show "High BP…" flags when the main BP finding is already healthy.
      if (bpIsGood &&
          cat.contains('what this means') &&
          (f.value?.toLowerCase().contains('high bp') == true ||
              f.message.toLowerCase().contains('high blood pressure'))) {
        continue;
      }
      final duplicatesExistingWeight =
          hasWeightFinding(cat) &&
          existingCategories.any(hasWeightFinding);
      // Add dual-guideline & syndrome findings; skip duplicate BMI/BP/glucose headlines.
      if (cat.contains('ideal weight') ||
          cat.contains('healthy weight') ||
          cat.contains('metabolic') ||
          cat.contains('cardiometabolic') ||
          cat.contains('overall heart') ||
          cat.contains('clinical pattern') ||
          cat.contains('what this means') ||
          cat.contains('for your age') ||
          cat.contains('age-specific') ||
          cat.contains('aha/acc')) {
        findings.add(f);
      } else if (!existingCategories.contains(cat) &&
          !duplicatesExistingWeight) {
        findings.add(f);
      }
    }

    if (findings.isEmpty && index.componentScores.isEmpty) {
      throw Exception('No health data found. Please log some metrics first.');
    }

    // Sort: critical → warning → info → good
    const order = {'critical': 0, 'warning': 1, 'info': 2, 'good': 3};
    findings.sort(
      (a, b) => (order[a.status] ?? 9).compareTo(order[b.status] ?? 9),
    );

    final score = index.score;
    final status = _uiStatus(index.status);
    final summary = _summary(
      uiStatus: status,
      score: score,
      findings: findings,
      index: index,
    );
    final recommendations = _recommendations(index: index, findings: findings);
    final correlationRecs = correlation.toRecommendations();
    for (final r in correlationRecs) {
      if (!recommendations.any((x) => x.text == r.text)) {
        recommendations.insert(0, r);
      }
    }

    final analyzedAt = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    await db.insert('health_analysis', {
      'id': id,
      'user_id': userId,
      'overall_status': status,
      'overall_score': score,
      'summary': summary,
      'findings': jsonEncode(findings.map((f) => f.toJson()).toList()),
      'recommendations':
          jsonEncode(recommendations.map((r) => r.toJson()).toList()),
      'analyzed_at': analyzedAt,
    });
    return (await latest_(id))!;
  }

  static Future<HealthAnalysis?> latest_(String id) async {
    final rows =
        await Db.instance.raw.query('health_analysis', where: 'id = ?', whereArgs: [id]);
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

    // One live row per metric for today; yesterday stays frozen after midnight.
    for (final m in [
      {'metric_type': 'steps', 'value': steps.toDouble()},
      {'metric_type': 'distance', 'value': distanceKm},
      {'metric_type': 'calories', 'value': calories},
    ]) {
      await DailyMetricStore.upsertToday(
        userId: userId,
        metricType: m['metric_type'] as String,
        value: m['value'] as double,
        source: 'health_connect',
      );
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
    await HealthIndexService.recalculate(userId);
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
