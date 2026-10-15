import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../ecg_rhythms.dart';
import '../heart_rate_service.dart';
import '../l10n/l10n_ext.dart';
import '../l10n/medical_l10n.dart';
import '../theme.dart';
import '../widgets.dart';

/// ECG from electrode sensors (Apple Watch → Apple Health) + rhythm guide.
class EcgModal extends StatefulWidget {
  const EcgModal({super.key});

  @override
  State<EcgModal> createState() => _EcgModalState();
}

class _EcgModalState extends State<EcgModal> {
  List<EcgSummary> ecgs = const [];
  HeartRateSnapshot? snap;
  bool loading = true;
  bool refreshing = false;
  bool connecting = false;
  bool permissionHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    permissionHint = await HeartRateService.hasEcgPermissionHint();
    await _load(initial: true, requestAuthIfNeeded: !permissionHint);
  }

  Future<void> _connectSensors() async {
    setState(() => connecting = true);
    final ok = await HeartRateService.requestEcgPermission();
    if (!mounted) return;
    setState(() {
      connecting = false;
      permissionHint = ok || permissionHint;
    });
    await _load(initial: false);
  }

  Future<void> _load({
    bool initial = false,
    bool requestAuthIfNeeded = false,
  }) async {
    final userId = context.read<AuthProvider>().user!.id;
    setState(() {
      if (initial) {
        loading = true;
      } else {
        refreshing = true;
      }
    });
    try {
      if (requestAuthIfNeeded && HeartRateService.ecgSensorSupported) {
        await HeartRateService.requestEcgPermission();
        permissionHint = await HeartRateService.hasEcgPermissionHint();
      }
      List<EcgSummary> fromSensors = const [];
      if (HeartRateService.ecgSensorSupported) {
        fromSensors = await HeartRateService.fetchEcgFromSensors();
      }
      final next = await HeartRateService.syncAndLoad(
        userId,
        notifyOnRisk: false,
      );
      if (!mounted) return;
      final merged = fromSensors.isNotEmpty
          ? fromSensors
          : (next.recentEcgs);
      setState(() {
        snap = next;
        ecgs = merged;
        loading = false;
        refreshing = false;
        permissionHint = permissionHint || next.permissionGranted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sensorOk = HeartRateService.ecgSensorSupported;
    return AppModal(
      title: l10n.actionEcg,
      onClose: () => Navigator.pop(context),
      child: loading && snap == null && ecgs.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.actionEcgDesc,
                  style: TextStyle(fontSize: 13, color: C.gray500, height: 1.35),
                ),
                const SizedBox(height: 12),
                _sensorBanner(l10n, sensorOk),
                const SizedBox(height: 14),
                if (!sensorOk)
                  _unsupportedCard(l10n)
                else ...[
                  if (!permissionHint) ...[
                    _permissionCard(l10n),
                    const SizedBox(height: 14),
                  ],
                  _statusBanner(l10n),
                  const SizedBox(height: 14),
                  _recordings(l10n),
                ],
                const SizedBox(height: 16),
                Text(
                  l10n.hrDisclaimer,
                  style: TextStyle(fontSize: 11, color: C.gray400, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (sensorOk) ...[
                  if (!permissionHint)
                    FilledButton.icon(
                      onPressed: connecting ? null : _connectSensors,
                      icon: connecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sensors, size: 18),
                      label: Text(l10n.hrEcgConnectSensors),
                    ),
                  if (!permissionHint) const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: refreshing ? null : () => _load(),
                    icon: refreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(l10n.hrEcgReadSensors),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _sensorBanner(AppLocalizations l10n, bool sensorOk) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.purple100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sensors, color: C.purple600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sensorOk ? l10n.hrEcgSensorHow : l10n.hrEcgSensorAndroid,
              style: TextStyle(fontSize: 12, color: C.gray800, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unsupportedCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 12),
      child: Text(
        l10n.hrEcgSensorAndroid,
        style: TextStyle(fontSize: 13, color: C.gray600, height: 1.4),
      ),
    );
  }

  Widget _permissionCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.hrEcgNeedPermissionTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.gray900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.hrEcgNeedPermissionBody,
            style: TextStyle(fontSize: 13, color: C.gray700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(AppLocalizations l10n) {
    final latest = ecgs.isNotEmpty ? ecgs.first : null;
    if (latest != null) {
      final kind = EcgRhythmKnowledge.resolveProcessedKind(
        classification: latest.classification,
        averageBpm: latest.averageBpm,
      );
      final severity =
          EcgRhythmKnowledge.profile(kind)?.severity ?? EcgRhythmSeverity.attention;
      final risk = severity == EcgRhythmSeverity.risk;
      final attention = severity == EcgRhythmSeverity.attention;
      final bg = risk ? C.red50 : attention ? C.amber50 : C.emerald50;
      final fg = risk ? C.red700 : attention ? C.amber700 : C.emerald600;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.hrEcgResultTitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.hrEcgRhythmTitle(kind),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.hrEcgDistortionLabel(kind),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.hrEcgRhythmAdvice(kind),
              style: TextStyle(fontSize: 13, color: fg, height: 1.4),
            ),
            if (latest.averageBpm != null) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.hrEcgLatestFromSensor}: ${latest.averageBpm!.round()} ${l10n.unitBpm}',
                style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.85)),
              ),
            ],
          ],
        ),
      );
    }
    final irregular = snap?.irregularRhythm == true;
    final irregularKind = EcgRhythmKnowledge.inferFromIrregularEvents(
      irregularRhythm: irregular,
      restingBpm: snap?.restingBpm,
    );
    final kind =
        irregularKind ?? EcgRhythmKnowledge.inferFromRestingRate(snap?.restingBpm);
    if (kind == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.blue50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.hrEcgEmpty,
          style: TextStyle(fontSize: 12, color: C.blue700, height: 1.4),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.blue50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.hrEcgResultTitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: C.blue700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.hrEcgRhythmTitle(kind),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: C.blue700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.hrEcgDistortionLabel(kind),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: C.blue700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.hrEcgRhythmAdvice(kind),
            style: TextStyle(fontSize: 13, color: C.blue700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _recordings(AppLocalizations l10n) {
    final fmt = DateFormat.MMMd().add_Hm();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.hrEcgTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.gray900,
            ),
          ),
          const SizedBox(height: 8),
          if (ecgs.isEmpty)
            Text(
              l10n.hrEcgEmpty,
              style: TextStyle(fontSize: 12, color: C.gray500, height: 1.35),
            )
          else
            for (final e in ecgs)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Builder(
                  builder: (context) {
                    final kind = EcgRhythmKnowledge.resolveProcessedKind(
                      classification: e.classification,
                      averageBpm: e.averageBpm,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.monitor_heart_outlined,
                                size: 16, color: C.purple600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${fmt.format(e.at.toLocal())}'
                                '${e.averageBpm != null ? ' · ${e.averageBpm!.round()} ${l10n.unitBpm}' : ''}'
                                ' · ${l10n.hrEcgRhythmTitle(kind)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: C.gray800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.hrEcgDistortionLabel(kind),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: EcgRhythmKnowledge.hasRhythmDistortion(kind)
                                ? C.amber700
                                : C.emerald600,
                          ),
                        ),
                        if (e.waveformPreview.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _EcgWavePainter(e.waveformPreview),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          l10n.hrEcgRhythmAdvice(kind),
                          style: TextStyle(
                            fontSize: 12,
                            color: C.gray600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class _EcgWavePainter extends CustomPainter {
  final List<double> values;
  _EcgWavePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;
    var minV = values.first;
    var maxV = values.first;
    for (final v in values) {
      minV = math.min(minV, v);
      maxV = math.max(maxV, v);
    }
    final span = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1).clamp(1, 9999) * size.width;
      final y = size.height - ((values[i] - minV) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = C.purple600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EcgWavePainter oldDelegate) =>
      !listEquals(oldDelegate.values, values);
}
