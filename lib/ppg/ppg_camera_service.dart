import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../core/app_logger.dart';
import 'ppg_signal.dart';

enum PpgSessionPhase {
  idle,
  requestingPermission,
  instructing,
  measuring,
  completed,
  failed,
}

/// Result returned when the user exits to analyze a completed reading.
class PpgMeasureResult {
  final double bpm;
  final double quality;

  const PpgMeasureResult({
    required this.bpm,
    required this.quality,
  });
}

class PpgSessionState {
  final PpgSessionPhase phase;
  final PpgAnalysis? analysis;
  final double progress; // 0..1
  final double? finalBpm;
  final String? error;
  final bool torchOn;
  final List<PpgSample> rawExport;

  const PpgSessionState({
    required this.phase,
    this.analysis,
    this.progress = 0,
    this.finalBpm,
    this.error,
    this.torchOn = false,
    this.rawExport = const [],
  });

  PpgSessionState copyWith({
    PpgSessionPhase? phase,
    PpgAnalysis? analysis,
    double? progress,
    double? finalBpm,
    String? error,
    bool? torchOn,
    List<PpgSample>? rawExport,
    bool clearError = false,
    bool clearAnalysis = false,
    bool clearFinalBpm = false,
  }) {
    return PpgSessionState(
      phase: phase ?? this.phase,
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      progress: progress ?? this.progress,
      finalBpm: clearFinalBpm ? null : (finalBpm ?? this.finalBpm),
      error: clearError ? null : (error ?? this.error),
      torchOn: torchOn ?? this.torchOn,
      rawExport: rawExport ?? this.rawExport,
    );
  }
}

class _RoiStats {
  final double intensity;
  final double redShare;
  final double meanR;
  final double meanG;
  final double meanB;
  /// 0..1 — how uniform the ROI is (1 = flat tissue glow).
  final double uniformity;

  const _RoiStats({
    required this.intensity,
    required this.redShare,
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.uniformity,
  });

  /// Strict fingertip + torch cover: deep uniform crimson, not a room scene.
  bool get fingerCovered {
    // Open room / no cover is usually mid-range mixed RGB; torch bounce is
    // near-white; true cover is saturated red with low blue.
    if (intensity < 55 || intensity > 210) return false;
    if (redShare < 0.52) return false;
    if (meanR < 70) return false;
    if (meanB > meanR * 0.55) return false;
    if (meanR < meanG * 1.15) return false;
    // Room scenes / partial cover have high spatial variance.
    if (uniformity < 0.72) return false;
    // Near-white flash leak: all channels high and close.
    if (intensity > 185 && (meanR - meanG).abs() < 22 && meanB > 80) {
      return false;
    }
    return true;
  }
}

/// Owns the rear camera, torch, and PPG analyzer for one measurement session.
class PpgCameraService {
  PpgCameraService({
    this.measureSeconds = 18,
    this.minMeasureSeconds = 10,
    /// Consecutive covered frames before UI turns red (~0.5s at 30 fps).
    this.coverConfirmFrames = 14,
    /// Extra hold after red before auto-start (~0.7s).
    this.autoStartHold = const Duration(milliseconds: 700),
  });

  final int measureSeconds;
  final int minMeasureSeconds;
  final int coverConfirmFrames;
  final Duration autoStartHold;

  CameraController? _controller;
  final PpgAnalyzer _analyzer = PpgAnalyzer();
  final _states = StreamController<PpgSessionState>.broadcast();
  PpgSessionState _state = const PpgSessionState(phase: PpgSessionPhase.idle);

  DateTime? _fingerLockedAt;
  DateTime? _coverConfirmedAt;
  int _coverStreak = 0;
  int _uncoverStreak = 0;
  bool _stableCover = false;
  bool _processing = false;
  bool _streaming = false;
  bool _autoStarting = false;
  final Stopwatch _clock = Stopwatch();

  Stream<PpgSessionState> get states => _states.stream;
  PpgSessionState get state => _state;
  CameraController? get controller => _controller;

  Future<void> prepare() async {
    _emit(_state.copyWith(
      phase: PpgSessionPhase.requestingPermission,
      clearError: true,
      clearAnalysis: true,
      clearFinalBpm: true,
      progress: 0,
      torchOn: false,
    ));
    try {
      final cameras = await availableCameras();
      final back = cameras.cast<CameraDescription?>().firstWhere(
            (c) => c?.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.isEmpty ? null : cameras.first,
          );
      if (back == null) {
        _fail('no_camera');
        return;
      }
      await _controller?.dispose();
      final ctrl = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      _controller = ctrl;
      _resetCoverGate();
      _analyzer.reset();
      _fingerLockedAt = null;
      _clock
        ..reset()
        ..start();
      _emit(_state.copyWith(
        phase: PpgSessionPhase.instructing,
        clearError: true,
      ));
      await _ensureTorchAndStream();
    } on CameraException catch (e, st) {
      AppLogger.e('PPG camera init failed',
          error: e, stackTrace: st, category: LogCategory.health);
      _fail(e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccessDeniedWithoutPrompt'
          ? 'permission'
          : 'camera_error');
    } catch (e, st) {
      AppLogger.e('PPG prepare failed',
          error: e, stackTrace: st, category: LogCategory.health);
      _fail('camera_error');
    }
  }

  void _resetCoverGate() {
    _coverStreak = 0;
    _uncoverStreak = 0;
    _stableCover = false;
    _coverConfirmedAt = null;
    _autoStarting = false;
  }

  Future<void> _ensureTorchAndStream() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    try {
      await c.setFlashMode(FlashMode.torch);
      _emit(_state.copyWith(torchOn: true));
    } catch (e, st) {
      AppLogger.w('Torch unavailable',
          error: e, stackTrace: st, category: LogCategory.health);
      _emit(_state.copyWith(error: 'no_torch', torchOn: false));
    }

    if (_streaming) return;
    _streaming = true;
    if (!_clock.isRunning) {
      _clock
        ..reset()
        ..start();
    }
    await c.startImageStream(_onFrame);
  }

  Future<void> startMeasurement() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      await prepare();
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    _analyzer.reset();
    _fingerLockedAt = null;
    _autoStarting = false;
    // Keep stable cover so measurement UI does not flicker back to instruct.
    _clock
      ..reset()
      ..start();
    _emit(_state.copyWith(
      phase: PpgSessionPhase.measuring,
      progress: 0,
      clearFinalBpm: true,
      clearAnalysis: true,
      clearError: true,
      rawExport: const [],
    ));

    await _ensureTorchAndStream();
  }

  Future<void> stop({bool completed = false}) async {
    final ctrl = _controller;

    if (completed) {
      if (_streaming && ctrl != null) {
        try {
          await ctrl.stopImageStream();
        } catch (_) {}
        _streaming = false;
      }
      try {
        await ctrl?.setFlashMode(FlashMode.off);
      } catch (_) {}
      _clock.stop();
      _resetCoverGate();
      final bpm = _state.analysis?.bpm;
      _emit(_state.copyWith(
        phase: PpgSessionPhase.completed,
        finalBpm: bpm,
        progress: 1,
        torchOn: false,
        rawExport: _analyzer.rawSamples,
      ));
      return;
    }

    if (_state.phase == PpgSessionPhase.measuring) {
      _analyzer.reset();
      _fingerLockedAt = null;
      _resetCoverGate();
      _emit(_state.copyWith(
        phase: PpgSessionPhase.instructing,
        progress: 0,
        clearFinalBpm: true,
        clearError: true,
        clearAnalysis: true,
      ));
      await _ensureTorchAndStream();
      return;
    }

    if (_streaming && ctrl != null) {
      try {
        await ctrl.stopImageStream();
      } catch (_) {}
      _streaming = false;
    }
    try {
      await ctrl?.setFlashMode(FlashMode.off);
    } catch (_) {}
    _clock.stop();
    _emit(_state.copyWith(torchOn: false));
  }

  Future<void> dispose() async {
    await stop();
    await _controller?.dispose();
    _controller = null;
    await _states.close();
  }

  /// Debounced cover: needs many consecutive true frames; drops quickly.
  bool _updateCoverGate(bool rawCovered) {
    if (rawCovered) {
      _coverStreak++;
      _uncoverStreak = 0;
      if (!_stableCover && _coverStreak >= coverConfirmFrames) {
        _stableCover = true;
        _coverConfirmedAt = DateTime.now();
      }
    } else {
      _uncoverStreak++;
      _coverStreak = 0;
      // Drop red quickly so a brief red flash cannot stick.
      if (_uncoverStreak >= 4) {
        _stableCover = false;
        _coverConfirmedAt = null;
      }
    }
    return _stableCover;
  }

  void _onFrame(CameraImage image) {
    final phase = _state.phase;
    if (_processing ||
        (phase != PpgSessionPhase.measuring &&
            phase != PpgSessionPhase.instructing)) {
      return;
    }
    _processing = true;
    try {
      final stats = _roiStats(image);
      final covered = _updateCoverGate(stats.fingerCovered);
      final tSec = _clock.elapsedMilliseconds / 1000.0;

      if (phase == PpgSessionPhase.instructing) {
        _emit(_state.copyWith(
          analysis: PpgAnalysis(
            bpm: null,
            signalQuality: covered ? 0.35 : 0,
            fingerPresent: covered,
            waveform: const [],
            recentPeaks: const [],
            rrMs: const [],
          ),
          clearError: covered,
          error: covered ? null : 'no_finger',
        ));

        // Auto-start once cover is stable long enough for a readable signal.
        if (covered &&
            !_autoStarting &&
            _coverConfirmedAt != null &&
            DateTime.now().difference(_coverConfirmedAt!) >= autoStartHold) {
          _autoStarting = true;
          unawaited(startMeasurement());
        }
        return;
      }

      final analysis = _analyzer.push(stats.intensity, tSec);
      final finger = covered &&
          (analysis.fingerPresent || _analyzer.rawSamples.length < 18);
      final effective = PpgAnalysis(
        bpm: finger ? analysis.bpm : null,
        signalQuality: finger ? analysis.signalQuality : 0,
        fingerPresent: finger,
        waveform: analysis.waveform,
        recentPeaks: analysis.recentPeaks,
        rrMs: analysis.rrMs,
      );

      if (effective.fingerPresent) {
        _fingerLockedAt ??= DateTime.now();
      } else {
        _fingerLockedAt = null;
      }

      final measureElapsed = _fingerLockedAt == null
          ? 0.0
          : DateTime.now().difference(_fingerLockedAt!).inMilliseconds / 1000.0;
      final progress = (measureElapsed / measureSeconds).clamp(0.0, 1.0);

      _emit(_state.copyWith(
        analysis: effective,
        progress: progress,
        clearError: effective.fingerPresent,
        error: effective.fingerPresent ? null : 'no_finger',
      ));

      final ready = effective.fingerPresent &&
          effective.bpm != null &&
          effective.signalQuality >= 0.45 &&
          measureElapsed >= minMeasureSeconds;
      final timedOut =
          measureElapsed >= measureSeconds && effective.bpm != null;

      if ((ready && progress >= 1.0) || timedOut) {
        unawaited(stop(completed: true));
      }
    } finally {
      _processing = false;
    }
  }

  static _RoiStats _roiStats(CameraImage image) {
    final w = image.width;
    final h = image.height;
    // Smaller central ROI — fingertip cover fills the center when placed well.
    final roiW = (w * 0.28).round().clamp(8, w);
    final roiH = (h * 0.28).round().clamp(8, h);
    final x0 = ((w - roiW) / 2).round();
    final y0 = ((h - roiH) / 2).round();

    if (image.format.group == ImageFormatGroup.bgra8888 ||
        image.planes.length == 1) {
      final plane = image.planes.first;
      final bytes = plane.bytes;
      final stride = plane.bytesPerRow;
      final pixelStride = plane.bytesPerPixel ?? 4;
      var sumI = 0.0;
      var sumR = 0.0;
      var sumG = 0.0;
      var sumB = 0.0;
      var sumSq = 0.0;
      var n = 0;
      for (var y = y0; y < y0 + roiH; y += 2) {
        final row = y * stride;
        for (var x = x0; x < x0 + roiW; x += 2) {
          final i = row + x * pixelStride;
          if (i + 2 >= bytes.length) continue;
          final b = bytes[i].toDouble();
          final g = bytes[i + 1].toDouble();
          final r = bytes[i + 2].toDouble();
          final intensity = r * 0.65 + g * 0.35;
          sumR += r;
          sumG += g;
          sumB += b;
          sumI += intensity;
          sumSq += intensity * intensity;
          n++;
        }
      }
      if (n == 0) {
        return const _RoiStats(
          intensity: 0,
          redShare: 0,
          meanR: 0,
          meanG: 0,
          meanB: 0,
          uniformity: 0,
        );
      }
      final meanR = sumR / n;
      final meanG = sumG / n;
      final meanB = sumB / n;
      final meanI = sumI / n;
      final total = meanR + meanG + meanB;
      final variance = (sumSq / n) - (meanI * meanI);
      final std = math.sqrt(variance < 0 ? 0 : variance);
      // Finger tissue glow is flat; std often < 25. Map to 0..1.
      final uniformity = (1.0 - (std / 55.0)).clamp(0.0, 1.0);
      return _RoiStats(
        intensity: meanI,
        redShare: total <= 0 ? 0 : meanR / total,
        meanR: meanR,
        meanG: meanG,
        meanB: meanB,
        uniformity: uniformity,
      );
    }

    // YUV fallback — do not treat as covered (no reliable red channel).
    return const _RoiStats(
      intensity: 0,
      redShare: 0,
      meanR: 0,
      meanG: 0,
      meanB: 0,
      uniformity: 0,
    );
  }

  void _fail(String code) {
    _emit(_state.copyWith(phase: PpgSessionPhase.failed, error: code));
  }

  void _emit(PpgSessionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}

/// Isolate-friendly intensity helper (kept for future off-main processing).
double ppgIntensityFromRgba(Uint8List rgba, int width, int height) {
  final roiW = math.max(8, (width * 0.35).round());
  final roiH = math.max(8, (height * 0.35).round());
  final x0 = ((width - roiW) / 2).round();
  final y0 = ((height - roiH) / 2).round();
  var sum = 0.0;
  var n = 0;
  for (var y = y0; y < y0 + roiH; y += 2) {
    for (var x = x0; x < x0 + roiW; x += 2) {
      final i = (y * width + x) * 4;
      if (i + 2 >= rgba.length) continue;
      sum += rgba[i] * 0.35 + rgba[i + 2] * 0.65; // G/R if RGBA
      n++;
    }
  }
  return n == 0 ? 0 : sum / n;
}
