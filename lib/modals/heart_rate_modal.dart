import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../db.dart';
import '../heart_rate.dart';
import '../heart_rate_service.dart';
import '../l10n/l10n_ext.dart';
import '../l10n/medical_l10n.dart';
import '../live_heart_rate.dart';
import '../theme.dart';
import '../widgets.dart';

/// Quick Action: Heart Rate & Rhythm — reads Apple Watch / HealthKit data.
class HeartRateModal extends StatefulWidget {
  const HeartRateModal({super.key});

  @override
  State<HeartRateModal> createState() => _HeartRateModalState();
}

class _HeartRateModalState extends State<HeartRateModal>
    with SingleTickerProviderStateMixin {
  HeartRateSnapshot? snap;
  bool loading = true;
  bool refreshing = false;
  String chartRange = '24h'; // 24h | 7d | 30d
  String? toast;

  /// Live BPM overlay (HealthKit push + 1 Hz poll while the sheet is open).
  double? _liveBpm;
  DateTime? _liveAt;
  Timer? _liveTimer;
  Timer? _ageTicker;
  StreamSubscription<HeartSample>? _liveSub;
  bool _livePolling = false;
  bool _liveActive = false;
  int _liveTick = 0;
  int? _age;
  bool _athlete = false;

  late final AnimationController _beat;

  /// Current BPM is hidden (and the heart stops) after this age.
  static const _freshWindow = Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
    _beat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 833), // ~72 bpm default
    )..repeat();
    _load(initial: true);
    // Start live HealthKit observation immediately — do not wait for full sync.
    _startLivePolling();
  }

  @override
  void dispose() {
    _liveActive = false;
    _liveTimer?.cancel();
    _ageTicker?.cancel();
    final sub = _liveSub;
    _liveSub = null;
    if (sub != null) unawaited(sub.cancel());
    unawaited(LiveHeartRate.stop());
    _beat.dispose();
    super.dispose();
  }

  DateTime? get _sampleAt => _liveAt ?? snap?.latestAt;

  bool get _hasFreshSample {
    final at = _sampleAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _freshWindow;
  }

  /// Current BPM only when the last device sample is still fresh.
  double? get _displayBpm {
    if (!_hasFreshSample) return null;
    return _liveBpm ?? snap?.latestBpm;
  }

  void _syncBeatToBpm(double? bpm) {
    if (bpm == null) {
      if (_beat.isAnimating) {
        _beat.stop();
        _beat.value = 0;
      }
      return;
    }
    final rate = bpm.clamp(40.0, 180.0);
    final ms = (60000 / rate).round().clamp(333, 1500);
    final next = Duration(milliseconds: ms);
    if (_beat.duration != next) {
      _beat.duration = next;
      if (_beat.isAnimating) {
        _beat
          ..reset()
          ..repeat();
        return;
      }
    }
    if (!_beat.isAnimating) _beat.repeat();
  }

  void _startLivePolling() {
    if (_liveActive) return;
    _liveActive = true;
    _liveTimer?.cancel();
    _ageTicker?.cancel();
    unawaited(LiveHeartRate.start());
    _liveSub ??= LiveHeartRate.samples.listen(_applyLiveSample);
    // Fallback poll every second (native push may miss some writes).
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollLive());
    });
    // Keep age / freshness UI in sync even when BPM is unchanged.
    _ageTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final wasBeating = _beat.isAnimating;
      setState(() {});
      final nowBeating = _displayBpm != null;
      if (wasBeating != nowBeating) _syncBeatToBpm(_displayBpm);
    });
    unawaited(_pollLive());
  }

  void _applyLiveSample(HeartSample sample) {
    if (!mounted || !_liveActive) return;
    // Ignore older samples than what we already show.
    if (_liveAt != null && sample.at.isBefore(_liveAt!)) return;
    final bpmChanged =
        _liveBpm == null || (_liveBpm! - sample.bpm).abs() >= 0.5;
    final timeChanged =
        _liveAt == null || !sample.at.isAtSameMomentAs(_liveAt!);
    if (!bpmChanged && !timeChanged) return;
    setState(() {
      _liveBpm = sample.bpm;
      _liveAt = sample.at;
      final s = snap;
      if (s != null) {
        snap = HeartRateSnapshot(
          samples24h: s.samples24h,
          restingSeries: s.restingSeries,
          avgSeries: s.avgSeries,
          hrvSeries: s.hrvSeries,
          latestBpm: sample.bpm,
          latestAt: sample.at,
          restingBpm: s.restingBpm,
          walkingBpm: s.walkingBpm,
          hrvMs: s.hrvMs,
          irregularRhythm: s.irregularRhythm,
          irregularEventCount: s.irregularEventCount,
          recentEcgs: s.recentEcgs,
          assessment: HeartRateGuidelines.assess(
            restingBpm: s.restingBpm,
            currentBpm: sample.bpm,
            hrvMs: s.hrvMs,
            walkingBpm: s.walkingBpm,
            irregularRhythm: s.irregularRhythm,
            recentRestingOldestFirst:
                s.restingSeries.map((e) => e.value).toList(),
            age: _age,
            athlete: _athlete,
          ),
          permissionGranted: true,
          error: s.error == 'permission' ? null : s.error,
        );
      }
    });
    _syncBeatToBpm(_displayBpm);
  }

  Future<void> _pollLive() async {
    if (!mounted || !_liveActive) return;
    if (_livePolling) return;
    _livePolling = true;
    final tick = ++_liveTick;
    try {
      final sample = await LiveHeartRate.latest();
      if (!mounted || !_liveActive || tick != _liveTick) return;
      if (sample != null) _applyLiveSample(sample);
    } finally {
      _livePolling = false;
    }
  }

  /// Refresh: force latest HealthKit sample, then soft-reload charts.
  Future<void> _refresh() async {
    if (refreshing) return;
    setState(() {
      refreshing = true;
      toast = null;
    });
    final beforeAt = _liveAt;
    final sample = await LiveHeartRate.latest();
    if (!mounted) return;
    if (sample != null) {
      _applyLiveSample(sample);
    }
    final l10n = context.l10n;
    final same = sample == null ||
        (beforeAt != null &&
            sample.at.isAtSameMomentAs(beforeAt) &&
            _liveBpm != null &&
            (_liveBpm! - sample.bpm).abs() < 0.5);
    setState(() {
      toast = same ? l10n.hrRefreshSame : l10n.hrRefreshOk;
    });
    await _load(preserveLive: true);
  }

  Future<({int? age, bool athlete})> _profileHints(String userId) async {
    final rows = await Db.instance.raw.query(
      'profiles',
      columns: ['age'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    final age = rows.isEmpty ? null : (rows.first['age'] as num?)?.toInt();
    // Athlete flag: professional / Superman activity program.
    final act = await Db.instance.raw.query(
      'physical_activity_programs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    var athlete = false;
    if (act.isNotEmpty) {
      final id = act.first['program_id'] as String? ?? '';
      athlete = id == 'professional' || id == 'superman';
    }
    return (age: age, athlete: athlete);
  }

  Future<void> _load({bool initial = false, bool preserveLive = false}) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user!.id;
    setState(() {
      if (initial) {
        loading = true;
      } else if (!preserveLive) {
        refreshing = true;
      }
      if (!preserveLive) toast = null;
    });

    final hints = await _profileHints(userId);
    _age = hints.age;
    _athlete = hints.athlete;

    // Show cached / empty UI quickly — never stay on the spinner forever.
    try {
      final cached = await HeartRateService.loadFromDb(
        userId,
        age: hints.age,
        athlete: hints.athlete,
      ).timeout(const Duration(seconds: 3));
      if (mounted && initial) {
        setState(() {
          snap = cached;
          _mergeLiveFromSnapshot(cached, onlyIfNewer: false);
          loading = false;
        });
        _syncBeatToBpm(_displayBpm);
      }
    } catch (_) {
      if (mounted && initial) {
        setState(() => loading = false);
      }
    }

    HeartRateSnapshot result;
    try {
      result = await HeartRateService.syncAndLoad(
        userId,
        age: hints.age,
        athlete: hints.athlete,
      ).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      result = snap ??
          await HeartRateService.loadFromDb(
            userId,
            age: hints.age,
            athlete: hints.athlete,
            error: 'read',
          );
    } catch (_) {
      result = snap ??
          await HeartRateService.loadFromDb(
            userId,
            age: hints.age,
            athlete: hints.athlete,
            error: 'read',
          );
    }

    if (!mounted) return;
    setState(() {
      snap = result;
      _mergeLiveFromSnapshot(result, onlyIfNewer: preserveLive || _liveAt != null);
      loading = false;
      refreshing = false;
    });
    _syncBeatToBpm(_displayBpm);
    _startLivePolling();
  }

  /// Prefer fresher live overlay over a slower sync/DB snapshot.
  void _mergeLiveFromSnapshot(
    HeartRateSnapshot result, {
    required bool onlyIfNewer,
  }) {
    final candidateBpm = result.latestBpm ?? result.restingBpm;
    final candidateAt = result.latestAt;
    if (candidateBpm == null) return;
    if (onlyIfNewer &&
        _liveAt != null &&
        candidateAt != null &&
        !candidateAt.isAfter(_liveAt!)) {
      return;
    }
    if (onlyIfNewer && _liveAt != null && candidateAt == null) return;
    _liveBpm = candidateBpm;
    if (candidateAt != null) _liveAt = candidateAt;
  }

  Future<void> _grantAccess() async {
    setState(() => refreshing = true);
    final ok = await HeartRateService.requestPermission();
    if (!mounted) return;
    if (!ok) {
      setState(() {
        refreshing = false;
        toast = context.l10n.hrNeedPermission;
      });
      return;
    }
    await _load();
  }

  Future<void> _export() async {
    final s = snap;
    if (s == null || !s.hasData) return;
    final text = HeartRateService.exportSummary(s, context.l10n);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => toast = context.l10n.hrExportCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppModal(
      title: l10n.actionHeartRate,
      onClose: () => Navigator.pop(context),
      child: loading
          ? _readingState(l10n)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  Text(
                    l10n.actionHeartRateDesc,
                    style: TextStyle(fontSize: 13, color: C.gray500, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  if (snap?.error == 'permission' ||
                      snap?.permissionGranted == false)
                    _permissionCard(l10n)
                  else if (snap != null && !snap!.hasData)
                    _emptyCard(l10n)
                  else if (snap != null) ...[
                    _heroCard(l10n, snap!),
                    const SizedBox(height: 14),
                    _metricsGrid(l10n, snap!),
                    const SizedBox(height: 14),
                    _zoneCard(l10n, snap!),
                    const SizedBox(height: 14),
                    _chartSection(l10n, snap!),
                    const SizedBox(height: 14),
                    _meaningSection(l10n, snap!),
                    if (snap!.recentEcgs.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _ecgSection(l10n, snap!),
                    ],
                    if (snap!.irregularRhythm) ...[
                      const SizedBox(height: 14),
                      _alertBanner(
                        l10n.hrIrregularRhythm,
                        l10n.hrExplainIrregular,
                        C.red50,
                        C.red700,
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Text(
                    l10n.hrDisclaimer,
                    style: TextStyle(
                      fontSize: 11,
                      color: C.gray400,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: refreshing ? null : _refresh,
                          icon: refreshing
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: C.blue600,
                                  ),
                                )
                              : Icon(Icons.sync, size: 18, color: C.blue600),
                          label: Text(l10n.hrRefresh),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: snap?.hasData == true ? _export : null,
                          icon: const Icon(Icons.copy_all_outlined, size: 18),
                          label: Text(l10n.hrExport),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.blue600,
                            foregroundColor: C.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (toast != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      toast!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: C.teal600),
                    ),
                  ],
                ],
              ),
    );
  }

  Widget _readingState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _beatingHeart(
            color: C.rose600,
            size: 88,
            iconSize: 42,
            glow: true,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.hrReading,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: C.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.hrReadingHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: C.gray500, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _permissionCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.amber50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.amber200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.hrNeedPermission,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: C.gray900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.hrNeedPermissionBody,
            style: TextStyle(fontSize: 13, color: C.gray600, height: 1.35),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: refreshing ? null : _grantAccess,
            style: ElevatedButton.styleFrom(
              backgroundColor: C.blue600,
              foregroundColor: C.white,
            ),
            child: Text(l10n.hrGrantAccess),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.gray200),
      ),
      child: Text(
        l10n.hrNoDeviceData,
        style: TextStyle(fontSize: 13, color: C.gray600, height: 1.4),
      ),
    );
  }

  Widget _heroCard(AppLocalizations l10n, HeartRateSnapshot s) {
    final bpm = _displayBpm;
    final fresh = bpm != null;
    final zoneColor = fresh ? _zoneColor(s.assessment.zone) : C.gray400;
    final sampleAt = _sampleAt;
    final age = sampleAt == null ? null : DateTime.now().difference(sampleAt);
    final liveFresh = age != null && age.inSeconds < 90;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            zoneColor.withValues(alpha: 0.12),
            C.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zoneColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          _beatingHeart(
            color: zoneColor,
            size: 64,
            iconSize: 30,
            glow: fresh,
            beating: fresh,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.hrCurrent,
                      style: TextStyle(fontSize: 12, color: C.gray500),
                    ),
                    if (fresh) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (liveFresh ? C.green500 : C.amber500)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: liveFresh ? C.green500 : C.amber500,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              liveFresh ? l10n.hrLive : l10n.hrStale,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: liveFresh ? C.green600 : C.amber600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        bpm != null ? bpm.round().toString() : '—',
                        key: ValueKey(bpm?.round() ?? -1),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: C.gray900,
                          height: 1.05,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 6),
                      child: Text(
                        l10n.unitBpm,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: C.gray500,
                        ),
                      ),
                    ),
                    if (fresh) ...[
                      const Spacer(),
                      _trendChip(l10n, s.assessment.trend),
                    ],
                  ],
                ),
                if (fresh && sampleAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _ageLabel(l10n, sampleAt),
                      style: TextStyle(fontSize: 11, color: C.gray400),
                    ),
                  ),
                if (!fresh)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      l10n.hrNoDeviceData,
                      style: TextStyle(
                        fontSize: 12,
                        color: C.gray600,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lub-dub scale synced to [_beat] duration (= current BPM).
  Widget _beatingHeart({
    required Color color,
    required double size,
    required double iconSize,
    bool glow = false,
    bool beating = true,
  }) {
    Widget heart({double scale = 1.0}) {
      final glowAlpha = glow ? (0.18 + (scale - 1.0) * 1.4).clamp(0.12, 0.45) : 0.0;
      return Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: glowAlpha),
                      blurRadius: 14 + (scale - 1.0) * 40,
                      spreadRadius: 1 + (scale - 1.0) * 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(Icons.favorite, color: color, size: iconSize),
        ),
      );
    }

    if (!beating) return heart();
    return AnimatedBuilder(
      animation: _beat,
      builder: (context, _) {
        final t = _beat.value;
        // Two-thump cardiac cycle, then rest until next beat.
        double scale;
        if (t < 0.14) {
          scale = 1.0 + 0.24 * (t / 0.14);
        } else if (t < 0.28) {
          scale = 1.24 - 0.16 * ((t - 0.14) / 0.14);
        } else if (t < 0.40) {
          scale = 1.08 + 0.12 * ((t - 0.28) / 0.12);
        } else if (t < 0.52) {
          scale = 1.20 - 0.20 * ((t - 0.40) / 0.12);
        } else {
          scale = 1.0;
        }
        return heart(scale: scale);
      },
    );
  }

  String _ageLabel(AppLocalizations l10n, DateTime at) {
    final secs = DateTime.now().difference(at).inSeconds;
    if (secs < 5) return l10n.hrUpdatedJustNow;
    if (secs < 60) return l10n.hrUpdatedSecondsAgo(secs);
    final mins = (secs / 60).floor();
    if (mins < 60) return l10n.hrUpdatedMinutesAgo(mins);
    return l10n.hrUpdatedMinutesAgo(mins);
  }

  Widget _trendChip(AppLocalizations l10n, HeartTrend trend) {
    IconData icon;
    String label;
    Color color;
    switch (trend) {
      case HeartTrend.improving:
        icon = Icons.trending_down;
        label = l10n.hrTrendImproving;
        color = C.green600;
      case HeartTrend.worsening:
        icon = Icons.trending_up;
        label = l10n.hrTrendWorsening;
        color = C.red600;
      case HeartTrend.stable:
        icon = Icons.trending_flat;
        label = l10n.hrTrendStable;
        color = C.blue600;
      case HeartTrend.unknown:
        icon = Icons.remove;
        label = l10n.hrTrendUnknown;
        color = C.gray500;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsGrid(AppLocalizations l10n, HeartRateSnapshot s) {
    return Row(
      children: [
        Expanded(
          child: _metricTile(
            l10n.hrResting,
            s.restingBpm != null ? '${s.restingBpm!.round()}' : '—',
            l10n.unitBpm,
            Icons.bedtime_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            l10n.hrWalking,
            s.walkingBpm != null ? '${s.walkingBpm!.round()}' : '—',
            l10n.unitBpm,
            Icons.directions_walk,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricTile(
            l10n.hrHrv,
            s.hrvMs != null ? '${s.hrvMs!.round()}' : '—',
            l10n.unitMs,
            Icons.graphic_eq,
          ),
        ),
      ],
    );
  }

  Widget _metricTile(String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: C.gray500),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: C.gray500),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: C.gray900,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(fontSize: 11, color: C.gray400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneCard(AppLocalizations l10n, HeartRateSnapshot s) {
    final a = s.assessment;
    final color = _zoneColor(a.zone);
    final status = switch (a.statusKey) {
      'attention' => l10n.hrStatusAttention,
      'risk' => l10n.hrStatusRisk,
      _ => l10n.hrStatusNormal,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                l10n.hrNormRangeShort(a.restingLow, a.restingHigh),
                style: TextStyle(fontSize: 11, color: C.gray500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _explain(l10n, a),
            style: TextStyle(fontSize: 13, color: C.gray700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _chartSection(AppLocalizations l10n, HeartRateSnapshot s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.hrChartTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.gray900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final r in const ['24h', '7d', '30d']) ...[
                Expanded(
                  child: _rangeChip(
                    label: r == '24h'
                        ? l10n.hrRange24h
                        : r == '7d'
                            ? l10n.hrRange7d
                            : l10n.hrRange30d,
                    selected: chartRange == r,
                    onTap: () => setState(() => chartRange = r),
                  ),
                ),
                if (r != '30d') const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: _buildChart(s),
          ),
          const SizedBox(height: 8),
          _zoneLegend(l10n, s),
        ],
      ),
    );
  }

  Widget _rangeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? C.blue50 : C.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? C.blue500 : C.gray200),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? C.blue600 : C.gray600,
          ),
        ),
      ),
    );
  }

  Widget _buildChart(HeartRateSnapshot s) {
    final a = s.assessment;
    List<double> values;
    if (chartRange == '24h') {
      values = HeartRateService.hourlyBuckets(s.samples24h)
          .map((e) => e.value)
          .toList();
    } else {
      final days = chartRange == '7d' ? 7 : 30;
      final series = s.restingSeries.isNotEmpty ? s.restingSeries : s.avgSeries;
      final slice = series.length <= days
          ? series
          : series.sublist(series.length - days);
      values = slice.map((e) => e.value).toList();
    }
    if (values.every((v) => v <= 0)) {
      return Center(
        child: Text(
          context.l10n.hrNoChartData,
          style: TextStyle(fontSize: 12, color: C.gray400),
        ),
      );
    }
    final ceil = HeartRateService.chartCeiling(values);
    return CustomPaint(
      painter: _HrBarPainter(
        values: values,
        ceiling: ceil,
        low: a.restingLow.toDouble(),
        high: a.restingHigh.toDouble(),
        green: C.green400,
        yellow: C.amber400,
        red: C.red400,
        zoneFill: C.green500.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _zoneLegend(AppLocalizations l10n, HeartRateSnapshot s) {
    return Row(
      children: [
        _legendDot(C.green500, l10n.hrStatusNormal),
        const SizedBox(width: 10),
        _legendDot(C.amber500, l10n.hrStatusAttention),
        const SizedBox(width: 10),
        _legendDot(C.red500, l10n.hrStatusRisk),
      ],
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: C.gray500)),
      ],
    );
  }

  Widget _meaningSection(AppLocalizations l10n, HeartRateSnapshot s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.hrWhatItMeans,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: C.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.hrWhatItMeansBody,
            style: TextStyle(fontSize: 13, color: C.gray600, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            _explain(l10n, s.assessment),
            style: TextStyle(fontSize: 13, color: C.gray800, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _ecgSection(AppLocalizations l10n, HeartRateSnapshot s) {
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
          for (final e in s.recentEcgs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.monitor_heart_outlined, size: 16, color: C.purple600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${fmt.format(e.at.toLocal())}'
                      '${e.averageBpm != null ? ' · ${e.averageBpm!.round()} ${l10n.unitBpm}' : ''}'
                      ' · ${l10n.hrEcgClassification(e.classification)}',
                      style: TextStyle(fontSize: 12, color: C.gray700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _alertBanner(String title, String body, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: fg, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fg,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(fontSize: 12, color: fg, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _zoneColor(HeartZone z) {
    switch (z) {
      case HeartZone.normal:
        return C.green600;
      case HeartZone.attention:
        return C.amber600;
      case HeartZone.risk:
        return C.red600;
    }
  }

  String _explain(AppLocalizations l10n, HeartRateAssessment a) {
    if (a.irregularRhythm) return l10n.hrExplainIrregular;
    if (a.sharpChange) return l10n.hrExplainSpike;
    if (a.elevatedRestingStreak) return l10n.hrExplainElevatedStreak;
    if (a.restingBpm != null && a.restingBpm! > a.restingHigh) {
      return l10n.hrExplainHighResting(a.restingBpm!.round(), a.restingHigh);
    }
    if (a.restingBpm != null && a.restingBpm! < a.restingLow) {
      return l10n.hrExplainLowResting(a.restingBpm!.round(), a.restingLow);
    }
    if (a.hrvMs != null && a.hrvMs! < 40) return l10n.hrExplainLowHrv;
    if (a.zone == HeartZone.normal) return l10n.hrExplainNormal;
    return l10n.hrAlertGenericBody;
  }
}

class _HrBarPainter extends CustomPainter {
  final List<double> values;
  final double ceiling;
  final double low;
  final double high;
  final Color green;
  final Color yellow;
  final Color red;
  final Color zoneFill;

  _HrBarPainter({
    required this.values,
    required this.ceiling,
    required this.low,
    required this.high,
    required this.green,
    required this.yellow,
    required this.red,
    required this.zoneFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || ceiling <= 0) return;

    // Normal zone band.
    final yHigh = size.height * (1 - (high / ceiling).clamp(0.0, 1.0));
    final yLow = size.height * (1 - (low / ceiling).clamp(0.0, 1.0));
    canvas.drawRect(
      Rect.fromLTRB(0, yHigh, size.width, yLow),
      Paint()..color = zoneFill,
    );

    final n = values.length;
    final gap = size.width / n;
    final barW = gap * 0.62;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      if (v <= 0) continue;
      final h = size.height * (v / ceiling).clamp(0.0, 1.0);
      final color = v < low || v > high + 15
          ? (v < low - 10 || v > high + 15 ? red : yellow)
          : (v > high ? yellow : green);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * gap + (gap - barW) / 2, size.height - h, barW, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _HrBarPainter old) =>
      old.values != values || old.ceiling != ceiling;
}
