import 'generated/app_localizations.dart';
import '../medical_guidelines.dart';

/// Localized medical/status strings for UI and health analysis.
extension MedicalL10n on AppLocalizations {
  String bpMessage(BpBand band) => switch (band) {
        BpBand.low => bpMsgLow,
        BpBand.optimal => bpMsgOptimal,
        BpBand.normal => bpMsgNormal,
        BpBand.highNormal => bpMsgHighNormal,
        BpBand.grade1 => bpMsgGrade1,
        BpBand.grade2 => bpMsgGrade2,
        BpBand.grade3 => bpMsgGrade3,
      };

  String indexCardBlurb(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return indexCardExcellent;
      case 'good':
        return indexCardGood;
      case 'fair':
        return indexCardFair;
      case 'poor':
      case 'needs_attention':
        return indexCardNeedsAttention;
      default:
        return indexCardGood;
    }
  }

  String indexSummary(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return indexSummaryExcellent;
      case 'good':
        return indexSummaryGood;
      case 'fair':
        return indexSummaryFair;
      case 'poor':
      case 'needs_attention':
        return indexSummaryPoor;
      default:
        return indexSummaryGood;
    }
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return statusExcellent;
      case 'good':
        return statusGood;
      case 'fair':
        return statusFair;
      case 'poor':
      case 'needs_attention':
        return statusNeedsAttention;
      default:
        if (status.isEmpty) return status;
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  String fmtSteps(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  ({String range, String message}) stepsFeedback(int steps) {
    final c = StepsGuidelines.classify(steps.toDouble());
    final range = switch (c.band) {
      'sedentary' => stepsRangeSedentary(
          fmtSteps(MedicalGuidelines.stepsSedentary - 1),
        ),
      'building' => stepsRangeBuilding(
          fmtSteps(MedicalGuidelines.stepsSedentary),
          fmtSteps(MedicalGuidelines.stepsBaseline - 1),
        ),
      'baseline' => stepsRangeBaseline(
          fmtSteps(MedicalGuidelines.stepsBaseline),
          fmtSteps(MedicalGuidelines.stepsStrong - 1),
        ),
      'strong' => stepsRangeStrong(
          fmtSteps(MedicalGuidelines.stepsStrong),
          fmtSteps(MedicalGuidelines.stepsGoal - 1),
        ),
      _ => stepsRangeGoal(fmtSteps(MedicalGuidelines.stepsGoal)),
    };
    final message = switch (c.band) {
      'sedentary' => stepsMsgSedentary,
      'building' => stepsMsgBuilding(MedicalGuidelines.stepsStrong),
      'baseline' => stepsMsgBaseline(MedicalGuidelines.stepsStrong),
      'strong' => stepsMsgStrong(MedicalGuidelines.stepsGoal),
      _ => stepsMsgGoal(MedicalGuidelines.stepsGoal),
    };
    return (range: range, message: message);
  }

  String glucoseMessage(String band) => switch (band) {
        'hypoglycemia' => glucoseMsgHypoglycemia,
        'normal' => glucoseMsgNormal,
        'prediabetes' => glucoseMsgPrediabetes,
        'diabetes' => glucoseMsgDiabetes,
        _ => glucoseMsgNormal,
      };

  String bmiMessage(String band) => switch (band) {
        'weight_only' => bmiMsgWeightOnly,
        'underweight' => bmiMsgUnderweight,
        'healthy' => bmiMsgHealthy,
        'overweight' => bmiMsgOverweight,
        'obesity_class_i' => bmiMsgObeseI,
        'obesity_class_ii_plus' => bmiMsgObeseII,
        _ => bmiMsgWeightOnly,
      };

  String wellnessMessage(String band) => switch (band) {
        'excellent' => wellnessMsgExcellent,
        'good' => wellnessMsgGood,
        'moderate' => wellnessMsgModerate,
        'needs_attention' => wellnessMsgNeedsAttention,
        'critical' => wellnessMsgCritical,
        _ => wellnessMsgModerate,
      };

  String componentLabel(String key) => switch (key) {
        'blood_pressure' => categoryBloodPressure,
        'smoking' => categorySmoking,
        'glucose' => categoryBloodGlucose,
        'bmi' => categoryWeightBmi,
        'activity' => categoryActivity,
        'heart_rate' => categoryHeartRate,
        'alcohol' => categoryAlcohol,
        'nutrition' => categoryNutrition,
        'wellness' => categoryMentalWellness,
        'psychotest' => categoryPsychoTest,
        'screen_time' => categoryScreenTime,
        'age' => categoryAge,
        'stress' => categoryStress,
        _ => key,
      };

  String findingCategory(String englishCategory) {
    final c = englishCategory.toLowerCase();
    if (c.contains('blood pressure')) return categoryBloodPressure;
    if (c.contains('blood glucose') || c == 'glucose') return categoryBloodGlucose;
    if (c.contains('weight / bmi') || c.contains('weight/bmi')) return categoryWeightBmi;
    if (c == 'weight') return categoryWeight;
    if (c.contains('daily activity') || c == 'activity') return categoryDailyActivity;
    if (c.contains('calorie')) return categoryCalorieBurn;
    if (c.contains('mental wellness') || c.contains('wellness')) return categoryMentalWellness;
    if (c.contains('smoking')) return categorySmoking;
    if (c.contains('alcohol')) return categoryAlcohol;
    if (c.contains('screen')) return categoryScreenTime;
    if (c.contains('nutrition')) return categoryNutrition;
    if (c.contains('psychotest')) return categoryPsychoTest;
    if (c.contains('heart') || c.contains('rhythm') || c == 'hrv') {
      return categoryHeartRate;
    }
    if (c.contains('age')) return categoryAge;
    if (c.contains('stress')) return categoryStress;
    return englishCategory;
  }

  /// Localize Apple HealthKit ECG classification strings using the rhythm KB.
  String hrEcgClassification(String raw) {
    final kind = EcgRhythmKnowledge.fromAppleClassification(raw);
    return switch (kind) {
      EcgRhythmKind.normalSinus => hrEcgSinusRhythm,
      EcgRhythmKind.atrialFibrillation => hrEcgAtrialFibrillation,
      EcgRhythmKind.sinusTachycardia => hrEcgSinusTachycardia,
      EcgRhythmKind.sinusBradycardia => hrEcgSinusBradycardia,
      EcgRhythmKind.ventricularTachycardia => hrEcgVentricularTachycardia,
      EcgRhythmKind.ventricularFibrillation => hrEcgVentricularFibrillation,
      EcgRhythmKind.avBlockFirstDegree => hrEcgAvBlock1,
      EcgRhythmKind.avBlockSecondMobitzI => hrEcgAvBlock2MobitzI,
      EcgRhythmKind.avBlockThirdDegree => hrEcgAvBlock3,
      EcgRhythmKind.inconclusive =>
        raw.toLowerCase().contains('low') || raw.toLowerCase().contains('high')
            ? hrEcgLowOrHighHr
            : hrEcgInconclusive,
      EcgRhythmKind.unknown =>
        (raw.trim().isEmpty ? hrEcgNotSet : raw),
    };
  }

  /// Short key-feature blurb for a rhythm kind (educational).
  String hrEcgRhythmFeatures(EcgRhythmKind kind) => switch (kind) {
        EcgRhythmKind.normalSinus => hrEcgFeatNormalSinus,
        EcgRhythmKind.sinusTachycardia => hrEcgFeatSinusTachy,
        EcgRhythmKind.sinusBradycardia => hrEcgFeatSinusBrady,
        EcgRhythmKind.atrialFibrillation => hrEcgFeatAfib,
        EcgRhythmKind.ventricularTachycardia => hrEcgFeatVt,
        EcgRhythmKind.ventricularFibrillation => hrEcgFeatVf,
        EcgRhythmKind.avBlockFirstDegree => hrEcgFeatAv1,
        EcgRhythmKind.avBlockSecondMobitzI => hrEcgFeatAv2,
        EcgRhythmKind.avBlockThirdDegree => hrEcgFeatAv3,
        EcgRhythmKind.inconclusive => hrEcgFeatInconclusive,
        EcgRhythmKind.unknown => hrEcgFeatUnknown,
      };

  String hrEcgRhythmTitle(EcgRhythmKind kind) => switch (kind) {
        EcgRhythmKind.normalSinus => hrEcgSinusRhythm,
        EcgRhythmKind.sinusTachycardia => hrEcgSinusTachycardia,
        EcgRhythmKind.sinusBradycardia => hrEcgSinusBradycardia,
        EcgRhythmKind.atrialFibrillation => hrEcgAtrialFibrillation,
        EcgRhythmKind.ventricularTachycardia => hrEcgVentricularTachycardia,
        EcgRhythmKind.ventricularFibrillation => hrEcgVentricularFibrillation,
        EcgRhythmKind.avBlockFirstDegree => hrEcgAvBlock1,
        EcgRhythmKind.avBlockSecondMobitzI => hrEcgAvBlock2MobitzI,
        EcgRhythmKind.avBlockThirdDegree => hrEcgAvBlock3,
        EcgRhythmKind.inconclusive => hrEcgInconclusive,
        EcgRhythmKind.unknown => hrEcgNotSet,
      };

  String analysisSummary(String uiStatus, int score, List<({String category, String status})> findings, List<String> gapKeys) {
    final opener = switch (uiStatus) {
      'excellent' => analysisSummaryExcellent,
      'good' => analysisSummaryGood,
      'fair' => analysisSummaryFair,
      'needs_attention' => analysisSummaryNeedsAttention,
      _ => analysisSummaryDefault,
    };
    var s = '$opener ${analysisScoreMatches(score)}';
    final strengths = findings.where((f) => f.status == 'good').toList();
    if (strengths.isNotEmpty) {
      final names = strengths.take(3).map((f) => findingCategory(f.category)).join(', ');
      s += ' ${analysisStrengths(names)}';
    }
    if (gapKeys.isNotEmpty) {
      final focus = gapKeys.take(3).map(componentLabel).join(', ');
      s += ' ${analysisBiggestDrag(focus)}';
    }
    return s;
  }

  String priorityLabel(String priority) => switch (priority) {
        'high' => priorityHigh,
        'medium' => priorityMedium,
        'low' => priorityLow,
        _ => priority,
      };

  String localizedUnit(String unit, String unitSystem) {
    if (unitSystem == 'imperial') {
      return switch (unit) {
        'kg' => unitLbs,
        'cm' => unitCm,
        'mmol/L' => unitMgdl,
        'km' => unitMiles,
        _ => unit,
      };
    }
    return switch (unit) {
      'kg' => unitKg,
      'cm' => unitCm,
      'mmol/L' => unitMmol,
      'km' => unitKm,
      'lbs' => unitLbs,
      'mg/dL' => unitMgdl,
      'miles' => unitMiles,
      'kcal' => unitKcal,
      'min' => unitMin,
      'yrs' => unitYears,
      _ => unit,
    };
  }

  String localizeUnitLabel(String unit) => switch (unit) {
        'km' => unitKm,
        'miles' => unitMiles,
        'kcal' => unitKcal,
        'min' => unitMin,
        'kg' => unitKg,
        'lbs' => unitLbs,
        'cm' => unitCm,
        'mmol/L' => unitMmol,
        'mg/dL' => unitMgdl,
        'yrs' => unitYears,
        _ => unit,
      };
}
