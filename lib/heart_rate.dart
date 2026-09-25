/// Resting heart rate / HRV / rhythm wellness bands for Ai Doc & Heart Check.
///
/// These are general adult wellness ranges, not a medical diagnosis.
/// The 60–105 bpm band is for **resting** HR only — not walking, workouts,
/// or other load. Live / activity samples use [zoneForCurrent] / walking rules.
/// Persist thresholds stay tunable via [MedicalGuidelines] constants.
library;

import 'medical_guidelines.dart';

enum HeartZone {
  /// Green — within expected range.
  normal,
  /// Yellow — mild deviation / watch closely.
  attention,
  /// Red — significant deviation / risk signal.
  risk,
}

enum HeartTrend {
  improving,
  stable,
  worsening,
  unknown,
}

class HeartRateAssessment {
  final HeartZone zone;
  final String statusKey; // normal | attention | risk
  final String primaryMetric; // resting | current | hrv | rhythm | spike
  final double? restingBpm;
  final double? currentBpm;
  final double? hrvMs;
  final double? walkingBpm;
  final bool irregularRhythm;
  final bool elevatedRestingStreak;
  final bool sharpChange;
  final HeartTrend trend;
  final int restingLow;
  final int restingHigh;

  const HeartRateAssessment({
    required this.zone,
    required this.statusKey,
    required this.primaryMetric,
    this.restingBpm,
    this.currentBpm,
    this.hrvMs,
    this.walkingBpm,
    this.irregularRhythm = false,
    this.elevatedRestingStreak = false,
    this.sharpChange = false,
    this.trend = HeartTrend.unknown,
    required this.restingLow,
    required this.restingHigh,
  });

  bool get hasAnyData =>
      restingBpm != null ||
      currentBpm != null ||
      hrvMs != null ||
      walkingBpm != null ||
      irregularRhythm;

  /// OS alarm: stably elevated ≥105, a sharp day-to-day rise, or irregular rhythm.
  bool get shouldAlarm {
    if (irregularRhythm) return true;
    if (elevatedRestingStreak || sharpChange) return true;
    if (restingBpm != null &&
        restingBpm! >= MedicalGuidelines.restingHrElevatedHigh) {
      return true;
    }
    return zone == HeartZone.risk && primaryMetric == 'resting';
  }
}

class HeartRateGuidelines {
  HeartRateGuidelines._();

  /// Age-adjusted resting HR comfort band (bpm).
  /// Base 60–105; athletes use a lower floor.
  static ({int low, int high}) restingRange({
    int? age,
    bool athlete = false,
  }) {
    var low = athlete
        ? MedicalGuidelines.restingHrAthleteMin
        : MedicalGuidelines.restingHrMin;
    var high = MedicalGuidelines.restingHrMax;
    if (age != null) {
      if (age >= 65) {
        high = MedicalGuidelines.restingHrMaxSenior;
      } else if (age < 30) {
        high = MedicalGuidelines.restingHrMaxYoung;
      }
    }
    return (low: low, high: high);
  }

  static HeartZone zoneForResting(
    double bpm, {
    int? age,
    bool athlete = false,
  }) {
    final r = restingRange(age: age, athlete: athlete);
    final high = MedicalGuidelines.restingHrElevatedHigh;
    final elevated = MedicalGuidelines.restingHrElevatedCutOff.toDouble();
    if (bpm < r.low - 10 || bpm >= high) return HeartZone.risk;
    if (bpm < r.low || bpm >= elevated) return HeartZone.attention;
    return HeartZone.normal;
  }

  /// Instant (non-resting) HR — broader band; exercise can raise pulse normally.
  /// Do **not** apply the resting 60–105 comfort range here.
  static HeartZone zoneForCurrent(double bpm) {
    if (bpm < 40 || bpm > 180) return HeartZone.risk;
    if (bpm < 50 || bpm > 160) return HeartZone.attention;
    return HeartZone.normal;
  }

  /// Higher HRV (SDNN ms) is generally better for recovery.
  /// Soft bands — individual baselines vary a lot.
  static HeartZone zoneForHrv(double sdnnMs) {
    if (sdnnMs < 20) return HeartZone.risk;
    if (sdnnMs < 40) return HeartZone.attention;
    return HeartZone.normal;
  }

  static HeartTrend trendFromRestingSeries(List<double> recentRestingOldestFirst) {
    final vals = recentRestingOldestFirst.where((v) => v > 0).toList();
    if (vals.length < 3) return HeartTrend.unknown;
    final mid = vals.length ~/ 2;
    final earlier = vals.sublist(0, mid);
    final later = vals.sublist(mid);
    final avgE = earlier.reduce((a, b) => a + b) / earlier.length;
    final avgL = later.reduce((a, b) => a + b) / later.length;
    final delta = avgL - avgE;
    if (delta <= -3) return HeartTrend.improving; // lower resting = better
    if (delta >= 3) return HeartTrend.worsening;
    return HeartTrend.stable;
  }

  /// True when resting HR stays at/above the normal max for several days.
  static bool elevatedStreak(List<double> recentRestingOldestFirst, {int days = 3}) {
    final cut = MedicalGuidelines.restingHrElevatedCutOff.toDouble();
    final tail = recentRestingOldestFirst.where((v) => v > 0).toList();
    if (tail.length < days) return false;
    final last = tail.sublist(tail.length - days);
    return last.every((v) => v >= cut);
  }

  /// True when resting HR stays at/above the elevated-high cut-off for several days.
  static bool highElevatedStreak(
    List<double> recentRestingOldestFirst, {
    int days = 3,
  }) {
    final cut = MedicalGuidelines.restingHrElevatedHigh.toDouble();
    final tail = recentRestingOldestFirst.where((v) => v > 0).toList();
    if (tail.length < days) return false;
    return tail.sublist(tail.length - days).every((v) => v >= cut);
  }

  /// Detect a sharp day-to-day *rise* in resting HR (≥ 10 bpm).
  static bool sharpDayChange(List<double> recentRestingOldestFirst) {
    final vals = recentRestingOldestFirst.where((v) => v > 0).toList();
    if (vals.length < 2) return false;
    final a = vals[vals.length - 2];
    final b = vals[vals.length - 1];
    return (b - a) >= MedicalGuidelines.restingHrSharpChangeBpm;
  }

  /// 0–100 contribution for Health Index from heart check metrics.
  /// Scores **resting** HR only (plus HRV / irregular rhythm). Daily average
  /// or exercise HR must not use the resting 60–105 band.
  /// Returns null when there is no usable heart data yet.
  static double? indexContribution({
    double? restingBpm,
    double? hrvMs,
    bool irregularRhythm = false,
    int? age,
    bool athlete = false,
  }) {
    final parts = <double>[];
    if (restingBpm != null && restingBpm > 0) {
      parts.add(_restingIndexScore(restingBpm, age: age, athlete: athlete));
    }
    if (hrvMs != null && hrvMs > 0) {
      parts.add(switch (zoneForHrv(hrvMs)) {
        HeartZone.normal => 90.0,
        HeartZone.attention => 58.0,
        HeartZone.risk => 28.0,
      });
    }
    if (irregularRhythm) {
      parts.add(38.0);
    }
    if (parts.isEmpty) return null;
    return parts.reduce((a, b) => a + b) / parts.length;
  }

  static double _restingIndexScore(
    double bpm, {
    int? age,
    bool athlete = false,
  }) {
    final r = restingRange(age: age, athlete: athlete);
    final comfortHigh = MedicalGuidelines.restingHrElevatedCutOff.toDouble();
    final riskHigh = MedicalGuidelines.restingHrElevatedHigh.toDouble();
    if (bpm >= r.low && bpm < comfortHigh) {
      final mid = (r.low + comfortHigh) / 2;
      final half = ((comfortHigh - r.low) / 2).clamp(1.0, 40.0);
      final dist = ((bpm - mid).abs() / half).clamp(0.0, 1.0);
      return 100 - dist * 12;
    }
    if (bpm < r.low) {
      final deficit = r.low - bpm;
      if (deficit <= 10) return (82 - deficit * 2.2).clamp(55, 82);
      return (48 - (deficit - 10) * 1.5).clamp(20, 48);
    }
    if (bpm < riskHigh) {
      final excess = bpm - comfortHigh;
      return (78 - excess * 1.4).clamp(48, 78);
    }
    final excess = bpm - riskHigh;
    return (42 - excess * 1.2).clamp(15, 42);
  }

  static HeartRateAssessment assess({
    double? restingBpm,
    double? currentBpm,
    double? hrvMs,
    double? walkingBpm,
    bool irregularRhythm = false,
    List<double> recentRestingOldestFirst = const [],
    int? age,
    bool athlete = false,
  }) {
    final range = restingRange(age: age, athlete: athlete);
    final streak = elevatedStreak(recentRestingOldestFirst);
    final highStreak = highElevatedStreak(recentRestingOldestFirst);
    final sharp = sharpDayChange(recentRestingOldestFirst);
    final trend = trendFromRestingSeries(recentRestingOldestFirst);

    HeartZone worst = HeartZone.normal;
    var primary = 'resting';

    void bump(HeartZone z, String metric) {
      if (z.index > worst.index) {
        worst = z;
        primary = metric;
      }
    }

    if (irregularRhythm) bump(HeartZone.risk, 'rhythm');
    if (restingBpm != null) {
      bump(zoneForResting(restingBpm, age: age, athlete: athlete), 'resting');
    }
    if (currentBpm != null) {
      bump(zoneForCurrent(currentBpm), 'current');
    }
    if (hrvMs != null) bump(zoneForHrv(hrvMs), 'hrv');
    if (highStreak) bump(HeartZone.risk, 'resting');
    if (streak) bump(HeartZone.attention, 'resting');
    if (sharp) bump(HeartZone.attention, 'spike');

    // Walking HR during activity — only flag extreme values; never use resting 105.
    if (walkingBpm != null && walkingBpm > 160) {
      bump(HeartZone.attention, 'current');
    }
    if (walkingBpm != null && walkingBpm > 180) {
      bump(HeartZone.risk, 'current');
    }

    final status = switch (worst) {
      HeartZone.normal => 'normal',
      HeartZone.attention => 'attention',
      HeartZone.risk => 'risk',
    };

    return HeartRateAssessment(
      zone: worst,
      statusKey: status,
      primaryMetric: primary,
      restingBpm: restingBpm,
      currentBpm: currentBpm,
      hrvMs: hrvMs,
      walkingBpm: walkingBpm,
      irregularRhythm: irregularRhythm,
      elevatedRestingStreak: streak,
      sharpChange: sharp,
      trend: trend,
      restingLow: range.low,
      restingHigh: range.high,
    );
  }
}
