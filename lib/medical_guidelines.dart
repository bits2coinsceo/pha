/// Single source of medical ranges, bands, and classifiers for PHA.
///
/// Medical Note: Adult office BP uses ESC/ESH (see [BloodPressure]). Glucose
/// uses ADA fasting cut-offs in mg/dL storage. BMI uses WHO. Activity bands
/// follow WHO-aligned step proxies (~7,000 beneficial; 10,000 aspirational).
/// Wellness / PsychoTest / habits share identical labels in Index, Insights,
/// and questionnaire UIs so screens never contradict each other.
library;

import 'dart:math';

import 'blood_pressure.dart';
import 'l10n/generated/app_localizations.dart';
import 'units.dart';

export 'blood_pressure.dart';
export 'clinical_correlations.dart';

/// Shared finding tone used by Insights and mirrored in questionnaire UIs.
typedef MedStatus = String; // good | info | warning | critical

class MedResult {
  final String band;
  final MedStatus status;
  final double score;
  final String label;
  final String message;

  const MedResult({
    required this.band,
    required this.status,
    required this.score,
    required this.label,
    required this.message,
  });
}

/// Input clamps and Index constants.
abstract final class MedicalGuidelines {
  // Medical Note: physiological plausibility for self-entered adult vitals —
  // not diagnostic cut-offs. Prevents absurd values from polluting Index/AI.
  static const bpSysMin = 60.0;
  static const bpSysMax = 250.0;
  static const bpDiaMin = 40.0;
  static const bpDiaMax = 150.0;

  static const glucoseMgdlMin = 20.0;
  static const glucoseMgdlMax = 600.0;

  static const ageMin = 1;
  static const ageMax = 120;
  static const heightCmMin = 50.0;
  static const heightCmMax = 250.0;
  static const weightKgMin = 20.0;
  static const weightKgMax = 300.0;

  /// Medical Note: ADA fasting plasma glucose (mg/dL).
  static const glucoseHypoMax = 70.0;
  static const glucoseNormalMax = 99.0;
  static const glucosePrediabetesMax = 125.0;

  /// Medical Note: WHO BMI categories (kg/m²).
  static const bmiUnder = 18.5;
  static const bmiNormal = 25.0;
  static const bmiOver = 30.0;
  static const bmiObeseI = 35.0;

  /// Activity step thresholds (adult proxy).
  static const stepsSedentary = 3000;
  static const stepsBaseline = 5000;
  static const stepsStrong = 7000;
  static const stepsGoal = 10000;

  /// Meal photo kcal / serving bands (Ai Doc categories).
  static const mealExcellentMaxKcal = 400;
  static const mealSatisfactoryMaxKcal = 650;

  /// Daily meal-intake chart zones (confirmed photo meals).
  /// ≤ deficitMax → green (deficit); ≤ moderateMax → yellow; above → red.
  static const mealIntakeDeficitMaxKcal = 1700;
  static const mealIntakeModerateMaxKcal = 2000;

  /// Resting heart-rate wellness bands (bpm). Tunable; not a diagnosis.
  static const restingHrMin = 60;
  static const restingHrMax = 95;
  static const restingHrMaxYoung = 95;
  static const restingHrMaxSenior = 95;
  static const restingHrAthleteMin = 40;
  /// Soft elevated cut-off: flag if resting HR stays in/above 80–95.
  static const restingHrElevatedCutOff = 80;
  /// Upper of the elevated band — at/above this is a risk signal.
  static const restingHrElevatedHigh = 95;
  /// Day-to-day rise that counts as a sharp change.
  static const restingHrSharpChangeBpm = 10;

  /// Soft daily energy target (Mifflin–St Jeor × light activity 1.4).
  /// Used for deficit / surplus feedback — not a medical prescription.
  static int estimatedDailyCalorieTarget({
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
  }) {
    if (age == null ||
        weightKg == null ||
        heightCm == null ||
        weightKg <= 0 ||
        heightCm <= 0) {
      return 2000;
    }
    final g = (gender ?? '').toLowerCase();
    final isMale = g.startsWith('m') || g == 'male';
    final bmr = isMale
        ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
        : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    return (bmr * 1.4).round().clamp(1200, 4000);
  }

  /// Foundation Health Index weights — vitals, body metrics, and habits.
  /// These form the base score before lifestyle modifiers.
  static const foundationWeights = <String, double>{
    'blood_pressure': 22,
    'glucose': 18,
    'bmi': 16,
    'smoking': 16,
    'alcohol': 12,
    'age': 10,
    'screen_time': 6,
  };

  /// Lifestyle modifiers applied on top of the foundation score.
  /// [heart_rate] is only included when there is meaningful daily activity.
  static const lifestyleWeights = <String, double>{
    'activity': 70,
    'heart_rate': 15,
    'nutrition': 8,
    'wellness': 4,
    'psychotest': 3,
  };

  /// How strongly lifestyle pulls the foundation score (0–1).
  static const lifestyleBlend = 0.28;

  /// Stress (elevated HR without activity) pull on the final score.
  static const stressBlend = 0.12;

  /// @Deprecated Prefer [foundationWeights] + [lifestyleWeights].
  /// Kept for Insights gap labeling of known keys.
  static const indexWeights = <String, double>{
    ...foundationWeights,
    ...lifestyleWeights,
    'stress': 8,
  };

  static String indexStatus(int score) {
    if (score >= 85) return 'excellent';
    if (score >= 70) return 'good';
    if (score >= 50) return 'fair';
    return 'poor';
  }

  static String indexSummary(int score, String status) {
    switch (status) {
      case 'excellent':
        return 'Excellent — keep your healthy habits going.';
      case 'good':
        return "You're doing well.";
      case 'fair':
        return 'Some areas need attention — small daily changes help.';
      default:
        return 'Your health index needs focus — review vitals and habits.';
    }
  }

  /// Same copy for Home Health Index card.
  static String indexCardBlurb(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return 'Excellent — keep it up.';
      case 'good':
        return "You're doing well.";
      case 'fair':
        return 'Some areas need attention.';
      case 'poor':
      case 'needs_attention':
        return 'Needs focus — review your habits.';
      default:
        return "You're doing well.";
    }
  }

  static double ageBaselineScore(int age) {
    if (age < 30) return 78;
    if (age < 45) return 74;
    if (age < 60) return 70;
    return 66;
  }
}

/// Plausibility validation for forms (onboarding, daily vitals, log metric).
abstract final class VitalValidation {
  static String? bloodPressure(double? sys, double? dia, AppLocalizations l10n) {
    if (sys == null || dia == null) return l10n.validationBpCheck;
    if (sys < MedicalGuidelines.bpSysMin ||
        sys > MedicalGuidelines.bpSysMax ||
        dia < MedicalGuidelines.bpDiaMin ||
        dia > MedicalGuidelines.bpDiaMax) {
      return l10n.validationBpRange(
        MedicalGuidelines.bpSysMin.toInt(),
        MedicalGuidelines.bpSysMax.toInt(),
        MedicalGuidelines.bpDiaMin.toInt(),
        MedicalGuidelines.bpDiaMax.toInt(),
      );
    }
    if (dia >= sys) return l10n.validationBpDiaLower;
    return null;
  }

  /// [userValue] is in the unit of [sys] (mmol/L metric, mg/dL imperial).
  /// Returns error message or null; [mgdlOut] is filled on success.
  static String? glucoseUserInput(
    double? userValue,
    UnitSystem unitSys,
    AppLocalizations l10n, {
    required void Function(double mgdl) onValid,
  }) {
    if (userValue == null) return l10n.validationGlucoseEnter;
    if (unitSys == 'imperial') {
      if (userValue < MedicalGuidelines.glucoseMgdlMin ||
          userValue > MedicalGuidelines.glucoseMgdlMax) {
        return l10n.validationGlucoseRangeMgdl(
          MedicalGuidelines.glucoseMgdlMin.toInt(),
          MedicalGuidelines.glucoseMgdlMax.toInt(),
        );
      }
      onValid(userValue);
      return null;
    }
    final minMmol = mgdlToMmol(MedicalGuidelines.glucoseMgdlMin);
    final maxMmol = mgdlToMmol(MedicalGuidelines.glucoseMgdlMax);
    if (userValue < minMmol || userValue > maxMmol) {
      return l10n.validationGlucoseRangeMmol(
        minMmol.toStringAsFixed(1),
        maxMmol.toStringAsFixed(1),
      );
    }
    onValid((mmolToMgdl(userValue) * 10).round() / 10);
    return null;
  }

  static String? weightKg(double? kg, AppLocalizations l10n) {
    if (kg == null) return l10n.validationWeightEnter;
    if (kg < MedicalGuidelines.weightKgMin ||
        kg > MedicalGuidelines.weightKgMax) {
      return l10n.validationWeightRange(
        MedicalGuidelines.weightKgMin.toInt(),
        MedicalGuidelines.weightKgMax.toInt(),
      );
    }
    return null;
  }

  static String? heightCm(double? cm, AppLocalizations l10n) {
    if (cm == null) return l10n.validationHeightEnter;
    if (cm < MedicalGuidelines.heightCmMin ||
        cm > MedicalGuidelines.heightCmMax) {
      return l10n.validationHeightRange(
        MedicalGuidelines.heightCmMin.toInt(),
        MedicalGuidelines.heightCmMax.toInt(),
      );
    }
    return null;
  }

  static String? age(int? age, AppLocalizations l10n) {
    if (age == null) return l10n.validationAgeEnter;
    if (age < MedicalGuidelines.ageMin || age > MedicalGuidelines.ageMax) {
      return l10n.validationAgeRange(
        MedicalGuidelines.ageMin,
        MedicalGuidelines.ageMax,
      );
    }
    return null;
  }

  /// Validates a free-form log metric after converting to storage units.
  static String? metricStorage(
    String metricType,
    double storageValue,
    AppLocalizations l10n,
  ) {
    switch (metricType) {
      case 'glucose':
        if (storageValue < MedicalGuidelines.glucoseMgdlMin ||
            storageValue > MedicalGuidelines.glucoseMgdlMax) {
          return l10n.validationGlucoseOutOfRange;
        }
      case 'weight':
        if (storageValue < MedicalGuidelines.weightKgMin ||
            storageValue > MedicalGuidelines.weightKgMax) {
          return l10n.validationWeightOutOfRange;
        }
      case 'steps':
        if (storageValue < 0 || storageValue > 100000) {
          return l10n.validationStepsUnrealistic;
        }
      case 'calories':
        if (storageValue < 0 || storageValue > 20000) {
          return l10n.validationCaloriesUnrealistic;
        }
      case 'water':
        if (storageValue < 0 || storageValue > 15000) {
          return l10n.validationWaterUnrealistic;
        }
      case 'active_time':
        if (storageValue < 0 || storageValue > 1440) {
          return l10n.validationActiveTimeRange;
        }
      case 'distance':
        if (storageValue < 0 || storageValue > 500) {
          return l10n.validationDistanceUnrealistic;
        }
    }
    return null;
  }
}

/// Medical Note: ADA fasting glucose bands; app stores mg/dL.
abstract final class GlucoseGuidelines {
  static MedResult classify(double mgdl, UnitSystem unitSys) {
    final formatted = formatGlucose(mgdl, unitSys);
    final v = '${formatted.value} ${formatted.unit}';
    if (mgdl < MedicalGuidelines.glucoseHypoMax) {
      return MedResult(
        band: 'hypoglycemia',
        status: 'critical',
        score: 40,
        label: v,
        message:
            'Blood glucose is low (hypoglycemia). Eat something with fast-acting '
            'carbohydrates and consult your doctor.',
      );
    }
    if (mgdl <= MedicalGuidelines.glucoseNormalMax) {
      return MedResult(
        band: 'normal',
        status: 'good',
        score: 96,
        label: v,
        message:
            'Fasting blood glucose is in the normal range. Good metabolic health.',
      );
    }
    if (mgdl <= MedicalGuidelines.glucosePrediabetesMax) {
      return MedResult(
        band: 'prediabetes',
        status: 'warning',
        score: 58,
        label: v,
        message:
            'Blood glucose is in the prediabetes range. Cut sugary drinks, '
            'add fiber at each meal, and walk 10–15 minutes after eating.',
      );
    }
    return MedResult(
      band: 'diabetes',
      status: 'critical',
      score: 28,
      label: v,
      message:
          'Blood glucose is in the diabetes range. Please consult a healthcare '
          'provider for evaluation and a care plan.',
    );
  }

  static double score(double mgdl) => classify(mgdl, 'metric').score;
}

/// Medical Note: WHO adult BMI.
abstract final class BmiGuidelines {
  static MedResult classify(double weightKg, double? heightCm) {
    if (heightCm == null || heightCm <= 0) {
      return MedResult(
        band: 'weight_only',
        status: 'info',
        score: 70,
        label: '${weightKg.toStringAsFixed(1)} kg',
        message:
            'Weight is recorded. Add your height in Profile so we can score BMI '
            'in your Health Index.',
      );
    }
    final bmi = weightKg / pow(heightCm / 100, 2);
    final s = bmi.toStringAsFixed(1);
    if (bmi < MedicalGuidelines.bmiUnder) {
      return MedResult(
        band: 'underweight',
        status: 'warning',
        score: 62,
        label: 'BMI $s',
        message:
            'Your weight is a bit low for your height. Eat protein-rich meals '
            'more often; ask a doctor if you did not mean to lose weight.',
      );
    }
    if (bmi < MedicalGuidelines.bmiNormal) {
      return MedResult(
        band: 'healthy',
        status: 'good',
        score: 95,
        label: 'BMI $s',
        message: 'Your weight looks healthy for your height. Well done!',
      );
    }
    if (bmi < MedicalGuidelines.bmiOver) {
      return MedResult(
        band: 'overweight',
        status: 'warning',
        score: 70,
        label: 'BMI $s',
        message:
            'Your weight is a bit above the healthy range. Aim for a gentle '
            'weekly loss, keep protein up, and protect your daily steps.',
      );
    }
    if (bmi < MedicalGuidelines.bmiObeseI) {
      return MedResult(
        band: 'obesity_class_i',
        status: 'critical',
        score: 48,
        label: 'BMI $s',
        message:
            'Your weight is clearly above the healthy range. This can raise '
            'blood pressure and blood sugar. Better food, more walking, and a '
            'doctor-guided plan help a lot.',
      );
    }
    return MedResult(
      band: 'obesity_class_ii_plus',
      status: 'critical',
      score: 32,
      label: 'BMI $s',
      message:
          'Your weight is well above the healthy range. Please see a doctor '
          'for a safe plan to protect your heart and metabolism.',
    );
  }

  static double scoreFromBmi(double bmi) {
    if (bmi < MedicalGuidelines.bmiUnder) return 62;
    if (bmi < MedicalGuidelines.bmiNormal) return 95;
    if (bmi < MedicalGuidelines.bmiOver) return 70;
    if (bmi < MedicalGuidelines.bmiObeseI) return 48;
    return 32;
  }
}

/// Unified step bands for Home feedback, Insights findings, and Index score.
///
/// Scores are intentionally generous once the user clears sedentary levels —
/// a meaningful daily step count is treated as a real Health Index contribution.
abstract final class StepsGuidelines {
  static MedResult classify(double steps) {
    final n = steps.round();
    final v = '$n steps';
    if (n < MedicalGuidelines.stepsSedentary) {
      return MedResult(
        band: 'sedentary',
        status: 'warning',
        score: n < 1000 ? 30 : 50,
        label: v,
        message:
            'Low activity today. Start with a 15-minute walk — consistency beats '
            'intensity for long-term heart health.',
      );
    }
    if (n < MedicalGuidelines.stepsBaseline) {
      return MedResult(
        band: 'building',
        status: 'info',
        score: 68,
        label: v,
        message:
            'You are building a walking habit. Aim toward '
            '${MedicalGuidelines.stepsStrong}+ steps for stronger cardiometabolic benefit.',
      );
    }
    if (n < MedicalGuidelines.stepsStrong) {
      return MedResult(
        band: 'baseline',
        status: 'good',
        score: 82,
        label: v,
        message:
            'Solid baseline activity. A few more short walks can reach the '
            '${MedicalGuidelines.stepsStrong}+ range many guidelines treat as beneficial.',
      );
    }
    if (n < MedicalGuidelines.stepsGoal) {
      return MedResult(
        band: 'strong',
        status: 'good',
        score: 94,
        label: v,
        message:
            'Strong activity level — well above sedentary. Keep this rhythm; '
            '${MedicalGuidelines.stepsGoal} steps is a bonus goal, not a must.',
      );
    }
    return MedResult(
      band: 'goal',
      status: 'good',
      score: 100,
      label: v,
      message:
          'Excellent activity level — you are meeting the classic '
          '${MedicalGuidelines.stepsGoal}-step day.',
    );
  }

  static double score(double steps) => classify(steps).score;

  /// Home card range label + short message (same bands as [classify]).
  static ({String range, String message}) feedback(int steps) {
    final r = classify(steps.toDouble());
    final range = switch (r.band) {
      'sedentary' => '0–${_fmt(MedicalGuidelines.stepsSedentary - 1)} steps',
      'building' =>
        '${_fmt(MedicalGuidelines.stepsSedentary)}–${_fmt(MedicalGuidelines.stepsBaseline - 1)} steps',
      'baseline' =>
        '${_fmt(MedicalGuidelines.stepsBaseline)}–${_fmt(MedicalGuidelines.stepsStrong - 1)} steps',
      'strong' =>
        '${_fmt(MedicalGuidelines.stepsStrong)}–${_fmt(MedicalGuidelines.stepsGoal - 1)} steps',
      _ => '${_fmt(MedicalGuidelines.stepsGoal)}+ steps',
    };
    return (range: range, message: r.message);
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Medical Note: Wellness Check 0–100 (higher = better). Same labels in modal + Insights.
abstract final class WellnessGuidelines {
  static MedResult classify(int score) {
    final v = '$score/100';
    if (score >= 80) {
      return MedResult(
        band: 'excellent',
        status: 'good',
        score: score.toDouble(),
        label: v,
        message:
            'Excellent wellness score — low stress load and solid mental resilience.',
      );
    }
    if (score >= 65) {
      return MedResult(
        band: 'good',
        status: 'good',
        score: score.toDouble(),
        label: v,
        message:
            'Good wellness. Small upgrades in sleep or recovery can push you to excellent.',
      );
    }
    if (score >= 50) {
      return MedResult(
        band: 'moderate',
        status: 'info',
        score: score.toDouble(),
        label: v,
        message:
            'Moderate wellness. Try a short wind-down: 5 minutes of breathing, '
            'a walk outside, or earlier lights-out.',
      );
    }
    if (score >= 35) {
      return MedResult(
        band: 'needs_attention',
        status: 'warning',
        score: score.toDouble(),
        label: v,
        message:
            'Wellness score suggests elevated stress. Protect sleep, reduce '
            'late caffeine, and reconnect socially this week.',
      );
    }
    return MedResult(
      band: 'critical',
      status: 'critical',
      score: score.toDouble(),
      label: v,
      message:
          'High stress load. Consider repeating the Wellness Check and talking '
          'with a mental health professional if this persists.',
    );
  }

  /// Stored `result` string for stress_tests table / modal title.
  static String resultLabel(int score) {
    switch (classify(score).band) {
      case 'excellent':
        return 'Excellent';
      case 'good':
        return 'Good';
      case 'moderate':
        return 'Moderate';
      case 'needs_attention':
        return 'Needs attention';
      default:
        return 'Needs attention';
    }
  }

  static String resultDescription(int score) {
    switch (classify(score).band) {
      case 'excellent':
        return 'Great job! Your wellness indicators are strong. Keep up the healthy habits.';
      case 'good':
        return 'You are doing well. Small improvements in sleep or stress could push you to excellent.';
      case 'moderate':
        return 'You are in a moderate range. Prioritize rest and light recovery this week.';
      default:
        return 'Consider taking steps to improve your rest, manage stress, or speak to a professional.';
    }
  }
}

/// Medical Note: PsychoTest total load 0–100 (higher = more psychosomatic load).
abstract final class PsychoGuidelines {
  static MedResult classifyLoad(int load) {
    final contribution = (100 - load).clamp(0, 100).toDouble();
    if (load < 34) {
      return MedResult(
        band: 'low',
        status: 'good',
        score: contribution,
        label: 'Low',
        message:
            'Psychosomatic indicators are within a healthy range. Keep maintaining your wellness habits.',
      );
    }
    if (load < 67) {
      return MedResult(
        band: 'moderate',
        status: 'info',
        score: contribution,
        label: 'Moderate',
        message:
            'Moderate psychosomatic load. Pay attention to rest, relaxation routines, '
            'and healthy boundaries.',
      );
    }
    return MedResult(
      band: 'high',
      status: 'warning',
      score: contribution,
      label: 'High',
      message:
          'Significant stress and psychosomatic tension. Consider speaking with a '
          'specialist and reducing your load.',
    );
  }

  static double indexContribution(int load) =>
      (100 - load).clamp(0, 100).toDouble();
}

/// Habit scorers shared by Index + Insights findings.
abstract final class HabitGuidelines {
  static double smokingScore(bool smokes, String? level) {
    if (!smokes) return 100;
    switch (level) {
      case 'less_than_one_pack':
        return 45;
      case 'one_pack':
        return 28;
      case 'more_than_one_pack':
        return 12;
      default:
        return 30;
    }
  }

  static double alcoholScore(bool drinks, String? level) {
    if (!drinks) return 100;
    switch (level) {
      case 'occasionally':
        return 78;
      case 'regularly':
        return 45;
      case 'heavy':
        return 15;
      default:
        return 50;
    }
  }

  static double screenScore(String? level) {
    switch (level) {
      case 'rarely':
        return 95;
      case 'under_hour':
        return 82;
      case 'one_to_two_hours':
        return 65;
      case 'constantly':
        return 40;
      default:
        return 70;
    }
  }

  static double nutritionFromMeals(List<Map<String, dynamic>> meals) {
    if (meals.isEmpty) return 60;
    var sum = 0.0;
    for (final m in meals) {
      switch (m['category'] as String?) {
        case 'excellent':
          sum += 95;
        case 'satisfactory':
          sum += 72;
        case 'attention':
          sum += 40;
        default:
          sum += 60;
      }
    }
    return sum / meals.length;
  }
}
