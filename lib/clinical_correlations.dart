/// Cross-parameter clinical correlations for adult vitals (18+).
///
/// Sources: WHO/CDC BMI; AHA/ACC & ESC/ESH BP; ADA fasting glucose & HbA1c
/// equivalents; harmonized ATP III / IDF metabolic syndrome criteria.
/// Educational — not a diagnosis.
library;

import 'dart:math';

import 'medical_guidelines.dart';
import 'models.dart';

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

  List<Finding> toFindings() => ClinicalCorrelationEngine.findingsFrom(this);

  List<Recommendation> toRecommendations() =>
      ClinicalCorrelationEngine.recommendationsFrom(this);
}

/// Deterministic cardiometabolic correlation engine.
abstract final class ClinicalCorrelationEngine {
  static ClinicalCorrelationReport analyze(ClinicalInput input) {
    if (input.age != null && input.age! < 18) {
      return ClinicalCorrelationReport(
        ageInsights: const [
          'Pediatric percentiles apply under 18 — adult BMI/BP/glucose cut-offs '
          'are not used here.',
        ],
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

  static List<Finding> findingsFrom(ClinicalCorrelationReport r) {
    final out = <Finding>[];

    if (r.bmi != null) {
      final b = r.bmi!;
      final action = b.bmi >= MedicalGuidelines.bmiOver
          ? ' Focus on smaller portions, more vegetables, and daily walks. '
              'A 5–7% weight loss already helps heart and blood sugar.'
          : b.bmi >= MedicalGuidelines.bmiNormal
              ? ' Small daily habits (steps + protein at meals) help keep '
                  'weight from creeping up.'
              : b.bmi < MedicalGuidelines.bmiUnder
                  ? ' Eat protein-rich meals more often and check with a '
                      'doctor if weight loss was not planned.'
                  : '';
      out.add(Finding(
        category: 'Weight',
        status: b.riskMultiplier >= 1.5
            ? 'critical'
            : b.riskMultiplier >= 1.2
                ? 'warning'
                : 'good',
        value: 'BMI ${b.bmi.toStringAsFixed(1)}',
        message: '${_plainBmiSummary(b)}$action',
      ));
    }

    if (r.idealWeight != null && r.bmi != null) {
      final i = r.idealWeight!;
      out.add(Finding(
        category: 'Healthy weight range',
        status: 'info',
        value: 'Around ${i.midpointKg.toStringAsFixed(0)} kg',
        message: IdealWeightEstimates.limitationNote,
      ));
    }

    if (r.ahaBp != null) {
      final a = r.ahaBp!;
      out.add(Finding(
        category: 'Blood Pressure',
        status: a.status,
        value: _plainBpBand(a.band),
        message: a.treatmentNote,
      ));
    } else if (r.escBpSummary != null) {
      out.add(Finding(
        category: 'Blood Pressure',
        status: 'info',
        value: r.escBpSummary,
        message:
            'Your reading looks a bit high-normal. Cut salt, stay active, '
            'and check BP again on another day.',
      ));
    }

    if (r.glucose != null) {
      final g = r.glucose!;
      out.add(Finding(
        category: 'Blood Glucose',
        status: g.status,
        value: _plainGlucoseBand(g.adaFastingBand),
        message: _plainGlucoseMessage(g),
      ));
    }

    if (r.metabolicSyndrome != null) {
      final m = r.metabolicSyndrome!;
      out.add(Finding(
        category: 'Metabolic health',
        status: m.likelyPresent == true
            ? 'critical'
            : m.criteriaMet >= 2
                ? 'warning'
                : 'info',
        value: m.likelyPresent == null
            ? '${m.criteriaMet} warning signs'
            : m.likelyPresent!
                ? 'Needs attention'
                : 'Looking okay',
        message: m.message,
      ));
    }

    if (r.combinedRisk != null) {
      final c = r.combinedRisk!;
      out.add(Finding(
        category: 'Overall heart & sugar risk',
        status: c.tier == 'very_high' || c.tier == 'high'
            ? 'critical'
            : c.tier == 'moderate'
                ? 'warning'
                : 'good',
        value: _plainRiskTier(c.tier),
        message: c.message,
      ));
      for (final flag in c.pathologyFlags) {
        final parts = flag.split('|');
        out.add(Finding(
          category: 'What this means',
          status: 'warning',
          value: parts.first,
          message: parts.length > 1 ? parts[1] : flag,
        ));
      }
    }

    for (final insight in r.ageInsights) {
      out.add(Finding(
        category: 'For your age',
        status: 'info',
        message: insight,
      ));
    }

    return out;
  }

  static String _plainBmiSummary(BmiAnalysis b) {
    if (b.bmi < MedicalGuidelines.bmiUnder) {
      return 'Your weight is lower than the healthy range for your height.';
    }
    if (b.bmi < MedicalGuidelines.bmiNormal) {
      return 'Your weight is in a healthy range for your height. Nice work!';
    }
    if (b.bmi < MedicalGuidelines.bmiOver) {
      return 'Your weight is a bit above the healthy range.';
    }
    if (b.bmi < MedicalGuidelines.bmiObeseI) {
      return 'Your weight is clearly above the healthy range. This can '
          'raise blood pressure and blood sugar over time.';
    }
    return 'Your weight is well above the healthy range. This can strain '
        'your heart and metabolism — a doctor can help you plan safely.';
  }

  static String _plainBpBand(String band) {
    if (band.contains('grade 3') || band.contains('crisis')) {
      return 'Very high — seek care';
    }
    if (band.contains('grade 2')) return 'High (grade 2)';
    if (band.contains('grade 1') || band.contains('Hypertension')) {
      return 'High';
    }
    if (band.contains('High-normal')) return 'A little high';
    if (band.contains('Normal') || band.contains('Optimal')) return 'Normal';
    if (band.contains('Low')) return 'Low';
    return band;
  }

  static String _plainGlucoseBand(String band) {
    if (band.contains('hypoglycemia') || band.contains('Below')) {
      return 'Too low';
    }
    if (band.contains('Normal')) return 'Normal';
    if (band.contains('Prediabetes')) return 'Prediabetes range';
    if (band.contains('Diabetes')) return 'Diabetes range';
    return band;
  }

  static String _plainGlucoseMessage(GlucoseCorrelation g) {
    if (g.status == 'critical' && g.adaFastingBand.contains('Below')) {
      return 'Your blood sugar is too low. Have a quick carb snack '
          '(juice, glucose tablets) and tell a doctor if this happens often.';
    }
    if (g.status == 'good') {
      return 'Your fasting blood sugar looks healthy. Keep up balanced meals '
          'and regular activity.';
    }
    if (g.adaFastingBand.contains('Prediabetes')) {
      return 'Your blood sugar is higher than normal, but not diabetes yet. '
          'Cut sugary drinks, add fiber at meals, walk 10–15 minutes after eating, '
          'and recheck with your doctor.';
    }
    return 'Your blood sugar is in the diabetes range. Please see a doctor '
        'soon for confirmation and a care plan.';
  }

  static String _plainRiskTier(String tier) => switch (tier) {
        'very_high' => 'High — act now',
        'high' => 'Elevated',
        'moderate' => 'Moderate',
        _ => 'Low',
      };

  static List<Recommendation> recommendationsFrom(
    ClinicalCorrelationReport r,
  ) {
    final out = <Recommendation>[];

    if (r.metabolicSyndrome?.likelyPresent == true) {
      out.add(Recommendation(
        priority: 'high',
        text:
            'Several warning signs are present together (weight, blood pressure, '
            'or blood sugar). Lose a little weight if you can, eat more plants and '
            'less salt, walk most days, and ask your doctor for cholesterol and '
            'sugar blood tests.',
      ));
    }

    if (r.combinedRisk != null &&
        (r.combinedRisk!.tier == 'high' ||
            r.combinedRisk!.tier == 'very_high')) {
      out.add(Recommendation(
        priority: 'high',
        text:
            'More than one risk is elevated. Book a checkup soon so your doctor '
            'can review blood pressure, blood sugar, and cholesterol with you.',
      ));
    }

    if (r.bmi != null && r.bmi!.pctDeviationFromIdeal > 10) {
      out.add(Recommendation(
        priority: 'medium',
        text:
            'Aim for a gentle 5–7% weight loss over a few months — that alone '
            'often improves blood pressure and blood sugar.',
      ));
    }

    if (r.glucose?.adaFastingBand.contains('Prediabetes') == true) {
      out.add(Recommendation(
        priority: 'high',
        text:
            'Your sugar is in the prediabetes range. Cut sugary drinks, walk '
            'after meals, and recheck fasting glucose or HbA1c with your doctor.',
      ));
    }

    if (_isHypertensive(r.ahaBp)) {
      out.add(Recommendation(
        priority: 'high',
        text:
            'Your blood pressure is high. Reduce salt, stay active, measure BP '
            'at home for a few days, and share the averages with your doctor.',
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

    var treatment = esc.message;
    if (age != null && age >= 65 && s >= 140 && d < 90) {
      treatment +=
          ' In older adults, the top number often rises first — focus on '
          'that trend and share home averages with your doctor.';
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
        message:
            'Not enough data yet. Log blood pressure, blood sugar, and weight '
            '(and waist if you can) so we can spot metabolic warning signs.',
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
          ? 'Several risk factors are present together (weight, blood pressure, '
              'or blood sugar). This raises heart and diabetes risk — see a doctor '
              'for cholesterol and sugar tests, and improve diet and activity.'
          : partial
              ? 'A couple of warning signs are present. Improve diet, walk more, '
                  'and watch weight — small changes help a lot.'
              : 'From the data we have, metabolic warning signs look under control.',
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
        flags.add(
          'Extra weight|'
          'Carrying extra weight raises the chance of high blood sugar and '
          'heart problems. Smaller portions, more vegetables, and daily walks help.',
        );
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
      flags.add(
        'Weight + BP + sugar|'
        'Extra weight, higher blood pressure, and higher blood sugar together '
        'greatly raise diabetes and heart risk. Focus on food, walks, and a doctor visit.',
      );
    }

    if (bmi != null &&
        bmi.bmi < MedicalGuidelines.bmiNormal &&
        input.systolic != null &&
        input.systolic! < 100 &&
        input.age != null &&
        input.age! >= 65) {
      flags.add(
        'Low weight + low BP|'
        'Low weight with low blood pressure in older age can mean frailty. '
        'Eat enough protein and ask a doctor before cutting calories.',
      );
    }

    if (bmi != null &&
        bmi.bmi < MedicalGuidelines.bmiOver &&
        glucose != null &&
        glucose.adaFastingBand.contains('Diabetes')) {
      flags.add(
        'High sugar, not much weight|'
        'Blood sugar is high even without much extra weight. A doctor should '
        'check what type of diabetes this might be.',
      );
    }

    // Only true hypertension (≥140/≥90) — never for healthy 120/80.
    if (input.age != null && input.age! < 40 && _isHypertensive(aha)) {
      flags.add(
        'High BP under 40|'
        'High blood pressure at a young age should be confirmed with repeat '
        'readings. Ask a doctor if another cause needs checking.',
      );
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
      message: switch (tier) {
        'very_high' || 'high' =>
          'Several risks are elevated together. This is a strong signal to '
              'improve food and activity and see a doctor for a checkup.',
        'moderate' =>
          'Your overall heart and sugar risk is higher than ideal. Small daily '
              'changes — walks, less salt and sugar — make a real difference.',
        _ =>
          'Your overall heart and sugar risk looks relatively low based on '
              'weight, blood pressure, and blood sugar.',
      },
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
      insights.add(
        'After 45, extra weight plus higher blood sugar raise diabetes risk. '
        'Ask your doctor about a sugar check every 1–3 years.',
      );
    }

    if (age >= 60 &&
        input.systolic != null &&
        input.systolic! >= 140 &&
        input.diastolic != null &&
        input.diastolic! < 90) {
      insights.add(
        'After 60, the top blood-pressure number often rises first. Track home '
        'averages and share them with your doctor.',
      );
    }

    if (age >= 65) {
      insights.add(
        'Over 65, many people aim for blood pressure under 140/90 if they feel well. '
        'Your doctor may set a different target if you are frail.',
      );
    }

    if (age < 40 &&
        glucose != null &&
        glucose.adaFastingBand.contains('Diabetes') &&
        bmi != null &&
        bmi.bmi < MedicalGuidelines.bmiNormal) {
      insights.add(
        'Under 40 with high blood sugar but normal weight — see a doctor to '
        'find out what type of diabetes this might be.',
      );
    }

    return insights;
  }

  static bool _isMale(String? gender) {
    final g = (gender ?? '').toLowerCase();
    return g.startsWith('m') || g == 'male';
  }
}
