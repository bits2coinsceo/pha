/// Photoplethysmography signal processing for camera-based heart rate.
///
/// Pipeline: intensity samples → detrend → bandpass (0.7–4 Hz) → peaks → BPM.
library;

import 'dart:math' as math;

class PpgSample {
  final double tSec;
  final double intensity;
  const PpgSample(this.tSec, this.intensity);
}

class PpgPeak {
  final double tSec;
  final double value;
  const PpgPeak(this.tSec, this.value);
}

class PpgAnalysis {
  final double? bpm;
  final double signalQuality; // 0..1
  final bool fingerPresent;
  final List<double> waveform; // recent filtered values for UI
  final List<PpgPeak> recentPeaks;
  final List<double> rrMs; // inter-peak intervals for labels

  const PpgAnalysis({
    required this.bpm,
    required this.signalQuality,
    required this.fingerPresent,
    required this.waveform,
    required this.recentPeaks,
    required this.rrMs,
  });
}

/// Incremental PPG analyzer. Feed one intensity sample per camera frame.
class PpgAnalyzer {
  PpgAnalyzer({
    this.targetFps = 30,
    this.minBpm = 42,
    this.maxBpm = 180,
    this.waveformWindow = 150,
  });

  final double targetFps;
  final double minBpm;
  final double maxBpm;
  final int waveformWindow;

  final List<PpgSample> _raw = [];
  final List<double> _filtered = [];
  final List<double> _t = [];
  final List<PpgPeak> _peaks = [];
  final List<double> _bpmHistory = [];

  double? _lastPeakT;
  double _emaMean = 0;
  bool _emaReady = false;

  /// Band edges in Hz.
  static const _lowHz = 0.7;
  static const _highHz = 4.0;

  void reset() {
    _raw.clear();
    _filtered.clear();
    _t.clear();
    _peaks.clear();
    _bpmHistory.clear();
    _lastPeakT = null;
    _emaMean = 0;
    _emaReady = false;
  }

  PpgAnalysis push(double intensity, double tSec) {
    _raw.add(PpgSample(tSec, intensity));
    // Keep ~25s of raw for quality / export.
    while (_raw.length > targetFps * 25) {
      _raw.removeAt(0);
    }

    final finger = _fingerPresent(intensity);
    final detrended = _detrend(intensity);
    final filtered = _bandpassStep(detrended, tSec);
    _t.add(tSec);
    _filtered.add(filtered);
    while (_filtered.length > waveformWindow) {
      _filtered.removeAt(0);
      _t.removeAt(0);
    }

    if (finger && _filtered.length >= 8) {
      _detectPeak(tSec, filtered);
    }

    final bpm = _computeBpm();
    final quality = _quality(finger, intensity);

    final rr = <double>[];
    for (var i = 1; i < _peaks.length; i++) {
      rr.add((_peaks[i].tSec - _peaks[i - 1].tSec) * 1000);
    }

    return PpgAnalysis(
      bpm: bpm,
      signalQuality: quality,
      fingerPresent: finger,
      waveform: List<double>.from(_filtered),
      recentPeaks: List<PpgPeak>.from(
        _peaks.length <= 8 ? _peaks : _peaks.sublist(_peaks.length - 8),
      ),
      rrMs: rr.length <= 6 ? rr : rr.sublist(rr.length - 6),
    );
  }

  /// Raw intensity series for debug export.
  List<PpgSample> get rawSamples => List.unmodifiable(_raw);

  bool _fingerPresent(double intensity) {
    // Torch + fingertip typically saturates red/green into a mid-high band.
    // Too dark = no finger / torch off; too bright = flash bounce / no cover.
    if (intensity < 28 || intensity > 245) return false;
    if (_raw.length < 12) return intensity > 40 && intensity < 240;
    final recent = _raw.sublist(_raw.length - 12);
    final mean =
        recent.fold<double>(0, (a, s) => a + s.intensity) / recent.length;
    final varSum = recent.fold<double>(
      0,
      (a, s) => a + math.pow(s.intensity - mean, 2),
    );
    final std = math.sqrt(varSum / recent.length);
    // Finger covering lens: moderate mean, small-to-medium pulsatile variance.
    return mean > 35 && mean < 235 && std > 0.15 && std < 45;
  }

  double _detrend(double x) {
    // Exponential moving average removes slow DC drift.
    const alpha = 0.02;
    if (!_emaReady) {
      _emaMean = x;
      _emaReady = true;
      return 0;
    }
    _emaMean = (1 - alpha) * _emaMean + alpha * x;
    return x - _emaMean;
  }

  /// One-pole low/high cascade approximating 0.7–4 Hz at ~30 fps.
  double _prevHp = 0;
  double _prevHpOut = 0;
  double _prevLp = 0;

  double _bandpassStep(double x, double tSec) {
    final dt = _t.isEmpty ? (1 / targetFps) : (tSec - _t.last).clamp(0.01, 0.1);
    final rcHp = 1 / (2 * math.pi * _lowHz);
    final alphaHp = rcHp / (rcHp + dt);
    final hp = alphaHp * (_prevHpOut + x - _prevHp);
    _prevHp = x;
    _prevHpOut = hp;

    final rcLp = 1 / (2 * math.pi * _highHz);
    final alphaLp = dt / (rcLp + dt);
    final lp = _prevLp + alphaLp * (hp - _prevLp);
    _prevLp = lp;
    return lp;
  }

  void _detectPeak(double tSec, double value) {
    if (_filtered.length < 3) return;
    final a = _filtered[_filtered.length - 3];
    final b = _filtered[_filtered.length - 2];
    final c = _filtered[_filtered.length - 1];
    final peakT = _t[_t.length - 2];
    final minInterval = 60.0 / maxBpm; // ~0.33s at 180
    if (b > a && b > c && b > 0.05) {
      if (_lastPeakT != null && peakT - _lastPeakT! < minInterval) {
        return;
      }
      // Amplitude gate vs recent noise floor.
      final window = _filtered.length > 30
          ? _filtered.sublist(_filtered.length - 30)
          : _filtered;
      final absMean =
          window.fold<double>(0, (s, v) => s + v.abs()) / window.length;
      if (b < absMean * 0.6) return;

      _lastPeakT = peakT;
      _peaks.add(PpgPeak(peakT, b));
      while (_peaks.length > 40) {
        _peaks.removeAt(0);
      }
      // Keep unused [value]/tSec for API symmetry / future scoring.
      // ignore: unused_local_variable
      final _ = (value, tSec);
    }
  }

  double? _computeBpm() {
    if (_peaks.length < 3) return null;
    final recent = _peaks.length <= 8
        ? _peaks
        : _peaks.sublist(_peaks.length - 8);
    final intervals = <double>[];
    for (var i = 1; i < recent.length; i++) {
      final dt = recent[i].tSec - recent[i - 1].tSec;
      final bpm = 60 / dt;
      if (bpm >= minBpm && bpm <= maxBpm) intervals.add(dt);
    }
    if (intervals.length < 2) return null;
    intervals.sort();
    // Trim outliers: use median-centered intervals.
    final mid = intervals[intervals.length ~/ 2];
    final kept = intervals
        .where((d) => (d - mid).abs() / mid < 0.35)
        .toList();
    if (kept.isEmpty) return null;
    final meanDt = kept.fold<double>(0, (a, b) => a + b) / kept.length;
    final bpm = 60 / meanDt;
    _bpmHistory.add(bpm);
    while (_bpmHistory.length > 7) {
      _bpmHistory.removeAt(0);
    }
    final smoothed =
        _bpmHistory.fold<double>(0, (a, b) => a + b) / _bpmHistory.length;
    return smoothed.clamp(minBpm, maxBpm);
  }

  double _quality(bool finger, double intensity) {
    if (!finger) return 0;
    if (_peaks.length < 2) {
      return intensity > 40 && intensity < 240 ? 0.25 : 0.1;
    }
    final recent = _peaks.length <= 6
        ? _peaks
        : _peaks.sublist(_peaks.length - 6);
    final rr = <double>[];
    for (var i = 1; i < recent.length; i++) {
      rr.add(recent[i].tSec - recent[i - 1].tSec);
    }
    if (rr.isEmpty) return 0.3;
    final mean = rr.fold<double>(0, (a, b) => a + b) / rr.length;
    final varSum = rr.fold<double>(0, (a, b) => a + math.pow(b - mean, 2));
    final cv = math.sqrt(varSum / rr.length) / mean;
    // Lower coefficient of variation → higher quality.
    final q = (1.0 - cv.clamp(0.0, 1.0)).clamp(0.0, 1.0);
    return (0.35 + 0.65 * q);
  }
}
