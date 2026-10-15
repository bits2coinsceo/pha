import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../daily_metric_store.dart';
import '../db.dart';
import '../l10n/l10n_ext.dart';
import '../ppg/ppg_camera_service.dart';

export '../ppg/ppg_camera_service.dart' show PpgMeasureResult;

/// Full-screen camera PPG measurement (torch + fingertip).
class PpgCameraModal extends StatefulWidget {
  const PpgCameraModal({super.key});

  @override
  State<PpgCameraModal> createState() => _PpgCameraModalState();
}

class _PpgCameraModalState extends State<PpgCameraModal>
    with TickerProviderStateMixin {
  late final PpgCameraService _service;
  StreamSubscription<PpgSessionState>? _sub;
  PpgSessionState _state =
      const PpgSessionState(phase: PpgSessionPhase.requestingPermission);

  late final AnimationController _pulse;
  late final AnimationController _facts;
  int _factIndex = 0;
  Timer? _factTimer;
  bool _saving = false;
  String? _saveMsg;

  @override
  void initState() {
    super.initState();
    _service = PpgCameraService();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _facts = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _sub = _service.states.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      final bpm = s.analysis?.bpm;
      if (bpm != null && bpm > 0) {
        final ms = (60000 / bpm.clamp(45, 160)).round();
        final next = Duration(milliseconds: ms);
        if (_pulse.duration != next) {
          _pulse
            ..duration = next
            ..reset()
            ..repeat();
        }
      }
      if (s.phase == PpgSessionPhase.measuring &&
          s.analysis?.fingerPresent == true) {
        _ensureFacts();
      }
    });
    unawaited(_service.prepare());
  }

  void _ensureFacts() {
    _factTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _factIndex++;
        _facts
          ..reset()
          ..forward();
      });
    });
    if (!_facts.isAnimating && _facts.value == 0) {
      unawaited(_facts.forward());
    }
  }

  @override
  void dispose() {
    _factTimer?.cancel();
    unawaited(_sub?.cancel() ?? Future.value());
    unawaited(_service.dispose());
    _pulse.dispose();
    _facts.dispose();
    super.dispose();
  }

  List<String> _factLines(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.ppgFact1,
      l10n.ppgFact2,
      l10n.ppgFact3,
      l10n.ppgFact4,
      l10n.ppgFact5,
      l10n.ppgFact6,
      l10n.ppgFact7,
      l10n.ppgFact8,
    ];
  }

  Future<void> _toggle() async {
    if (_state.phase == PpgSessionPhase.measuring) {
      await _service.stop();
      return;
    }
    if (_state.phase == PpgSessionPhase.completed ||
        _state.phase == PpgSessionPhase.failed) {
      setState(() {
        _saveMsg = null;
        _factIndex = 0;
      });
    }
    await _service.startMeasurement();
  }

  Future<bool> _persistResult() async {
    final bpm = _state.finalBpm;
    if (bpm == null) return false;
    final user = context.read<AuthProvider>().user;
    if (user == null) return false;
    setState(() {
      _saving = true;
      _saveMsg = null;
    });
    try {
      final now = DateTime.now().toUtc();
      await Db.instance.raw.insert('health_metrics', {
        'id': const Uuid().v4(),
        'user_id': user.id,
        'metric_type': 'heart_rate',
        'value': bpm.roundToDouble(),
        'recorded_at': now.toIso8601String(),
        'notes': 'camera_ppg',
        'source': 'camera_ppg',
        'created_at': now.toIso8601String(),
      });
      await DailyMetricStore.upsertToday(
        userId: user.id,
        metricType: 'resting_heart_rate',
        value: bpm.roundToDouble(),
        source: 'camera_ppg',
        notes: 'camera_ppg',
      );
      if (!mounted) return true;
      setState(() => _saveMsg = context.l10n.ppgSaved);
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _saveMsg = context.l10n.ppgSaveFailed);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exitAndAnalyze() async {
    final bpm = _state.finalBpm;
    if (bpm == null || _saving) return;
    final ok = await _persistResult();
    if (!mounted) return;
    if (!ok) return;
    final quality = _state.analysis?.signalQuality ?? 0;
    Navigator.pop(
      context,
      PpgMeasureResult(bpm: bpm, quality: quality),
    );
  }

  Future<void> _exportRaw() async {
    final samples = _state.rawExport;
    final bpm = _state.finalBpm ?? _state.analysis?.bpm;
    final buf = StringBuffer()
      ..writeln(context.l10n.ppgExportTitle)
      ..writeln('BPM: ${bpm?.toStringAsFixed(0) ?? '—'}')
      ..writeln(
          'quality: ${_state.analysis?.signalQuality.toStringAsFixed(2) ?? '—'}')
      ..writeln('t_sec,intensity');
    for (final s in samples) {
      buf.writeln(
          '${s.tSec.toStringAsFixed(3)},${s.intensity.toStringAsFixed(3)}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    setState(() => _saveMsg = context.l10n.ppgExportCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final measuring = _state.phase == PpgSessionPhase.measuring;
    final finger = _state.analysis?.fingerPresent == true;
    final bpm = measuring
        ? _state.analysis?.bpm
        : (_state.finalBpm ?? _state.analysis?.bpm);
    final showPreview = _state.phase == PpgSessionPhase.instructing ||
        (_state.phase == PpgSessionPhase.measuring && !finger);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0000),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BackgroundGlow(
              active: finger || _state.phase == PpgSessionPhase.completed,
              pulse: _pulse,
            ),
            if (showPreview) _dimmedCameraBackdrop(_service.controller),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                        ),
                        Expanded(
                          child: Text(
                            l10n.ppgTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: switch (_state.phase) {
                      PpgSessionPhase.requestingPermission =>
                        _centeredMessage(l10n.ppgPreparing),
                      PpgSessionPhase.failed => _errorBody(l10n),
                      PpgSessionPhase.completed => _resultBody(l10n, bpm),
                      PpgSessionPhase.instructing ||
                      PpgSessionPhase.idle =>
                        _instructBody(l10n, finger: finger),
                      PpgSessionPhase.measuring => finger
                          ? _measureBody(l10n, bpm)
                          : _instructBody(
                              l10n,
                              finger: finger,
                              waiting: true,
                            ),
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      children: [
                        if (_saveMsg != null) ...[
                          Text(
                            _saveMsg!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          l10n.ppgDisclaimer,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_state.phase == PpgSessionPhase.completed)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  _saving || bpm == null ? null : _exitAndAnalyze,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                _saving
                                    ? l10n.ppgSaving
                                    : l10n.ppgExitAndAnalyze,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        else if (measuring)
                          // Measurement auto-starts on stable finger cover —
                          // only allow stop while running.
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _toggle,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                l10n.ppgStop,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimmedCameraBackdrop(CameraController? ctrl) {
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.22,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: ctrl.value.previewSize?.height ?? 1,
              height: ctrl.value.previewSize?.width ?? 1,
              child: CameraPreview(ctrl),
            ),
          ),
        ),
      ),
    );
  }

  Widget _centeredMessage(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style:
            TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15),
      ),
    );
  }

  Widget _errorBody(AppLocalizations l10n) {
    final msg = switch (_state.error) {
      'permission' => l10n.ppgNeedPermission,
      'no_camera' => l10n.ppgNoCamera,
      'no_torch' => l10n.ppgNoTorch,
      _ => l10n.ppgCameraError,
    };
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_outlined,
              color: Colors.white54, size: 48),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => _service.prepare(),
            child: Text(l10n.ppgRetry),
          ),
        ],
      ),
    );
  }

  Widget _instructBody(
    AppLocalizations l10n, {
    required bool finger,
    bool waiting = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiting ? l10n.ppgHoldFinger : l10n.ppgPlaceFinger,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.ppgCoverBothHint,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _StatusCircle(
                red: finger,
                pulse: _pulse,
                controller: _service.controller,
              ),
            ],
          ),
          const Spacer(),
          // Reference illustration: left hand holds phone, right index covers
          // camera/flash with torch glow — readable unlike abstract line art.
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = math.min(300.0, w * 1.05);
              final active = waiting || finger;
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: active ? 1 : 0.92,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Image.asset(
                    'assets/ppg/finger_instruction.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              );
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _measureBody(AppLocalizations l10n, double? bpm) {
    final analysis = _state.analysis;
    final facts = _factLines(context);
    final fact = facts[_factIndex % facts.length];
    final next = facts[(_factIndex + 1) % facts.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(right: 100, left: 8, top: 24),
                    child: _PpgWaveform(
                      values: analysis?.waveform ?? const [],
                      rrMs: analysis?.rrMs ?? const [],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 16,
                  child: _BpmRing(
                    bpm: bpm,
                    progress: _state.progress,
                    pulse: _pulse,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _state.progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white12,
            color: const Color(0xFFFF6B8A),
            minHeight: 3,
          ),
          const SizedBox(height: 28),
          Text(
            l10n.ppgTipsHeader,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: Tween(begin: 0.4, end: 1.0).animate(_facts),
                child: Column(
                  children: [
                    Text(
                      fact,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      next,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            l10n.ppgHoldStill,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _resultBody(AppLocalizations l10n, double? bpm) {
    final q = _state.analysis?.signalQuality ?? 0;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Spacer(),
          _BpmRing(bpm: bpm, progress: 1, pulse: _pulse, large: true),
          const SizedBox(height: 20),
          Text(
            l10n.ppgResultTitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.ppgQuality((q * 100).round()),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _toggle,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(l10n.ppgRetry),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _state.rawExport.isEmpty ? null : _exportRaw,
            child: Text(
              l10n.ppgExportRaw,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({required this.active, required this.pulse});
  final bool active;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t =
            active ? (0.55 + 0.25 * math.sin(pulse.value * math.pi * 2)) : 0.25;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.55, -0.55),
              radius: 1.15,
              colors: [
                Color.lerp(const Color(0xFF4A0010), const Color(0xFFB01030), t)!,
                const Color(0xFF1A0008),
                const Color(0xFF050000),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        );
      },
    );
  }
}

class _StatusCircle extends StatelessWidget {
  const _StatusCircle({
    required this.red,
    required this.pulse,
    this.controller,
  });
  final bool red;
  final Animation<double> pulse;
  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    final hasPreview = ctrl != null && ctrl.value.isInitialized;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = red ? 12 + 8 * math.sin(pulse.value * math.pi * 2) : 0.0;
        return Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: red ? const Color(0xFFE11D48) : Colors.black,
            border: Border.all(
              color: red ? const Color(0xFFFF6B8A) : Colors.white54,
              width: 2,
            ),
            boxShadow: red
                ? [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.55),
                      blurRadius: glow,
                      spreadRadius: glow * 0.2,
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: red || !hasPreview
              ? null
              : FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: ctrl.value.previewSize?.height ?? 88,
                    height: ctrl.value.previewSize?.width ?? 88,
                    child: CameraPreview(ctrl),
                  ),
                ),
        );
      },
    );
  }
}

class _BpmRing extends StatelessWidget {
  const _BpmRing({
    required this.bpm,
    required this.progress,
    required this.pulse,
    this.large = false,
  });
  final double? bpm;
  final double progress;
  final Animation<double> pulse;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 160.0 : 112.0;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final scale = 1 + 0.04 * math.sin(pulse.value * math.pi * 2);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 3; i >= 1; i--)
                Transform.scale(
                  scale: scale + i * 0.12,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08 / i),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 3,
                  backgroundColor: Colors.white12,
                  color: Colors.white,
                ),
              ),
              Container(
                width: size - 18,
                height: size - 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE11D48),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x99E11D48),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite,
                        color: Colors.white, size: large ? 28 : 20),
                    Text(
                      bpm == null ? '—' : bpm!.round().toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: large ? 44 : 32,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PpgWaveform extends StatelessWidget {
  const _PpgWaveform({
    required this.values,
    required this.rrMs,
  });
  final List<double> values;
  final List<double> rrMs;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WavePainter(values: values, rrMs: rrMs),
      size: Size.infinite,
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.values, required this.rrMs});
  final List<double> values;
  final List<double> rrMs;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      final p = Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, size.height * 0.55),
        Offset(size.width, size.height * 0.55),
        p,
      );
      return;
    }
    var minV = values.first;
    var maxV = values.first;
    for (final v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final span = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height * (0.75 - 0.55 * ((values[i] - minV) / span));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    if (rrMs.isNotEmpty) {
      final tp = TextPainter(textDirection: ui.TextDirection.ltr);
      final start = values.length - math.min(values.length, rrMs.length * 12);
      for (var i = 0; i < rrMs.length; i++) {
        final idx =
            (start + ((i + 1) * (values.length - start) / (rrMs.length + 1)))
                .round()
                .clamp(0, values.length - 1);
        final x = idx / (values.length - 1) * size.width;
        final y = size.height * (0.75 - 0.55 * ((values[idx] - minV) / span));
        tp.text = TextSpan(
          text: rrMs[i].round().toString(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y - 18));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.rrMs != rrMs;
}
