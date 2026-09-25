/// Educational ECG rhythm reference for Heart Rate & Rhythm / Ai Doc.
///
/// Source concepts: classic adult ECG teaching (normal sinus, sinus
/// brady/tachy, AF, VT, VF, AV blocks I–III). Not a diagnosis — Apple Watch
/// ECG only reports a subset (sinus / AFib / inconclusive).
///
/// App **wellness** resting comfort stays in [MedicalGuidelines] (60–105 bpm
/// at rest). Classic ECG teaching for normal sinus rate is 60–100 bpm; the
/// two bands serve different jobs and must not be mixed.
library;

import 'medical_guidelines.dart';

/// Canonical rhythm kinds used in PHA’s understanding layer.
enum EcgRhythmKind {
  normalSinus,
  sinusTachycardia,
  sinusBradycardia,
  atrialFibrillation,
  ventricularTachycardia,
  ventricularFibrillation,
  avBlockFirstDegree,
  avBlockSecondMobitzI,
  avBlockThirdDegree,
  /// Apple Watch / HealthKit inconclusive or unrecognized.
  inconclusive,
  unknown,
}

/// Severity for UI / Health Index style signals.
enum EcgRhythmSeverity {
  /// Expected / benign teaching pattern.
  normal,
  /// Watch closely; often situational (e.g. sinus tachy).
  attention,
  /// Seek care / risk teaching pattern.
  risk,
}

/// One rhythm entry with the key ECG features from training materials.
class EcgRhythmProfile {
  final EcgRhythmKind kind;
  final String id;
  final EcgRhythmSeverity severity;
  /// Classic teaching heart-rate band, when applicable (null = N/A).
  final int? rateMinBpm;
  final int? rateMaxBpm;
  final bool rateAbove;
  final bool rateBelow;
  /// English key-feature bullets for AI / debug context (UI uses l10n).
  final List<String> keyFeaturesEn;
  /// Whether Apple Watch ECG can emit this class directly.
  final bool appleWatchClassifiable;

  const EcgRhythmProfile({
    required this.kind,
    required this.id,
    required this.severity,
    required this.keyFeaturesEn,
    this.rateMinBpm,
    this.rateMaxBpm,
    this.rateAbove = false,
    this.rateBelow = false,
    this.appleWatchClassifiable = false,
  });
}

/// Static knowledge base + mappers for HealthKit / rate hints.
class EcgRhythmKnowledge {
  EcgRhythmKnowledge._();

  /// Classic ECG normal-sinus rate (teaching). Distinct from app wellness max.
  static const classicSinusMinBpm = 60;
  static const classicSinusMaxBpm = 100;

  static const catalog = <EcgRhythmProfile>[
    EcgRhythmProfile(
      kind: EcgRhythmKind.normalSinus,
      id: 'normal_sinus',
      severity: EcgRhythmSeverity.normal,
      rateMinBpm: classicSinusMinBpm,
      rateMaxBpm: classicSinusMaxBpm,
      appleWatchClassifiable: true,
      keyFeaturesEn: [
        'Heart rate 60–100 bpm',
        'Regular rhythm',
        'Each P wave precedes a QRS complex',
        'PR interval 0.12–0.20 s',
        'QRS duration < 0.12 s',
      ],
    ),
    EcgRhythmProfile(
      kind: EcgRhythmKind.sinusTachycardia,
      id: 'sinus_tachycardia',
      severity: EcgRhythmSeverity.attention,
      rateMinBpm: 100,
      rateAbove: true,
      keyFeaturesEn: [
        'Heart rate > 100 bpm',
        'Regular rhythm',
        'Each P wave precedes a QRS complex',
        'PR interval 0.12–0.20 s',
        'QRS duration < 0.12 s',
      ],
    ),
    EcgRhythmProfile(
      kind: EcgRhythmKind.sinusBradycardia,
      id: 'sinus_bradycardia',
      severity: EcgRhythmSeverity.attention,
      rateMaxBpm: 60,
      rateBelow: true,
      keyFeaturesEn: [
        'Heart rate < 60 bpm',
        'Regular rhythm',
        'Each P wave precedes a QRS complex',
        'PR interval 0.12–0.20 s',
        'QRS duration < 0.12 s',
      ],
    ),
    EcgRhythmProfile(
      kind: EcgRhythmKind.atrialFibrillation,
      id: 'atrial_fibrillation',
      severity: EcgRhythmSeverity.risk,
      rateMinBpm: 100,
      rateMaxBpm: 250,
      appleWatchClassifiable: true,
      keyFeaturesEn: [
        'Heart rate often 100–250 bpm',
        'Irregular rhythm',
        'P waves absent',
        'QRS usually narrow (≤ 0.12 s)',
      ],
    ),
    EcgRhythmProfile(
      kind: EcgRhythmKind.ventricularTachycardia,
      id: 'ventricular_tachycardia',
      severity: EcgRhythmSeverity.risk,
      rateMinBpm: 100,
      rateMaxBpm: 250,
      keyFeaturesEn: [
        'Heart rate 100–250 bpm',
        'Regular rhythm',
        'Wide QRS complexes (≥ 0.12 s)',
        'P waves usually absent',
      ],
    ),
    EcgRhythmProfile(
      kind: EcgRhythmKind.ventricularFibrillation,
      id: 'ventricular_fibrillation',
      severity: EcgRhythmSeverity.risk,
      keyFeaturesEn: [
        'No organized rhythm',
        'Chaotic baseline',
        'QRS not identifiable',
        'P waves absent',
      ],
    ),
    EcgRhythmProfile(
      kind: EcgRhythmKind.avBlockFirstDegree,
      id: 'av_block_1',
      severity: EcgRhythmSeverity.attention,
      keyFeaturesEn: [
        'PR interval > 0.20 s',
        'Each P wave is followed by a QRS',
        'QRS duration < 0.12 s',
      ],
    ),
    EcgRhythmProfile(
      kind: EcgRhythmKind.avBlockSecondMobitzI,
      id: 'av_block_2_mobitz_i',
      severity: EcgRhythmSeverity.risk,
      keyFeaturesEn: [
        'Progressive PR (P–Q) lengthening',
        'Eventual dropped QRS',
        'Cyclic pattern with dropouts',
      ],
    ),
    EcgRhythmProfile(
      kind: EcgRhythmKind.avBlockThirdDegree,
      id: 'av_block_3',
      severity: EcgRhythmSeverity.risk,
      keyFeaturesEn: [
        'No relationship between P waves and QRS complexes',
        'Independent atrial and ventricular rates',
        'Ventricular escape rhythm',
      ],
    ),
  ];

  static EcgRhythmProfile? profile(EcgRhythmKind kind) {
    for (final p in catalog) {
      if (p.kind == kind) return p;
    }
    return null;
  }

  /// Map Apple HealthKit / health plugin classification strings.
  static EcgRhythmKind fromAppleClassification(String? raw) {
    if (raw == null || raw.trim().isEmpty) return EcgRhythmKind.unknown;
    final c = raw.toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    if (c.contains('sinus_rhythm') || c == 'sinus' || c.contains('sinusrhythm')) {
      return EcgRhythmKind.normalSinus;
    }
    if (c.contains('atrial_fibrillation') ||
        c.contains('atrialfibrillation') ||
        c.contains('afib') ||
        c == 'af') {
      return EcgRhythmKind.atrialFibrillation;
    }
    if (c.contains('inconclusive') ||
        c.contains('low_heart') ||
        c.contains('high_heart') ||
        c.contains('poor_reading') ||
        c.contains('unrecognized') ||
        c.contains('not_set')) {
      return EcgRhythmKind.inconclusive;
    }
    // Educational aliases if a clinician note / OCR ever supplies them.
    if (c.contains('ventricular_fibrillation') || c.contains('vfib') || c == 'vf') {
      return EcgRhythmKind.ventricularFibrillation;
    }
    if (c.contains('ventricular_tachycardia') || c.contains('vtach') || c == 'vt') {
      return EcgRhythmKind.ventricularTachycardia;
    }
    if (c.contains('sinus_tach') || c.contains('sinustach')) {
      return EcgRhythmKind.sinusTachycardia;
    }
    if (c.contains('sinus_brady') || c.contains('sinusbrady')) {
      return EcgRhythmKind.sinusBradycardia;
    }
    if (c.contains('mobitz') || c.contains('second_degree') || c.contains('av_block_2')) {
      return EcgRhythmKind.avBlockSecondMobitzI;
    }
    if (c.contains('third_degree') ||
        c.contains('complete_heart_block') ||
        c.contains('av_block_3')) {
      return EcgRhythmKind.avBlockThirdDegree;
    }
    if (c.contains('first_degree') || c.contains('av_block_1')) {
      return EcgRhythmKind.avBlockFirstDegree;
    }
    return EcgRhythmKind.unknown;
  }

  /// Rate-only teaching hint for **resting** samples (not during exercise).
  /// Uses classic ECG bands (60–100), not the app wellness max (105).
  static EcgRhythmKind? inferFromRestingRate(double? restingBpm) {
    if (restingBpm == null || restingBpm <= 0) return null;
    if (restingBpm < classicSinusMinBpm) return EcgRhythmKind.sinusBradycardia;
    if (restingBpm > classicSinusMaxBpm) return EcgRhythmKind.sinusTachycardia;
    return EcgRhythmKind.normalSinus;
  }

  /// Irregular-rhythm notifications from Apple Watch → AF teaching attention.
  static EcgRhythmKind? inferFromIrregularEvents({
    required bool irregularRhythm,
    double? restingBpm,
  }) {
    if (!irregularRhythm) return null;
    return EcgRhythmKind.atrialFibrillation;
  }

  /// Compact English brief for Ai Doc / export (always educational).
  static String aiDocBrief({
    EcgRhythmKind? appleClass,
    double? restingBpm,
    bool irregularRhythm = false,
  }) {
    final lines = <String>[
      'ECG rhythm reference (educational, not a diagnosis):',
      'Normal sinus: regular, each P before QRS, rate 60–100 bpm, PR 0.12–0.20 s, QRS < 0.12 s.',
      'Sinus tachy: same structure, rate > 100 bpm. Sinus brady: same structure, rate < 60 bpm.',
      'Atrial fibrillation: irregular, no P waves, rate often 100–250 bpm.',
      'Ventricular tachycardia: wide QRS (≥ 0.12 s), rate 100–250, usually no P waves.',
      'Ventricular fibrillation: chaotic baseline, no organized QRS — emergency teaching pattern.',
      'AV block I: PR > 0.20 s. Mobitz I: progressive PR then dropped QRS. Complete AV block: P and QRS independent.',
      'App wellness resting comfort is ${MedicalGuidelines.restingHrMin}–${MedicalGuidelines.restingHrMax} bpm at rest (separate from classic ECG 60–100 sinus band).',
    ];
    if (appleClass != null &&
        appleClass != EcgRhythmKind.unknown &&
        appleClass != EcgRhythmKind.inconclusive) {
      final p = profile(appleClass);
      lines.add(
        'Latest Apple Watch ECG class mapped to: ${p?.id ?? appleClass.name}.',
      );
    }
    if (irregularRhythm) {
      lines.add(
        'Device reported irregular rhythm notifications — discuss with a clinician if recurrent; compatible with AF teaching pattern, not a diagnosis.',
      );
    }
    final inferred = inferFromRestingRate(restingBpm);
    if (inferred != null && restingBpm != null) {
      lines.add(
        'Resting rate ${restingBpm.round()} bpm → classic ECG teaching label: ${profile(inferred)?.id ?? inferred.name}.',
      );
    }
    return lines.join('\n');
  }
}
