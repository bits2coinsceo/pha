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
import 'locale_controller.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/medical_l10n.dart';
import 'units.dart';

const _uuid = Uuid();
final _rng = Random();

const _aiDocDailyBriefStyle =
    'RESPONSE STYLE (mandatory): Be clear, practical, and a little more detailed. '
    'Start with a short direct answer (2–3 sentences). '
    'Then add a short section with what looks good, what needs attention, and why. '
    'Finish with concrete next steps (3–6 bullets). '
    'Aim for roughly 150–250 words — enough to explain, not a lecture. '
    'Use plain patient-friendly language. No greetings, no fluff, no repeated disclaimers. '
    'Remind once that this is wellness guidance, not a formal medical diagnosis.';

const _aiDocFocusedReplyStyle =
    'RESPONSE STYLE (mandatory): Answer ONLY the patient\'s specific question. '
    'Keep it concise (roughly 60–120 words). '
    'Do NOT repeat a full vitals review or restate blood pressure, glucose, weight, '
    'steps, or Health Index unless the question is directly about those metrics. '
    'Do NOT add "what looks good / what needs attention" sections — that was already '
    'covered in today\'s first message. '
    'Use the patient history above only when it directly helps answer this question. '
    'No greetings, no fluff. One brief wellness disclaimer at most.';

const _aiDocSupplementGuidance =
    'DIETARY SUPPLEMENTS & BIOACTIVE ADDITIVES (including БАД): When the patient '
    'asks about vitamins, minerals, herbal products, probiotics, or dietary supplements, '
    'give practical, evidence-informed suggestions tailored to their profile and question '
    '(what may help, typical timing/dose ranges when well-established, cautions or '
    'interactions when relevant). Do not refuse solely because the topic is a supplement. '
    'End every supplement-related answer with one short sentence advising them to confirm '
    'with their doctor or pharmacist before starting, stopping, or changing supplements. '
    'If they already take a product and ask follow-up questions, answer those directly first; '
    'add a brief consult-a-specialist note at the end only.';

/// Legacy alias used in onboarding / upload prompts that expect the daily format.
const _aiDocResponseStyle = _aiDocDailyBriefStyle;

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

  /// Async variant that appends language + response rules.
  Future<String> toDiagnosisPromptLocalized() async {
    final base = toDiagnosisPrompt();
    final rules = await AiConsultationService.aiDocResponseRules(dailyBrief: true);
    return '$base\n\n$rules';
  }
}

// ── AI consultation ──────────────────────────────────────────────────────────
// Ported from supabase/functions/ai-consultation.
class AiConsultationService {
  /// Language, response style, and supplement policy for Gemini prompts.
  static Future<String> aiDocResponseRules({required bool dailyBrief}) async {
    final lang = await LocaleController.aiLanguageInstruction();
    final style = dailyBrief ? _aiDocDailyBriefStyle : _aiDocFocusedReplyStyle;
    return '$lang$style\n$_aiDocSupplementGuidance';
  }

  /// Prompt for uploaded lab PDFs / images (not DICOM).
  static Future<String> buildAnalysisUploadPrompt(String userId) async {
    final context = await buildFullPatientContext(userId);
    final rules = await aiDocResponseRules(dailyBrief: true);
    return '''
$context

The patient uploaded a medical lab report or analysis file (PDF or image).
Read all visible values, explain what is normal vs out of range in plain language,
relate findings to the patient profile above when relevant, and suggest sensible next steps.
Quote test names as written on the document; explain everything else in the app UI language.
$rules
''';
  }

  /// Asks the backend (Vertex AI Gemini) for a reply. Falls back to the local
  /// keyword responder only when the backend is unreachable (network/timeout).
  /// Auth failures (401) and budget exhaustion (402) are rethrown for the UI.
  static Future<String> reply(
    String userId,
    String message, {
    String complexity = 'simple',
    bool includeContext = true,
    bool? dailyBrief,
  }) async {
    final brief = dailyBrief ?? await isFirstChatMessageToday(userId);
    final payload = includeContext
        ? await _wrapWithPatientContext(
            userId,
            message,
            dailyBrief: brief,
          )
        : message;
    try {
      return await ApiClient.chat(
        userId: userId,
        message: payload,
        complexity: complexity,
      );
    } on ApiException catch (e) {
      if (e.isBudgetExhausted || e.isAuthError) rethrow;
      return await _localReply(message);
    } catch (_) {
      return await _localReply(message);
    }
  }

  /// Chat photo: compress, then analyze with full patient context.
  static Future<String> replyWithPhoto({
    required String userId,
    required String filePath,
    String caption = '',
  }) async {
    final context = await buildFullPatientContext(userId);
    final rules = await aiDocResponseRules(dailyBrief: false);
    final note = caption.trim().isEmpty
        ? ''
        : '\nPatient note with the photo: "${caption.trim()}"\n';
    final prompt = '''
$context
$note
The patient shared a photo in Ai Doc chat.
Look carefully at the image (meal, lab report, skin, medication, wound, etc.).
Explain what you see and give practical advice tied to the photo.
Only mention stored vitals if directly relevant to what is in the image.
Quote labels on the document as written; explain everything in the app UI language.
$rules
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

  /// Thorough DICOM imaging review — pathology-focused prompt for Gemini.
  static Future<String> analyzeDicomUpload({
    required String userId,
    required String filePath,
  }) async {
    final context = await buildFullPatientContext(userId);
    final rules = await aiDocResponseRules(dailyBrief: true);
    final prompt = '''
$context

The patient uploaded a DICOM medical imaging study for an in-depth clinical review.
Perform a systematic, radiology-style analysis with extra care for pathology:

1. Identify modality (CT, MRI, X-ray, ultrasound, PET, etc.) and anatomical region.
2. Describe visible structures and any abnormal findings in plain language.
3. Flag signs that may suggest pathology: masses, nodules, fractures, hemorrhage,
   inflammation, effusion, obstruction, ischemia, or other concerning patterns.
4. Note study limitations (single image vs series, quality, missing contrast phases).
5. Relate findings to the patient's profile and history above when relevant.
6. Recommend sensible next steps (specialist referral, repeat imaging, urgent care)
   when warranted — use cautious, non-diagnostic language.

This is clinical decision support only; the patient must confirm with a radiologist
or treating physician.
$rules
''';
    return ApiClient.analyze(
      userId: userId,
      filePath: filePath,
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
      'Use this background data to inform answers — do not recite all metrics '
      'unless the patient asks or it is their first message of the day.\n\n'
      '$_aiDocSupplementGuidance\n',
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
    String newMessage, {
    required bool dailyBrief,
  }) async {
    final context = await buildFullPatientContext(userId);
    final rules = await aiDocResponseRules(dailyBrief: dailyBrief);
    if (dailyBrief) {
      return '$context\n\n---\n\n'
          'Patient\'s new message:\n$newMessage\n\n'
          'This is the patient\'s first Ai Doc message today. '
          'Give a concise daily health brief (what looks good, what needs attention) '
          'and answer their question.\n$rules';
    }
    return '$context\n\n---\n\n'
        'Patient\'s new message:\n$newMessage\n\n'
        'Reply now.\n$rules';
  }

  /// True when the user has not yet sent an Ai Doc message today (local day).
  static Future<bool> isFirstChatMessageToday(String userId) async {
    if (!Db.instance.isReady) return true;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await Db.instance.raw.query(
      'ai_consultations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 20,
    );
    for (final r in rows) {
      final at = DateTime.parse(r['created_at'] as String).toLocal();
      if (!at.isBefore(start) && at.isBefore(end)) return false;
    }
    return true;
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
        await data.toDiagnosisPromptLocalized(),
        complexity: 'complex',
        dailyBrief: true,
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

  static Future<String> _localReply(String message) async {
    final l10n = await LocaleController.loadLocalizations();
    final lower = message.toLowerCase();
    if (lower.contains('sleep')) {
      return _rng.nextBool() ? l10n.aiOfflineSleep1 : l10n.aiOfflineSleep2;
    }
    if (lower.contains('exercise') ||
        lower.contains('activity') ||
        lower.contains('walk')) {
      return _rng.nextBool() ? l10n.aiOfflineExercise1 : l10n.aiOfflineExercise2;
    }
    if (lower.contains('stress') || lower.contains('anx')) {
      return _rng.nextBool() ? l10n.aiOfflineStress1 : l10n.aiOfflineStress2;
    }
    if (lower.contains('nutrition') ||
        lower.contains('diet') ||
        lower.contains('food') ||
        lower.contains('eat')) {
      return _rng.nextBool() ? l10n.aiOfflineNutrition1 : l10n.aiOfflineNutrition2;
    }
    if (lower.contains('weight') || lower.contains('bmi')) {
      return _rng.nextBool() ? l10n.aiOfflineWeight1 : l10n.aiOfflineWeight2;
    }
    return _rng.nextBool() ? l10n.aiOfflineDefault1 : l10n.aiOfflineDefault2;
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
    String? userMessage,
  }) async {
    final msg = userMessage ?? 'I uploaded my analysis: $fileName';
    await save(userId, msg, analysis);
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
  static Finding _bp(double s, double d, AppLocalizations l10n, {int? age, String? gender}) {
    final c = BloodPressure.classify(s, d, age: age, gender: gender);
    return Finding(
      category: l10n.categoryBloodPressure,
      status: c.status,
      value: c.label.replaceAll('mmHg', l10n.unitMmhg),
      message: l10n.bpMessage(c.band),
    );
  }

  static Finding _glucose(double gMgdl, UnitSystem sys, AppLocalizations l10n) {
    final c = GlucoseGuidelines.classify(gMgdl, sys);
    return Finding(
      category: l10n.categoryBloodGlucose,
      status: c.status,
      value: c.label,
      message: l10n.glucoseMessage(c.band),
    );
  }

  static Finding _weight(double weight, double? heightCm, AppLocalizations l10n) {
    final c = BmiGuidelines.classify(weight, heightCm);
    final String value;
    if (c.band == 'weight_only' || heightCm == null || heightCm <= 0) {
      value = '${weight.toStringAsFixed(1)} ${l10n.unitKg}';
    } else {
      final bmi = weight / ((heightCm / 100) * (heightCm / 100));
      value = l10n.clinicalBmiValue(bmi.toStringAsFixed(1));
    }
    return Finding(
      category: c.band == 'weight_only' ? l10n.categoryWeight : l10n.categoryWeightBmi,
      status: c.status,
      value: value,
      message: l10n.bmiMessage(c.band),
    );
  }

  static Finding _steps(double steps, AppLocalizations l10n) {
    final c = StepsGuidelines.classify(steps);
    return Finding(
      category: l10n.categoryDailyActivity,
      status: c.status,
      value: l10n.stepsLabel('${steps.round()}'),
      message: l10n.stepsFeedback(steps.round()).message,
    );
  }

  static Finding _calories(double calories, double steps, AppLocalizations l10n) {
    final expMin = steps * 0.04;
    final expMax = steps * 0.06;
    if (calories >= expMin && calories <= expMax * 1.5) {
      return Finding(
        category: l10n.categoryCalorieBurn,
        status: 'good',
        value: '${calories.toInt()} ${l10n.unitKcal}',
        message: l10n.calorieBurnGood,
      );
    }
    return Finding(
      category: l10n.categoryCalorieBurn,
      status: 'info',
      value: '${calories.toInt()} ${l10n.unitKcal}',
      message: l10n.calorieBurnInfo(calories.toInt()),
    );
  }

  static Finding _wellness(int score, AppLocalizations l10n) {
    final c = WellnessGuidelines.classify(score);
    return Finding(
      category: l10n.categoryMentalWellness,
      status: c.status,
      value: c.label,
      message: l10n.wellnessMessage(c.band),
    );
  }

  static Finding? _smoking(Map<String, dynamic> h, AppLocalizations l10n) {
    final smokes = (h['smokes'] as num).toInt() == 1;
    if (!smokes) {
      return Finding(
        category: l10n.categorySmoking,
        status: 'good',
        value: l10n.smokingNonSmoker,
        message: l10n.smokingGood,
      );
    }
    final level = h['smoking_level'] as String?;
    final label = switch (level) {
      'less_than_one_pack' => l10n.smokingLessPack,
      'one_pack' => l10n.smokingOnePack,
      'more_than_one_pack' => l10n.smokingMorePack,
      _ => l10n.smokingActive,
    };
    return Finding(
      category: l10n.categorySmoking,
      status: level == 'less_than_one_pack' ? 'warning' : 'critical',
      value: label,
      message: l10n.smokingWarning,
    );
  }

  static Finding? _alcohol(Map<String, dynamic> h, AppLocalizations l10n) {
    final drinks = (h['drinks_alcohol'] as num).toInt() == 1;
    if (!drinks) {
      return Finding(
        category: l10n.categoryAlcohol,
        status: 'good',
        value: l10n.alcoholNone,
        message: l10n.alcoholGood,
      );
    }
    final level = h['alcohol_level'] as String?;
    final (status, label, tip) = switch (level) {
      'occasionally' => ('info', l10n.alcoholOccasional, l10n.alcoholOccasionalTip),
      'regularly' => ('warning', l10n.alcoholRegular, l10n.alcoholRegularTip),
      'heavy' => ('critical', l10n.alcoholHeavy, l10n.alcoholHeavyTip),
      _ => ('warning', l10n.alcoholDefault, l10n.alcoholDefaultTip),
    };
    return Finding(category: l10n.categoryAlcohol, status: status, value: label, message: tip);
  }

  static Finding? _screenTime(Map<String, dynamic> h, AppLocalizations l10n) {
    final level = h['social_media_level'] as String?;
    if (level == null) return null;
    final (status, label, tip) = switch (level) {
      'rarely' => ('good', l10n.screenRarely, l10n.screenRarelyTip),
      'under_hour' => ('info', l10n.screenUnderHour, l10n.screenUnderHourTip),
      'one_to_two_hours' => ('info', l10n.screenOneTwoHours, l10n.screenOneTwoTip),
      'constantly' => ('warning', l10n.screenConstant, l10n.screenConstantTip),
      _ => ('info', level, l10n.screenDefaultTip),
    };
    return Finding(
      category: l10n.categoryScreenTime,
      status: status,
      value: label,
      message: tip,
    );
  }

  static Finding? _nutrition(List<Map<String, dynamic>> meals, AppLocalizations l10n) {
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
    final value = l10n.nutritionRecentMeals(n);
    if (attention >= (n + 1) ~/ 2) {
      return Finding(
        category: l10n.categoryNutrition,
        status: 'warning',
        value: value,
        message: l10n.nutritionWarning,
      );
    }
    if (excellent >= ok && attention == 0) {
      return Finding(
        category: l10n.categoryNutrition,
        status: 'good',
        value: value,
        message: l10n.nutritionGood,
      );
    }
    return Finding(
      category: l10n.categoryNutrition,
      status: 'info',
      value: value,
      message: l10n.nutritionInfo,
    );
  }

  static Finding? _psychotest(Map<String, dynamic> row, AppLocalizations l10n) {
    final total = (row['total_score'] as num).toInt();
    final c = PsychoGuidelines.classifyLoad(total);
    final label = switch (c.band) {
      'low' => l10n.psychoLow,
      'moderate' => l10n.psychoModerate,
      _ => l10n.psychoHigh,
    };
    final msg = switch (c.band) {
      'low' => l10n.psychoLowMsg,
      'moderate' => l10n.psychoModerateMsg,
      _ => l10n.psychoHighMsg,
    };
    return Finding(
      category: l10n.categoryPsychoTest,
      status: c.status,
      value: l10n.psychoLoad(total, label),
      message: msg,
    );
  }

  /// Map Index status → Insights card status (`poor` → `needs_attention`).
  static String _uiStatus(String indexStatus) {
    if (indexStatus == 'poor') return 'needs_attention';
    return indexStatus;
  }

  static String _summary({
    required AppLocalizations l10n,
    required String uiStatus,
    required int score,
    required List<Finding> findings,
    required HealthIndexResult index,
  }) {
    final gapKeys = _rankedGaps(index).map((e) => e.key).toList();
    return l10n.analysisSummary(
      uiStatus,
      score,
      findings.map((f) => (category: f.category, status: f.status)).toList(),
      gapKeys,
    );
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

  static String _componentLabel(String key, AppLocalizations l10n) =>
      l10n.componentLabel(key);

  static List<Recommendation> _recommendations({
    required AppLocalizations l10n,
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
      for (final tip in _adviceForComponent(gap.key, score, l10n)) {
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
        l10n.analysisAllSolid,
      );
    } else if (index.score >= 70) {
      add(
        'low',
        l10n.adviceProtectWhatWorks,
      );
    }

    return recs.take(8).toList();
  }

  static List<String> _adviceForComponent(String key, double score, AppLocalizations l10n) {
    switch (key) {
      case 'blood_pressure':
        return [
          l10n.adviceBloodPressure1,
          if (score < 60) l10n.adviceBloodPressure2,
        ];
      case 'smoking':
        return [l10n.adviceSmoking];
      case 'glucose':
        return [
          l10n.adviceGlucose1,
          if (score < 50) l10n.adviceGlucose2,
        ];
      case 'bmi':
        return [l10n.adviceBmi1, l10n.adviceBmi2];
      case 'activity':
        return [l10n.adviceActivity];
      case 'alcohol':
        return [l10n.adviceAlcohol];
      case 'nutrition':
        return [l10n.adviceNutrition];
      case 'wellness':
        return [l10n.adviceWellness];
      case 'psychotest':
        return [l10n.advicePsychotest];
      case 'screen_time':
        return [l10n.adviceScreenTime];
      case 'heart_rate':
        return [
          l10n.adviceHeartRate1,
          if (score < 60) l10n.adviceHeartRate2,
        ];
      case 'stress':
        return [l10n.adviceStress];
      default:
        return [];
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
  static Future<HealthAnalysis> run(String userId, AppLocalizations l10n) async {
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
      findings.add(_bp(sys, dia, l10n, age: age, gender: gender));
    }
    final glucose = latest['glucose'];
    if (glucose != null) findings.add(_glucose(glucose, unitSystem, l10n));

    final weight =
        latest['weight'] ?? (profileRows.isNotEmpty
            ? (profileRows.first['weight'] as num?)?.toDouble()
            : null);
    if (weight != null) findings.add(_weight(weight, heightCm, l10n));

    final steps = latest['steps'];
    if (steps != null) findings.add(_steps(steps, l10n));
    final calories = latest['calories'];
    if (calories != null && steps != null) {
      findings.add(_calories(calories, steps, l10n));
    }
    if (wellnessRows.isNotEmpty) {
      findings.add(_wellness((wellnessRows.first['score'] as num).toInt(), l10n));
    }
    if (habitRows.isNotEmpty) {
      final smoking = _smoking(habitRows.first, l10n);
      if (smoking != null) findings.add(smoking);
      final alcohol = _alcohol(habitRows.first, l10n);
      if (alcohol != null) findings.add(alcohol);
      final screens = _screenTime(habitRows.first, l10n);
      if (screens != null) findings.add(screens);
    }
    final nutrition = _nutrition(meals, l10n);
    if (nutrition != null) findings.add(nutrition);
    if (psychoRows.isNotEmpty) {
      final psycho = _psychotest(psychoRows.first, l10n);
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
    final correlationFindings = correlation.toFindings(l10n);
    bool hasWeightFinding(String category) {
      final c = category.toLowerCase();
      return c.contains('weight') ||
          c.contains('bmi') ||
          c.contains('вес') ||
          c.contains('peso') ||
          c.contains('体重') ||
          c.contains('وزن');
    }

    String metricKey(String category) {
      final c = category.toLowerCase();
      if (c.contains('glucose') ||
          c.contains('глюкоз') ||
          c.contains('sugar') ||
          c.contains('azúcar') ||
          c.contains('血糖') ||
          c.contains('جلوكوز')) {
        return 'glucose';
      }
      if (c.contains('blood pressure') ||
          c.contains('давлен') ||
          c.contains('presión') ||
          c.contains('血压') ||
          c.contains('ضغط')) {
        return 'bp';
      }
      if (hasWeightFinding(c)) return 'weight';
      return c;
    }

    bool isClinicalExtra(String category) {
      return category == l10n.clinicalCategoryWhatMeans ||
          category == l10n.clinicalCategoryHealthyWeight ||
          category == l10n.clinicalCategoryMetabolic ||
          category == l10n.clinicalCategoryCombinedRisk ||
          category == l10n.clinicalCategoryForAge ||
          () {
            final c = category.toLowerCase();
            return c.contains('what this means') ||
                c.contains('что это значит') ||
                c.contains('healthy weight') ||
                c.contains('здоровый') ||
                c.contains('metabolic') ||
                c.contains('метаболическ') ||
                c.contains('overall heart') ||
                c.contains('сердечно') ||
                c.contains('for your age') ||
                c.contains('для вашего возраста') ||
                c.contains('ideal weight') ||
                c.contains('cardiometabolic') ||
                c.contains('clinical pattern') ||
                c.contains('age-specific') ||
                c.contains('aha/acc');
          }();
    }

    final existingKeys = findings.map((f) => metricKey(f.category)).toSet();
    final bpIsGood = findings.any(
      (f) =>
          metricKey(f.category) == 'bp' &&
          (f.status == 'good' || f.status == 'info'),
    );
    for (final raw in correlationFindings) {
      final f = Finding(
        category: l10n.findingCategory(raw.category),
        status: raw.status,
        value: raw.value,
        message: raw.message,
      );
      final key = metricKey(raw.category);
      if (key == 'glucose' || key == 'bp' || key == 'weight') {
        if (existingKeys.contains(key)) continue;
        existingKeys.add(key);
      }
      // Never show young-HTN flags when the main BP finding is already healthy.
      if (bpIsGood &&
          raw.category == l10n.clinicalCategoryWhatMeans &&
          (f.value == l10n.clinicalFlagYoungHtnTitle ||
              (f.value?.toLowerCase().contains('high bp') == true))) {
        continue;
      }
      final duplicatesExistingWeight =
          hasWeightFinding(raw.category) && existingKeys.contains('weight');
      if (isClinicalExtra(raw.category)) {
        findings.add(f);
      } else if (!existingKeys.contains(key) && !duplicatesExistingWeight) {
        findings.add(f);
        existingKeys.add(key);
      }
    }

    if (findings.isEmpty && index.componentScores.isEmpty) {
      throw Exception(l10n.analysisNoData);
    }

    // Sort: critical → warning → info → good
    const order = {'critical': 0, 'warning': 1, 'info': 2, 'good': 3};
    findings.sort(
      (a, b) => (order[a.status] ?? 9).compareTo(order[b.status] ?? 9),
    );

    final score = index.score;
    final status = _uiStatus(index.status);
    final summary = _summary(
      l10n: l10n,
      uiStatus: status,
      score: score,
      findings: findings,
      index: index,
    );
    final recommendations = _recommendations(l10n: l10n, index: index, findings: findings);
    final correlationRecs = correlation.toRecommendations(l10n);
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

  static Future<void> sync(
    String userId, {
    required int steps,
    required double distanceMeters,
    DateTime? day,
  }) async {
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
    final targetDay = day ?? DateTime.now();

    // One live row per metric for the target local day.
    for (final m in [
      {'metric_type': 'steps', 'value': steps.toDouble()},
      {'metric_type': 'distance', 'value': distanceKm},
      {'metric_type': 'calories', 'value': calories},
    ]) {
      await DailyMetricStore.upsertOnLocalDay(
        userId: userId,
        metricType: m['metric_type'] as String,
        value: m['value'] as double,
        day: targetDay,
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
      'raw_payload': jsonEncode({
        'steps': steps,
        'distance_meters': distanceMeters,
        'day': DailyMetricStore.localDateKey(targetDay),
      }),
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

  /// Pulls a specific local calendar [day] from HealthKit / Health Connect and
  /// freezes it into SQLite (used before the morning “yesterday” push).
  static Future<bool> syncDayFromDevice(String userId, DateTime day) async {
    if (!HealthTelemetryService.isSupported) return false;
    if (Platform.isAndroid && !await HealthTelemetryService.hasPermission()) {
      return false;
    }
    final local = day.toLocal();
    final target = DateTime(local.year, local.month, local.day);
    final snapshot = await HealthTelemetryService.fetchForDay(target);
    if (snapshot == null) return false;

    final bounds = DailyMetricStore.localDayBounds(target);
    final existing = await Db.instance.raw.query(
      'health_metrics',
      columns: ['value'],
      where:
          'user_id = ? AND metric_type = ? AND recorded_at >= ? AND recorded_at < ?',
      whereArgs: [userId, 'steps', bounds.startIso, bounds.endIso],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final prev = (existing.first['value'] as num).toInt();
      if (prev == snapshot.steps) return false;
    }

    await sync(
      userId,
      steps: snapshot.steps,
      distanceMeters: snapshot.distanceMeters,
      day: target,
    );
    return true;
  }
}
