/// Cross-parameter clinical correlations for adult vitals (18+).
///
/// Sources: WHO/CDC BMI; AHA/ACC & ESC/ESH BP; ADA fasting glucose & HbA1c
/// equivalents; harmonized ATP III / IDF metabolic syndrome criteria.
/// Educational — not a diagnosis.
library;

import 'dart:math';

import 'medical_guidelines.dart';
import 'models.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/medical_l10n.dart';

/// Adult vitals snapshot for correlation analysis.
class ClinicalInput {
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final double? waistCm;
  final String? gender;
  final String? ethnicity;
  final double? systolic;
  final double? diastolic;
  final double? fastingGlucoseMgdl;
  final double? triglyceridesMgdl;
  final double? hdlMgdl;

  const ClinicalInput({
    this.age,
    this.heightCm,
    this.weightKg,
    this.waistCm,
    this.gender,
    this.ethnicity,
    this.systolic,
    this.diastolic,
    this.fastingGlucoseMgdl,
    this.triglyceridesMgdl,
    this.hdlMgdl,
  });

  bool get isAdult => age != null && age! >= 18;

  bool get isMale {
    final g = (gender ?? '').toLowerCase();
    return g.startsWith('m') || g == 'male';
  }

  bool get isFemale {
    final g = (gender ?? '').toLowerCase();
    return g.startsWith('f') || g == 'female';
  }
}

class IdealWeightEstimates {
  final double devineKg;
  final double robinsonKg;
  final double hamwiKg;
  final double lorentzKg;
  final double midpointKg;

  const IdealWeightEstimates({
    required this.devineKg,
    required this.robinsonKg,
    required this.hamwiKg,
    required this.lorentzKg,
    required this.midpointKg,
  });

  static const limitationNote =
      'This is only a rough healthy-weight estimate. Your best range depends '
      'on muscle, body shape, and how you feel — not one formula.';
}

class BmiAnalysis {
  final double bmi;
  final String whoCategory;
  final double riskMultiplier;
  final double idealMidKg;
  final double pctDeviationFromIdeal;

  const BmiAnalysis({
    required this.bmi,
    required this.whoCategory,
    required this.riskMultiplier,
    required this.idealMidKg,
    required this.pctDeviationFromIdeal,
  });
}

class AhaBpClassification {
  final String band;
  final String status;
  final String treatmentNote;

  const AhaBpClassification({
    required this.band,
    required this.status,
    required this.treatmentNote,
  });
}

class GlucoseCorrelation {
  final String adaFastingBand;
  final String hba1cEquivalent;
  final String status;

  const GlucoseCorrelation({
    required this.adaFastingBand,
    required this.hba1cEquivalent,
    required this.status,
  });
}

class MetabolicSyndromeResult {
  final bool? likelyPresent;
  final int criteriaMet;
  final int criteriaChecked;
  final List<String> metCriteria;
  final String message;

  const MetabolicSyndromeResult({
    required this.likelyPresent,
    required this.criteriaMet,
    required this.criteriaChecked,
    required this.metCriteria,
    required this.message,
  });
}

class CombinedRiskResult {
  final double relativeRiskMultiplier;
  final String tier;
  final List<String> pathologyFlags;
  final String message;

  const CombinedRiskResult({
    required this.relativeRiskMultiplier,
    required this.tier,
    required this.pathologyFlags,
    required this.message,
  });
}

class ClinicalCorrelationReport {
  final BmiAnalysis? bmi;
  final IdealWeightEstimates? idealWeight;
  final AhaBpClassification? ahaBp;
  final String? escBpSummary;
  final GlucoseCorrelation? glucose;
  final MetabolicSyndromeResult? metabolicSyndrome;
  final CombinedRiskResult? combinedRisk;
  final List<String> ageInsights;

  const ClinicalCorrelationReport({
    this.bmi,
    this.idealWeight,
    this.ahaBp,
    this.escBpSummary,
    this.glucose,
    this.metabolicSyndrome,
    this.combinedRisk,
    this.ageInsights = const [],
  });

  List<Finding> toFindings(AppLocalizations l10n) =>
      ClinicalCorrelationEngine.findingsFrom(this, l10n);

  List<Recommendation> toRecommendations(AppLocalizations l10n) =>
      ClinicalCorrelationEngine.recommendationsFrom(this, l10n);
}

/// Deterministic cardiometabolic correlation engine.
abstract final class ClinicalCorrelationEngine {
  static ClinicalCorrelationReport analyze(ClinicalInput input) {
    if (input.age != null && input.age! < 18) {
      return ClinicalCorrelationReport(
        ageInsights: const ['pediatric'],
      );
    }

    BmiAnalysis? bmi;
    IdealWeightEstimates? ideal;
    if (input.weightKg != null &&
        input.heightCm != null &&
        input.heightCm! > 0) {
      ideal = _idealWeights(input.heightCm!, input.gender);
      bmi = _bmiAnalysis(
        weightKg: input.weightKg!,
        heightCm: input.heightCm!,
        idealMidKg: ideal.midpointKg,
      );
    }

    AhaBpClassification? aha;
    String? esc;
    if (input.systolic != null && input.diastolic != null) {
      aha = _ahaBp(
        input.systolic!,
        input.diastolic!,
        age: input.age,
      );
      final escClass = BloodPressure.classify(
        input.systolic!,
        input.diastolic!,
        age: input.age,
        gender: input.gender,
      );
      esc = '${escClass.label} (ESC/ESH: ${escClass.band.name})';
    }

    GlucoseCorrelation? glucose;
    if (input.fastingGlucoseMgdl != null) {
      glucose = _glucoseCorrelation(input.fastingGlucoseMgdl!);
    }

    final metabolic = _metabolicSyndrome(input, bmi?.bmi);

    final combined = _combinedRisk(
      input: input,
      bmi: bmi,
      aha: aha,
      glucose: glucose,
      metabolic: metabolic,
    );

    final ageInsights = _ageInsights(input, bmi, aha, glucose);

    return ClinicalCorrelationReport(
      bmi: bmi,
      idealWeight: ideal,
      ahaBp: aha,
      escBpSummary: esc,
      glucose: glucose,
      metabolicSyndrome: metabolic,
      combinedRisk: combined,
      ageInsights: ageInsights,
    );
  }

  static List<Finding> findingsFrom(ClinicalCorrelationReport r, AppLocalizations l10n) {
    final out = <Finding>[];

    if (r.bmi != null) {
      final b = r.bmi!;
      final band = b.bmi < MedicalGuidelines.bmiUnder
          ? 'underweight'
          : b.bmi < MedicalGuidelines.bmiNormal
              ? 'healthy'
              : b.bmi < MedicalGuidelines.bmiOver
                  ? 'overweight'
                  : b.bmi < MedicalGuidelines.bmiObeseI
                      ? 'obesity_class_i'
                      : 'obesity_class_ii_plus';
      final action = b.bmi >= MedicalGuidelines.bmiOver
          ? l10n.clinicalBmiActionOver
          : b.bmi >= MedicalGuidelines.bmiNormal
              ? l10n.clinicalBmiActionNormal
              : b.bmi < MedicalGuidelines.bmiUnder
                  ? l10n.clinicalBmiActionUnder
                  : '';
      out.add(Finding(
        category: l10n.categoryWeight,
        status: b.riskMultiplier >= 1.5
            ? 'critical'
            : b.riskMultiplier >= 1.2
                ? 'warning'
                : 'good',
        value: l10n.clinicalBmiValue(b.bmi.toStringAsFixed(1)),
        message: '${l10n.bmiMessage(band)}$action',
      ));
    }

    if (r.idealWeight != null && r.bmi != null) {
      final i = r.idealWeight!;
      out.add(Finding(
        category: l10n.clinicalCategoryHealthyWeight,
        status: 'info',
        value: l10n.clinicalAroundKg(i.midpointKg.round()),
        message: l10n.clinicalIdealWeightNote,
      ));
    }

    if (r.ahaBp != null) {
      final a = r.ahaBp!;
      out.add(Finding(
        category: l10n.categoryBloodPressure,
        status: a.status,
        value: _localizedBpBand(a.band, l10n),
        message: _localizedBpTreatment(a, l10n),
      ));
    } else if (r.escBpSummary != null) {
      out.add(Finding(
        category: l10n.categoryBloodPressure,
        status: 'info',
        value: r.escBpSummary,
        message: l10n.clinicalBpHighNormalMsg,
      ));
    }

    if (r.glucose != null) {
      final g = r.glucose!;
      out.add(Finding(
        category: l10n.categoryBloodGlucose,
        status: g.status,
        value: _localizedGlucoseBand(g.adaFastingBand, l10n),
        message: _localizedGlucoseMessage(g, l10n),
      ));
    }

    if (r.metabolicSyndrome != null) {
      final m = r.metabolicSyndrome!;
      out.add(Finding(
        category: l10n.clinicalCategoryMetabolic,
        status: m.likelyPresent == true
            ? 'critical'
            : m.criteriaMet >= 2
                ? 'warning'
                : 'info',
        value: m.likelyPresent == null
            ? l10n.clinicalWarningSigns(m.criteriaMet)
            : m.likelyPresent!
                ? l10n.statusNeedsAttention
                : l10n.clinicalLookingOkay,
        message: _localizedMetabolicMessage(m.message, l10n),
      ));
    }

    if (r.combinedRisk != null) {
      final c = r.combinedRisk!;
      out.add(Finding(
        category: l10n.clinicalCategoryCombinedRisk,
        status: c.tier == 'very_high' || c.tier == 'high'
            ? 'critical'
            : c.tier == 'moderate'
                ? 'warning'
                : 'good',
        value: _localizedRiskTier(c.tier, l10n),
        message: _localizedRiskMessage(c.tier, l10n),
      ));
      for (final flag in c.pathologyFlags) {
        final localized = _localizedPathologyFlag(flag, l10n);
        out.add(Finding(
          category: l10n.clinicalCategoryWhatMeans,
          status: 'warning',
          value: localized.$1,
          message: localized.$2,
        ));
      }
    }

    for (final insight in r.ageInsights) {
      out.add(Finding(
        category: l10n.clinicalCategoryForAge,
        status: 'info',
        message: _localizedAgeInsight(insight, l10n),
      ));
    }

    return out;
  }

  static String _localizedBpTreatment(AhaBpClassification a, AppLocalizations l10n) {
    final band = a.band;
    String base;
    if (band.contains('grade 3') || band.contains('crisis')) {
      base = l10n.bpMsgGrade3;
    } else if (band.contains('grade 2')) {
      base = l10n.bpMsgGrade2;
    } else if (band.contains('grade 1') || band.contains('Hypertension')) {
      base = l10n.bpMsgGrade1;
    } else if (band.contains('High-normal')) {
      base = l10n.bpMsgHighNormal;
    } else if (band.contains('Optimal')) {
      base = l10n.bpMsgOptimal;
    } else if (band.contains('Normal')) {
      base = l10n.bpMsgNormal;
    } else if (band.contains('Low')) {
      base = l10n.bpMsgLow;
    } else {
      base = a.treatmentNote;
    }
    if (a.treatmentNote == 'older_adult') {
      return '$base ${l10n.clinicalBpOlderAdultSuffix}';
    }
    return base;
  }

  static String _localizedMetabolicMessage(String key, AppLocalizations l10n) =>
      switch (key) {
        'insufficient' => l10n.clinicalMetabolicInsufficient,
        'present' => l10n.clinicalMetabolicPresent,
        'partial' => l10n.clinicalMetabolicPartial,
        'ok' => l10n.clinicalMetabolicOk,
        _ => key,
      };

  static String _localizedRiskMessage(String tier, AppLocalizations l10n) =>
      switch (tier) {
        'very_high' || 'high' => l10n.clinicalRiskMsgHigh,
        'moderate' => l10n.clinicalRiskMsgModerate,
        _ => l10n.clinicalRiskMsgLow,
      };

  static (String, String) _localizedPathologyFlag(String key, AppLocalizations l10n) =>
      switch (key) {
        'extra_weight' => (
            l10n.clinicalFlagExtraWeightTitle,
            l10n.clinicalFlagExtraWeightBody,
          ),
        'weight_bp_sugar' => (
            l10n.clinicalFlagTripleTitle,
            l10n.clinicalFlagTripleBody,
          ),
        'low_weight_bp' => (
            l10n.clinicalFlagLowWeightBpTitle,
            l10n.clinicalFlagLowWeightBpBody,
          ),
        'high_sugar_lean' => (
            l10n.clinicalFlagLeanDiabetesTitle,
            l10n.clinicalFlagLeanDiabetesBody,
          ),
        'high_bp_young' => (
            l10n.clinicalFlagYoungHtnTitle,
            l10n.clinicalFlagYoungHtnBody,
          ),
        _ => () {
            final parts = key.split('|');
            return (parts.first, parts.length > 1 ? parts[1] : key);
          }(),
      };

  static String _localizedAgeInsight(String key, AppLocalizations l10n) =>
      switch (key) {
        'pediatric' => l10n.clinicalAgePediatric,
        'age45_weight_sugar' => l10n.clinicalAge45WeightSugar,
        'age60_systolic' => l10n.clinicalAge60Systolic,
        'age65_target' => l10n.clinicalAge65Target,
        'young_diabetes_lean' => l10n.clinicalAgeYoungDiabetesLean,
        _ => key,
      };

  static String _localizedBpBand(String band, AppLocalizations l10n) {
    if (band.contains('grade 3') || band.contains('crisis')) return l10n.clinicalBpVeryHigh;
    if (band.contains('grade 2')) return l10n.clinicalBpHighGrade2;
    if (band.contains('grade 1') || band.contains('Hypertension')) return l10n.clinicalBpHigh;
    if (band.contains('High-normal')) return l10n.clinicalBpALittleHigh;
    if (band.contains('Normal') || band.contains('Optimal')) return l10n.clinicalGlucoseNormal;
    if (band.contains('Low')) return l10n.clinicalBpLow;
    return band;
  }

  static String _localizedGlucoseBand(String band, AppLocalizations l10n) {
    if (band.contains('hypoglycemia') || band.contains('Below')) return l10n.clinicalGlucoseTooLow;
    if (band.contains('Normal')) return l10n.clinicalGlucoseNormal;
    if (band.contains('Prediabetes')) return l10n.clinicalGlucosePrediabetes;
    if (band.contains('Diabetes')) return l10n.clinicalGlucoseDiabetes;
    return band;
  }

  static String _localizedGlucoseMessage(GlucoseCorrelation g, AppLocalizations l10n) {
    if (g.status == 'critical' && g.adaFastingBand.contains('Below')) {
      return l10n.glucoseMessage('hypoglycemia');
    }
    if (g.status == 'good') return l10n.glucoseMessage('normal');
    if (g.adaFastingBand.contains('Prediabetes')) return l10n.glucoseMessage('prediabetes');
    return l10n.glucoseMessage('diabetes');
  }

  static String _localizedRiskTier(String tier, AppLocalizations l10n) => switch (tier) {
        'very_high' => l10n.clinicalRiskVeryHigh,
        'high' => l10n.clinicalRiskElevated,
        'moderate' => l10n.clinicalRiskModerate,
        _ => l10n.clinicalRiskLow,
      };

  static List<Recommendation> recommendationsFrom(
    ClinicalCorrelationReport r,
    AppLocalizations l10n,
  ) {
    final out = <Recommendation>[];

    if (r.metabolicSyndrome?.likelyPresent == true) {
      out.add(Recommendation(
        priority: 'high',
        text: l10n.clinicalRecMetabolicCluster,
      ));
    }

    if (r.combinedRisk != null &&
        (r.combinedRisk!.tier == 'high' ||
            r.combinedRisk!.tier == 'very_high')) {
      out.add(Recommendation(
        priority: 'high',
        text: l10n.clinicalRecCombinedHigh,
      ));
    }

    if (r.bmi != null && r.bmi!.pctDeviationFromIdeal > 10) {
      out.add(Recommendation(
        priority: 'medium',
        text: l10n.clinicalRecWeightLoss5to7,
      ));
    }

    if (r.glucose?.adaFastingBand.contains('Prediabetes') == true) {
      out.add(Recommendation(
        priority: 'high',
        text: l10n.clinicalRecPrediabetes,
      ));
    }

    if (_isHypertensive(r.ahaBp)) {
      out.add(Recommendation(
        priority: 'high',
        text: l10n.clinicalRecHighBp,
      ));
    }

    return out;
  }

  // ── BMI & ideal weight ───────────────────────────────────────────────────

  static IdealWeightEstimates _idealWeights(double heightCm, String? gender) {
    final inchesOver5ft = max(0.0, (heightCm / 2.54) - 60);
    final isMale = _isMale(gender);

    final devine = isMale
        ? 50.0 + 2.3 * inchesOver5ft
        : 45.5 + 2.3 * inchesOver5ft;
    final robinson = isMale
        ? 52.0 + 1.9 * inchesOver5ft
        : 49.0 + 1.7 * inchesOver5ft;
    final hamwi = isMale
        ? 48.0 + 2.7 * inchesOver5ft
        : 45.5 + 2.2 * inchesOver5ft;
    final lorentz = isMale
        ? heightCm - 100 - ((heightCm - 150) / 4)
        : heightCm - 100 - ((heightCm - 150) / 2);

    final mid = (devine + robinson + hamwi + lorentz) / 4;
    return IdealWeightEstimates(
      devineKg: devine,
      robinsonKg: robinson,
      hamwiKg: hamwi,
      lorentzKg: lorentz,
      midpointKg: mid,
    );
  }

  static BmiAnalysis _bmiAnalysis({
    required double weightKg,
    required double heightCm,
    required double idealMidKg,
  }) {
    final bmi = weightKg / pow(heightCm / 100, 2);
    final who = _whoCategory(bmi);
    final mult = _bmiRiskMultiplier(bmi);
    final pctDev = idealMidKg > 0
        ? ((weightKg - idealMidKg) / idealMidKg) * 100
        : 0.0;
    return BmiAnalysis(
      bmi: bmi,
      whoCategory: who,
      riskMultiplier: mult,
      idealMidKg: idealMidKg,
      pctDeviationFromIdeal: pctDev,
    );
  }

  static String _whoCategory(double bmi) {
    if (bmi < MedicalGuidelines.bmiUnder) return 'Underweight (<18.5)';
    if (bmi < MedicalGuidelines.bmiNormal) return 'Normal (18.5–24.9)';
    if (bmi < MedicalGuidelines.bmiOver) return 'Overweight (25–29.9)';
    if (bmi < MedicalGuidelines.bmiObeseI) return 'Obesity class I (30–34.9)';
    if (bmi < 40) return 'Obesity class II (35–39.9)';
    return 'Obesity class III (≥40)';
  }

  /// Approximate relative cardiometabolic risk vs BMI 18.5–24.9 (CDC/WHO).
  static double _bmiRiskMultiplier(double bmi) {
    if (bmi < MedicalGuidelines.bmiUnder) return 1.1;
    if (bmi < MedicalGuidelines.bmiNormal) return 1.0;
    if (bmi < MedicalGuidelines.bmiOver) return 1.25;
    if (bmi < MedicalGuidelines.bmiObeseI) return 1.55;
    if (bmi < 40) return 1.85;
    return 2.2;
  }

  // ── Blood pressure (ESC/ESH — same as BloodPressure / Health Index) ──────
  //
  // Do NOT use ACC/AHA Stage 1 (DBP ≥ 80): that labels textbook-healthy
  // 120/80 as hypertension and contradicts the app's Health Index + BP card.

  static AhaBpClassification _ahaBp(
    double systolic,
    double diastolic, {
    int? age,
  }) {
    final s = systolic.round();
    final d = diastolic.round();
    // Reuse ESC/ESH bands so Insights never contradicts Health Index.
    final esc = BloodPressure.classify(s.toDouble(), d.toDouble(), age: age);
    final band = switch (esc.band) {
      BpBand.low => 'Low (<90 or <60)',
      BpBand.optimal => 'Optimal (<120 and <80)',
      BpBand.normal => 'Normal (around 120/80)',
      BpBand.highNormal => 'High-normal (130–139 or 85–89)',
      BpBand.grade1 => 'Hypertension grade 1 (≥140 or ≥90)',
      BpBand.grade2 => 'Hypertension grade 2 (≥160 or ≥100)',
      BpBand.grade3 => 'Hypertension grade 3 (≥180 or ≥110)',
    };

    var treatment = '';
    if (age != null && age >= 65 && s >= 140 && d < 90) {
      treatment = 'older_adult';
    }

    return AhaBpClassification(
      band: band,
      status: esc.status,
      treatmentNote: treatment,
    );
  }

  /// True hypertension for flags / risk stacking (≥140 or ≥90).
  static bool _isHypertensive(AhaBpClassification? aha) {
    if (aha == null) return false;
    return aha.band.contains('Hypertension') || aha.band.contains('crisis');
  }

  /// Elevated but not yet hypertension (high-normal).
  static bool _isHighNormal(AhaBpClassification? aha) {
    if (aha == null) return false;
    return aha.band.contains('High-normal');
  }

  // ── Glucose ──────────────────────────────────────────────────────────────

  static GlucoseCorrelation _glucoseCorrelation(double mgdl) {
    if (mgdl < MedicalGuidelines.glucoseHypoMax) {
      return const GlucoseCorrelation(
        adaFastingBand: 'Below normal (hypoglycemia)',
        hba1cEquivalent: 'N/A — treat low glucose',
        status: 'critical',
      );
    }
    if (mgdl <= MedicalGuidelines.glucoseNormalMax) {
      return const GlucoseCorrelation(
        adaFastingBand: 'Normal fasting (<100 mg/dL)',
        hba1cEquivalent: '<5.7%',
        status: 'good',
      );
    }
    if (mgdl <= MedicalGuidelines.glucosePrediabetesMax) {
      return const GlucoseCorrelation(
        adaFastingBand: 'Prediabetes / IFG (100–125 mg/dL)',
        hba1cEquivalent: '5.7–6.4%',
        status: 'warning',
      );
    }
    return const GlucoseCorrelation(
      adaFastingBand: 'Diabetes range (≥126 mg/dL fasting)',
      hba1cEquivalent: '≥6.5%',
      status: 'critical',
    );
  }

  // ── Metabolic syndrome (harmonized ATP III / IDF) ────────────────────────

  static MetabolicSyndromeResult _metabolicSyndrome(
    ClinicalInput input,
    double? bmi,
  ) {
    final met = <String>[];
    var checked = 0;

    // 1 — Central adiposity
    checked++;
    final waistOk = _centralObesity(input, bmi);
    if (waistOk == true) met.add('Central obesity / elevated adiposity');

    // 2 — Triglycerides
    if (input.triglyceridesMgdl != null) {
      checked++;
      if (input.triglyceridesMgdl! >= 150) {
        met.add('Triglycerides ≥150 mg/dL');
      }
    }

    // 3 — HDL
    if (input.hdlMgdl != null) {
      checked++;
      final lowHdl = input.isMale
          ? input.hdlMgdl! < 40
          : input.isFemale
              ? input.hdlMgdl! < 50
              : input.hdlMgdl! < 40;
      if (lowHdl) met.add('Low HDL cholesterol');
    }

    // 4 — Blood pressure
    if (input.systolic != null && input.diastolic != null) {
      checked++;
      if (input.systolic! >= 130 || input.diastolic! >= 85) {
        met.add('Blood pressure ≥130/85 mmHg');
      }
    }

    // 5 — Fasting glucose
    if (input.fastingGlucoseMgdl != null) {
      checked++;
      if (input.fastingGlucoseMgdl! >= 100) {
        met.add('Fasting glucose ≥100 mg/dL (≥5.6 mmol/L)');
      }
    }

    if (checked < 2) {
      return MetabolicSyndromeResult(
        likelyPresent: null,
        criteriaMet: met.length,
        criteriaChecked: checked,
        metCriteria: met,
        message: 'insufficient',
      );
    }

    final present = met.length >= 3;
    final partial = !present && met.length >= 2;
    return MetabolicSyndromeResult(
      likelyPresent: present ? true : (partial ? null : false),
      criteriaMet: met.length,
      criteriaChecked: checked,
      metCriteria: met,
      message: present
          ? 'present'
          : partial
              ? 'partial'
              : 'ok',
    );
  }

  static bool? _centralObesity(ClinicalInput input, double? bmi) {
    if (input.waistCm != null && input.waistCm! > 0) {
      final ethnic = (input.ethnicity ?? '').toLowerCase();
      final southAsian = ethnic.contains('asian') ||
          ethnic.contains('south') ||
          ethnic.contains('indian');
      if (input.isMale) {
        final cut = southAsian ? 90.0 : 102.0;
        return input.waistCm! >= cut;
      }
      if (input.isFemale) {
        final cut = southAsian ? 80.0 : 88.0;
        return input.waistCm! >= cut;
      }
      return input.waistCm! >= 94;
    }
    if (bmi != null && bmi >= 30) {
      return true; // BMI proxy when waist absent — note in combined risk
    }
    if (bmi != null && bmi >= 25) return false;
    return null;
  }

  // ── Combined risk & pathology flags ──────────────────────────────────────

  static CombinedRiskResult _combinedRisk({
    required ClinicalInput input,
    required BmiAnalysis? bmi,
    required AhaBpClassification? aha,
    required GlucoseCorrelation? glucose,
    required MetabolicSyndromeResult? metabolic,
  }) {
    var mult = 1.0;
    final flags = <String>[];

    if (bmi != null) {
      mult *= bmi.riskMultiplier;
      if (bmi.bmi >= MedicalGuidelines.bmiOver) {
        flags.add('extra_weight');
      }
    }

    if (aha != null) {
      if (aha.band.contains('grade 3') || aha.band.contains('crisis')) {
        mult *= 1.8;
      } else if (aha.band.contains('grade 2')) {
        mult *= 1.6;
      } else if (_isHypertensive(aha)) {
        mult *= 1.35;
      } else if (_isHighNormal(aha)) {
        mult *= 1.1;
      }
    }

    if (glucose != null) {
      if (glucose.adaFastingBand.contains('Diabetes')) {
        mult *= 1.85;
      } else if (glucose.adaFastingBand.contains('Prediabetes')) {
        mult *= 1.35;
      }
    }

    if (metabolic?.likelyPresent == true) mult *= 1.4;

    // Triple combination: obesity + true HTN + hyperglycemia
    final obese = bmi != null && bmi.bmi >= MedicalGuidelines.bmiOver;
    final htn = _isHypertensive(aha);
    final dysgly = glucose != null &&
        !glucose.adaFastingBand.contains('Normal') &&
        !glucose.adaFastingBand.contains('hypoglycemia');
    if (obese && htn && dysgly) {
      mult = max(mult, 3.0);
      flags.add('weight_bp_sugar');
    }

    if (bmi != null &&
        bmi.bmi < MedicalGuidelines.bmiNormal &&
        input.systolic != null &&
        input.systolic! < 100 &&
        input.age != null &&
        input.age! >= 65) {
      flags.add('low_weight_bp');
    }

    if (bmi != null &&
        bmi.bmi < MedicalGuidelines.bmiOver &&
        glucose != null &&
        glucose.adaFastingBand.contains('Diabetes')) {
      flags.add('high_sugar_lean');
    }

    // Only true hypertension (≥140/≥90) — never for healthy 120/80.
    if (input.age != null && input.age! < 40 && _isHypertensive(aha)) {
      flags.add('high_bp_young');
    }

    mult = mult.clamp(1.0, 4.0);
    final tier = mult >= 3.0
        ? 'very_high'
        : mult >= 2.2
            ? 'high'
            : mult >= 1.4
                ? 'moderate'
                : 'low';

    return CombinedRiskResult(
      relativeRiskMultiplier: mult,
      tier: tier,
      pathologyFlags: flags,
      message: tier, // localized in findingsFrom via tier
    );
  }

  static List<String> _ageInsights(
    ClinicalInput input,
    BmiAnalysis? bmi,
    AhaBpClassification? aha,
    GlucoseCorrelation? glucose,
  ) {
    final age = input.age;
    if (age == null) return const [];

    final insights = <String>[];

    if (age >= 45 &&
        bmi != null &&
        bmi.bmi >= MedicalGuidelines.bmiOver &&
        glucose != null &&
        !glucose.adaFastingBand.contains('Normal')) {
      insights.add('age45_weight_sugar');
    }

    if (age >= 60 &&
        input.systolic != null &&
        input.systolic! >= 140 &&
        input.diastolic != null &&
        input.diastolic! < 90) {
      insights.add('age60_systolic');
    }

    if (age >= 65) {
      insights.add('age65_target');
    }

    if (age < 40 &&
        glucose != null &&
        glucose.adaFastingBand.contains('Diabetes') &&
        bmi != null &&
        bmi.bmi < MedicalGuidelines.bmiNormal) {
      insights.add('young_diabetes_lean');
    }

    return insights;
  }

  static bool _isMale(String? gender) {
    final g = (gender ?? '').toLowerCase();
    return g.startsWith('m') || g == 'male';
  }
}
