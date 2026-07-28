/// Office blood-pressure classification (ESC/ESH adult bands).
///
/// Why ESC/ESH (not ACC/AHA alone): under ACC/AHA 2017/2025, DBP ≥ 80 is
/// already "Stage 1 hypertension", so the textbook-healthy 120/80 is labeled
/// hypertensive. ESC/ESH keeps hypertension at ≥ 140 / ≥ 90 and treats
/// 120–129 and/or 80–84 as **normal** — matching common clinical messaging
/// in Europe and everyday "ideal ~120/80" advice.
///
/// Adult diagnostic cut-offs are **not** age- or sex-specific in either
/// guideline. Age/sex mainly change population means and treatment targets,
/// which we surface as optional context — not different stage thresholds.
library;

enum BpBand {
  low,
  optimal,
  normal,
  highNormal,
  grade1,
  grade2,
  grade3,
}

class BpClassification {
  final BpBand band;
  final String label;
  /// Insight card status: good | info | warning | critical
  final String status;
  final String message;

  const BpClassification({
    required this.band,
    required this.label,
    required this.status,
    required this.message,
  });
}

class BloodPressure {
  BloodPressure._();

  /// Classify a single office reading. Uses the worse of systolic / diastolic.
  static BpBand band(double systolic, double diastolic) {
    final s = systolic.round();
    final d = diastolic.round();
    if (s < 90 || d < 60) return BpBand.low;
    if (s >= 180 || d >= 110) return BpBand.grade3;
    if (s >= 160 || d >= 100) return BpBand.grade2;
    if (s >= 140 || d >= 90) return BpBand.grade1;
    if (s >= 130 || d >= 85) return BpBand.highNormal;
    if (s >= 120 || d >= 80) return BpBand.normal;
    return BpBand.optimal;
  }

  /// Health-index score 0–100 for the reading.
  static double score(double systolic, double diastolic) {
    switch (band(systolic, diastolic)) {
      case BpBand.low:
        return 55;
      case BpBand.optimal:
        return 98;
      case BpBand.normal:
        return 94;
      case BpBand.highNormal:
        return 78;
      case BpBand.grade1:
        return 58;
      case BpBand.grade2:
        return 36;
      case BpBand.grade3:
        return 18;
    }
  }

  static BpClassification classify(
    double systolic,
    double diastolic, {
    int? age,
    String? gender,
  }) {
    final s = systolic.round();
    final d = diastolic.round();
    final v = '$s/$d mmHg';
    final b = band(systolic, diastolic);
    final ageNote = _ageSexNote(age, gender);

    switch (b) {
      case BpBand.low:
        return BpClassification(
          band: b,
          label: v,
          status: 'warning',
          message:
              'Blood pressure is below the usual adult range (hypotension). '
              'Stay hydrated and talk to a clinician if you feel dizzy or faint.'
              '${ageNote == null ? '' : ' $ageNote'}',
        );
      case BpBand.optimal:
        return BpClassification(
          band: b,
          label: v,
          status: 'good',
          message:
              'Blood pressure is optimal (<120/<80). Keep up the healthy lifestyle.'
              '${ageNote == null ? '' : ' $ageNote'}',
        );
      case BpBand.normal:
        return BpClassification(
          band: b,
          label: v,
          status: 'good',
          message:
              'Blood pressure is in the normal adult range (around 120/80). '
              'This is a healthy target for most adults — not hypertension.'
              '${ageNote == null ? '' : ' $ageNote'}',
        );
      case BpBand.highNormal:
        return BpClassification(
          band: b,
          label: v,
          status: 'info',
          message:
              'Blood pressure is a little high (not hypertension yet). '
              'Monitor regularly; cut salt, stay active, and watch trends.'
              '${ageNote == null ? '' : ' $ageNote'}',
        );
      case BpBand.grade1:
        return BpClassification(
          band: b,
          label: v,
          status: 'warning',
          message:
              'Blood pressure is high. Lifestyle changes come first — less salt, '
              'more walking. Recheck and talk to a doctor if it stays up.'
              '${ageNote == null ? '' : ' $ageNote'}',
        );
      case BpBand.grade2:
        return BpClassification(
          band: b,
          label: v,
          status: 'critical',
          message:
              'Blood pressure is clearly high. Please see a doctor soon.'
              '${ageNote == null ? '' : ' $ageNote'}',
        );
      case BpBand.grade3:
        return BpClassification(
          band: b,
          label: v,
          status: 'critical',
          message:
              'Blood pressure is very high. Seek medical care without delay.'
              '${ageNote == null ? '' : ' $ageNote'}',
        );
    }
  }

  /// Population / treatment context — does not change the band.
  static String? _ageSexNote(int? age, String? gender) {
    if (age == null) return null;
    final sex = (gender ?? '').toLowerCase();
    final isFemale = sex.startsWith('f') || sex.contains('woman');
    final isMale = sex.startsWith('m') || sex.contains('man');

    if (age < 18) {
      return 'Under 18, clinicians use age-, sex-, and height-based percentiles '
          'rather than adult cut-offs — confirm with a pediatric guideline.';
    }
    if (age < 40) {
      final who = isMale
          ? 'Men in this age group often run slightly higher BP than women.'
          : isFemale
              ? 'Women in this age group often run slightly lower BP than men.'
              : 'Average BP is usually lowest in early adulthood.';
      return who;
    }
    if (age < 60) {
      return 'Average systolic pressure tends to rise through midlife; '
          '120/80 remains a healthy adult target, not a disease label.';
    }
    if (age < 80) {
      final who = isFemale
          ? 'After menopause, average BP in women often catches up with or exceeds men.'
          : 'Systolic pressure commonly rises with age; guidelines still diagnose '
              'hypertension at ≥140/≥90, with individualized treatment targets.';
      return who;
    }
    return 'In adults 80+, treatment targets are often individualized '
        '(start <140/90, then lower if well tolerated) — classification of a '
        'single reading still uses the same adult bands.';
  }
}
