import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'daily_metric_store.dart';
import 'daily_notifications.dart';
import 'db.dart';
import 'health_index.dart';
import 'health_telemetry.dart';
import 'heart_rate.dart';
import 'l10n/generated/app_localizations.dart';
import 'locale_controller.dart';

const _uuid = Uuid();
const _hrAuthKey = 'health_heart_rate_authorized';
const _hrAlertCooldownKey = 'heart_rate_alert_last_at';
const _hrAlertNotifId = 2101;
const _hrAlarmSound = 'Alarm.mp3';

/// One HealthKit (or stored) heart-rate sample.
class HeartSample {
  final DateTime at;
  final double bpm;
  const HeartSample(this.at, this.bpm);
}

class EcgSummary {
  final DateTime at;
  final double? averageBpm;
  final String classification;
  const EcgSummary({
    required this.at,
    this.averageBpm,
    required this.classification,
  });
}

/// Full snapshot used by the Heart Rate & Rhythm Quick Action.
class HeartRateSnapshot {
  final List<HeartSample> samples24h;
  final List<({DateTime day, double value})> restingSeries;
  final List<({DateTime day, double value})> avgSeries;
  final List<({DateTime day, double value})> hrvSeries;
  final double? latestBpm;
  final DateTime? latestAt;
  final double? restingBpm;
  final double? walkingBpm;
  final double? hrvMs;
  final bool irregularRhythm;
  final int irregularEventCount;
  final List<EcgSummary> recentEcgs;
  final HeartRateAssessment assessment;
  final bool permissionGranted;
  final String? error;

  const HeartRateSnapshot({
    required this.samples24h,
    required this.restingSeries,
    required this.avgSeries,
    required this.hrvSeries,
    required this.assessment,
    required this.permissionGranted,
    this.latestBpm,
    this.latestAt,
    this.restingBpm,
    this.walkingBpm,
    this.hrvMs,
    this.irregularRhythm = false,
    this.irregularEventCount = 0,
    this.recentEcgs = const [],
    this.error,
  });

  bool get hasData => assessment.hasAnyData || samples24h.isNotEmpty;
}

/// Reads heart metrics from Apple Health / Health Connect and persists daily
/// summaries into `health_metrics`.
class HeartRateService {
  HeartRateService._();

  static final Health _health = Health();
  static bool _configured = false;

  static const _types = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.WALKING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.IRREGULAR_HEART_RATE_EVENT,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  static bool get isSupported => HealthTelemetryService.isSupported;

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure().timeout(const Duration(seconds: 5));
    _configured = true;
  }

  /// True when we previously got a HealthKit auth sheet for heart types.
  /// iOS never confirms READ grants — so this is only a soft hint.
  static Future<bool> hasPermission() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    if (Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hrAuthKey) ?? false;
    }
    final permitted =
        await _health.hasPermissions(_types, permissions: _permissions);
    return permitted ?? false;
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      await _ensureConfigured();
      if (Platform.isIOS) {
        final prefs = await SharedPreferences.getInstance();
        // iOS 26+: repeating requestAuthorization after a decision can show a
        // blank undismissable sheet (looks like a stuck white screen).
        if (prefs.getBool(_hrAuthKey) ?? false) {
          return true;
        }
      }
      final granted = await _health
          .requestAuthorization(_types, permissions: _permissions)
          .timeout(const Duration(seconds: 45));
      if (Platform.isIOS) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_hrAuthKey, true);
      }
      return granted || Platform.isIOS;
    } catch (e) {
      debugPrint('HeartRateService.requestPermission failed: $e');
      return false;
    }
  }

  /// Latest HEART_RATE sample. Short lookback for live 1 Hz polling.
  static Future<HeartSample?> fetchLatestSample({
    Duration lookback = const Duration(minutes: 5),
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (!isSupported) return null;
    try {
      await _ensureConfigured();
    } catch (_) {
      return null;
    }
    final now = DateTime.now();
    var points = await _safeQuery(
      [HealthDataType.HEART_RATE],
      now.subtract(lookback),
      now,
      timeout: timeout,
    );
    if (points.isEmpty) {
      points = await _safeQuery(
        [HealthDataType.HEART_RATE],
        now.subtract(const Duration(hours: 2)),
        now,
        timeout: timeout,
      );
    }
    final newest = _newestSample(points);
    // Remember that HealthKit READ works — skip future auth prompts.
    if (newest != null && Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_hrAuthKey) ?? false)) {
        await prefs.setBool(_hrAuthKey, true);
      }
    }
    return newest;
  }

  static HeartSample? _newestSample(List<HealthDataPoint> points) {
    HeartSample? best;
    for (final p in points) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final n = v.numericValue.toDouble();
      if (n <= 0 || n > 250) continue;
      // Prefer dateTo (sample end); fall back to dateFrom.
      final at = p.dateTo.isAfter(p.dateFrom) ? p.dateTo : p.dateFrom;
      if (best == null || at.isAfter(best.at)) {
        best = HeartSample(at, n);
      }
    }
    return best;
  }

  /// Pulls HealthKit data, persists daily aggregates, returns UI snapshot.
  /// Does not show the Health auth sheet — call [requestPermission] from UI.
  static Future<HeartRateSnapshot> syncAndLoad(
    String userId, {
    int? age,
    bool athlete = false,
    bool notifyOnRisk = true,
  }) async {
    if (!isSupported) {
      return _empty(
        permissionGranted: false,
        error: 'unsupported',
        age: age,
        athlete: athlete,
      );
    }

    try {
      await _ensureConfigured();
    } catch (e) {
      debugPrint('HeartRate configure failed: $e');
      return loadFromDb(userId, age: age, athlete: athlete, error: 'read');
    }

    // Never await the system auth sheet here — it can hang forever / blank on
    // iOS 26 and leaves the modal stuck on "Reading heart data…".
    final prompted = await hasPermission();

    try {
      final now = DateTime.now();
      final start7 = now.subtract(const Duration(days: 7));
      final start24 = now.subtract(const Duration(hours: 24));

      final results = await Future.wait([
        _safeQuery(
          [HealthDataType.HEART_RATE],
          now.subtract(const Duration(hours: 6)),
          now,
        ),
        _safeQuery([HealthDataType.HEART_RATE], start24, now),
        _safeQuery([HealthDataType.RESTING_HEART_RATE], start7, now),
        _safeQuery([HealthDataType.WALKING_HEART_RATE], start7, now),
        _safeQuery(
          [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
          start7,
          now,
        ),
        _safeQuery(
          [HealthDataType.IRREGULAR_HEART_RATE_EVENT],
          start7,
          now,
        ),
      ]);

      final latestPoints = results[0];
      final hrPoints = results[1];
      final restingPoints = results[2];
      final walkingPoints = results[3];
      final hrvPoints = results[4];
      final irregularPoints = results[5];

      final newest = _newestSample(latestPoints);
      final samples = _numericSamples(hrPoints);
      samples.sort((a, b) => a.at.compareTo(b.at));
      final samples24h = List<HeartSample>.from(samples);
      if (newest != null &&
          (samples24h.isEmpty || newest.at.isAfter(samples24h.last.at))) {
        samples24h.add(newest);
      }

      final restingByDay = _dailyLatest(restingPoints);
      final avgByDay = _dailyAverage(samples);
      final hrvByDay = _dailyAverage(_numericSamples(hrvPoints));
      final walkingByDay = _dailyLatest(walkingPoints);

      final hasHkData = newest != null ||
          samples24h.isNotEmpty ||
          restingByDay.isNotEmpty ||
          hrvByDay.isNotEmpty;

      if (!hasHkData && !prompted) {
        return _empty(
          permissionGranted: false,
          error: 'permission',
          age: age,
          athlete: athlete,
        );
      }

      // Persist in background — do not block the graph UI.
      unawaited(_persistDay(
        userId: userId,
        resting: restingByDay[DailyMetricStore.localDateKey()],
        walking: walkingByDay[DailyMetricStore.localDateKey()],
        hrv: hrvByDay[DailyMetricStore.localDateKey()],
        avgHr: avgByDay[DailyMetricStore.localDateKey()],
        samplesToday: samples24h
            .where((s) =>
                DailyMetricStore.localDateKey(s.at) ==
                DailyMetricStore.localDateKey())
            .toList(),
        irregularCount: irregularPoints.length,
      ));
      unawaited(HealthIndexService.recalculate(userId));

      final restingSeries = await _seriesFromMap(restingByDay, 30);
      final avgSeries = await _seriesFromMap(avgByDay, 30);
      final hrvSeries = await _seriesFromMap(hrvByDay, 30);

      final restingToday = restingByDay[DailyMetricStore.localDateKey()];
      final walkingToday = walkingByDay[DailyMetricStore.localDateKey()];
      final hrvToday = hrvByDay[DailyMetricStore.localDateKey()];
      final latest = newest?.bpm ??
          (samples24h.isNotEmpty ? samples24h.last.bpm : null);
      final irregular = irregularPoints.isNotEmpty;

      final assessment = HeartRateGuidelines.assess(
        restingBpm: restingToday,
        currentBpm: latest,
        hrvMs: hrvToday,
        walkingBpm: walkingToday,
        irregularRhythm: irregular,
        recentRestingOldestFirst:
            restingSeries.map((e) => e.value).toList(),
        age: age,
        athlete: athlete,
      );

      if (notifyOnRisk && assessment.shouldAlarm) {
        unawaited(maybeNotify(userId, assessment));
      }

      return HeartRateSnapshot(
        samples24h: samples24h,
        restingSeries: restingSeries,
        avgSeries: avgSeries,
        hrvSeries: hrvSeries,
        latestBpm: latest,
        latestAt: newest?.at ??
            (samples24h.isNotEmpty ? samples24h.last.at : null),
        restingBpm: restingToday,
        walkingBpm: walkingToday,
        hrvMs: hrvToday,
        irregularRhythm: irregular,
        irregularEventCount: irregularPoints.length,
        recentEcgs: const [],
        assessment: assessment,
        permissionGranted: prompted || hasHkData,
      );
    } catch (e) {
      debugPrint('HeartRateService.syncAndLoad: $e');
      return loadFromDb(userId, age: age, athlete: athlete, error: 'read');
    }
  }

  /// Loads last persisted heart metrics without hitting HealthKit.
  static Future<HeartRateSnapshot> loadFromDb(
    String userId, {
    int? age,
    bool athlete = false,
    String? error,
  }) async {
    final restingSeries = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'resting_heart_rate',
      days: 30,
    );
    final avgSeries = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'heart_rate_avg',
      days: 30,
    );
    final hrvSeries = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'hrv_sdnn',
      days: 30,
    );
    final samples24h = await _samplesFromDb(userId, const Duration(hours: 24));

    double? lastPositive(List<({DateTime day, double value})> s) {
      for (var i = s.length - 1; i >= 0; i--) {
        if (s[i].value > 0) return s[i].value;
      }
      return null;
    }

    final resting = lastPositive(restingSeries);
    final hrv = lastPositive(hrvSeries);
    final latest = samples24h.isNotEmpty
        ? samples24h.last.bpm
        : lastPositive(avgSeries);

    final walkingRows = await Db.instance.raw.query(
      'health_metrics',
      where: 'user_id = ? AND metric_type = ?',
      whereArgs: [userId, 'walking_heart_rate'],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    final walking = walkingRows.isEmpty
        ? null
        : (walkingRows.first['value'] as num).toDouble();

    final irregularRows = await Db.instance.raw.query(
      'health_metrics',
      where: 'user_id = ? AND metric_type = ?',
      whereArgs: [userId, 'irregular_rhythm'],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    final irregularCount = irregularRows.isEmpty
        ? 0
        : (irregularRows.first['value'] as num).toInt();

    final assessment = HeartRateGuidelines.assess(
      restingBpm: resting,
      currentBpm: latest,
      hrvMs: hrv,
      walkingBpm: walking,
      irregularRhythm: irregularCount > 0,
      recentRestingOldestFirst: restingSeries.map((e) => e.value).toList(),
      age: age,
      athlete: athlete,
    );

    return HeartRateSnapshot(
      samples24h: samples24h,
      restingSeries: restingSeries,
      avgSeries: avgSeries,
      hrvSeries: hrvSeries,
      latestBpm: latest,
      latestAt: samples24h.isNotEmpty ? samples24h.last.at : null,
      restingBpm: resting,
      walkingBpm: walking,
      hrvMs: hrv,
      irregularRhythm: irregularCount > 0,
      irregularEventCount: irregularCount,
      assessment: assessment,
      permissionGranted: await hasPermission(),
      error: error,
    );
  }

  static Future<void> maybeNotify(
    String userId,
    HeartRateAssessment assessment,
  ) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final lastIso = prefs.getString(_hrAlertCooldownKey);
    if (lastIso != null) {
      final last = DateTime.tryParse(lastIso);
      if (last != null &&
          DateTime.now().difference(last) < const Duration(hours: 6)) {
        return;
      }
    }

    final ready = await DailyNotificationService.ensureReady();
    if (!ready) return;

    final l10n = await LocaleController.loadLocalizations();
    final title = assessment.zone == HeartZone.risk
        ? l10n.hrAlertRiskTitle
        : l10n.hrAlertAttentionTitle;
    final body = _alertBody(l10n, assessment);
    final now = DateTime.now();

    await DailyNotificationService.plugin.show(
      _hrAlertNotifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'pha_heart_rate_alarm',
          l10n.actionHeartRate,
          channelDescription: l10n.actionHeartRateDesc,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('alarm'),
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: _hrAlarmSound,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: '{"type":"heart_rate"}',
    );
    await prefs.setString(
      _hrAlertCooldownKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    await DailyNotificationService.saveHeartRateAlert(
      userId: userId,
      title: title,
      body: body,
      hour: now.hour,
      minute: now.minute,
    );
  }

  /// Plain-text export for clipboard / share.
  static String exportSummary(
    HeartRateSnapshot snap,
    AppLocalizations l10n,
  ) {
    final buf = StringBuffer();
    buf.writeln(l10n.hrExportTitle);
    buf.writeln(l10n.hrDisclaimer);
    buf.writeln();
    if (snap.latestBpm != null) {
      buf.writeln('${l10n.hrCurrent}: ${snap.latestBpm!.round()} ${l10n.unitBpm}');
    }
    if (snap.restingBpm != null) {
      buf.writeln(
          '${l10n.hrResting}: ${snap.restingBpm!.round()} ${l10n.unitBpm}');
    }
    if (snap.walkingBpm != null) {
      buf.writeln(
          '${l10n.hrWalking}: ${snap.walkingBpm!.round()} ${l10n.unitBpm}');
    }
    if (snap.hrvMs != null) {
      buf.writeln('${l10n.hrHrv}: ${snap.hrvMs!.round()} ${l10n.unitMs}');
    }
    buf.writeln(
        '${l10n.hrStatus}: ${_statusLabel(l10n, snap.assessment.statusKey)}');
    buf.writeln(
        '${l10n.hrNormRange}: ${snap.assessment.restingLow}–${snap.assessment.restingHigh} ${l10n.unitBpm}');
    if (snap.irregularRhythm) {
      buf.writeln(
          '${l10n.hrIrregularRhythm}: ${snap.irregularEventCount}');
    }
    return buf.toString();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static HeartRateSnapshot _empty({
    required bool permissionGranted,
    String? error,
    int? age,
    bool athlete = false,
  }) {
    final range = HeartRateGuidelines.restingRange(age: age, athlete: athlete);
    return HeartRateSnapshot(
      samples24h: const [],
      restingSeries: const [],
      avgSeries: const [],
      hrvSeries: const [],
      assessment: HeartRateAssessment(
        zone: HeartZone.normal,
        statusKey: 'normal',
        primaryMetric: 'resting',
        restingLow: range.low,
        restingHigh: range.high,
      ),
      permissionGranted: permissionGranted,
      error: error,
    );
  }

  static Future<List<HealthDataPoint>> _safeQuery(
    List<HealthDataType> types,
    DateTime start,
    DateTime end, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      return await _health
          .getHealthDataFromTypes(
            types: types,
            startTime: start,
            endTime: end,
          )
          .timeout(timeout);
    } catch (e) {
      debugPrint('HeartRate query $types failed: $e');
      return const [];
    }
  }

  static List<HeartSample> _numericSamples(List<HealthDataPoint> points) {
    final out = <HeartSample>[];
    for (final p in points) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final n = v.numericValue.toDouble();
      if (n <= 0 || n > 250) continue;
      out.add(HeartSample(p.dateTo, n));
    }
    return out;
  }

  static Map<String, double> _dailyLatest(List<HealthDataPoint> points) {
    final map = <String, double>{};
    final sorted = [...points]
      ..sort((a, b) => b.dateTo.compareTo(a.dateTo));
    for (final p in sorted) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      final n = v.numericValue.toDouble();
      if (n <= 0) continue;
      final key = DailyMetricStore.localDateKey(p.dateTo);
      map.putIfAbsent(key, () => n);
    }
    return map;
  }

  static Map<String, double> _dailyAverage(List<HeartSample> samples) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final s in samples) {
      final key = DailyMetricStore.localDateKey(s.at);
      sums[key] = (sums[key] ?? 0) + s.bpm;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return {
      for (final e in sums.entries) e.key: e.value / counts[e.key]!,
    };
  }

  static Future<List<({DateTime day, double value})>> _seriesFromMap(
    Map<String, double> byDay,
    int days,
  ) async {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    return List.generate(days, (i) {
      final day = start.add(Duration(days: i));
      final key = DailyMetricStore.localDateKey(day);
      return (day: day, value: byDay[key] ?? 0);
    });
  }

  static Future<void> _persistDay({
    required String userId,
    required double? resting,
    required double? walking,
    required double? hrv,
    required double? avgHr,
    required List<HeartSample> samplesToday,
    required int irregularCount,
  }) async {
    if (!Db.instance.isReady) return;

    if (resting != null) {
      await DailyMetricStore.upsertToday(
        userId: userId,
        metricType: 'resting_heart_rate',
        value: resting,
        source: 'healthkit',
      );
    }
    if (walking != null) {
      await DailyMetricStore.upsertToday(
        userId: userId,
        metricType: 'walking_heart_rate',
        value: walking,
        source: 'healthkit',
      );
    }
    if (hrv != null) {
      await DailyMetricStore.upsertToday(
        userId: userId,
        metricType: 'hrv_sdnn',
        value: hrv,
        source: 'healthkit',
      );
    }
    if (avgHr != null) {
      await DailyMetricStore.upsertToday(
        userId: userId,
        metricType: 'heart_rate_avg',
        value: avgHr,
        source: 'healthkit',
      );
    }
    // latestBpm is reflected via downsampled samples + heart_rate_avg.

    // Replace today's downsampled HR samples.
    final bounds = DailyMetricStore.localDayBounds();
    await Db.instance.raw.delete(
      'health_metrics',
      where:
          'user_id = ? AND metric_type = ? AND source = ? AND recorded_at >= ? AND recorded_at < ? AND notes = ?',
      whereArgs: [
        userId,
        'heart_rate',
        'healthkit',
        bounds.startIso,
        bounds.endIso,
        'sample',
      ],
    );
    final down = _downsample(samplesToday, const Duration(minutes: 10));
    for (final s in down) {
      await Db.instance.raw.insert('health_metrics', {
        'id': _uuid.v4(),
        'user_id': userId,
        'metric_type': 'heart_rate',
        'value': s.bpm,
        'recorded_at': s.at.toUtc().toIso8601String(),
        'notes': 'sample',
        'source': 'healthkit',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    await DailyMetricStore.upsertToday(
      userId: userId,
      metricType: 'irregular_rhythm',
      value: irregularCount.toDouble(),
      source: 'healthkit',
      notes: irregularCount > 0 ? 'irregular_events' : 'none',
    );
  }

  static List<HeartSample> _downsample(
    List<HeartSample> samples,
    Duration bucket,
  ) {
    if (samples.isEmpty) return const [];
    final out = <HeartSample>[];
    DateTime? bucketStart;
    double sum = 0;
    var count = 0;
    DateTime? lastAt;
    for (final s in samples) {
      bucketStart ??= s.at;
      if (s.at.difference(bucketStart) >= bucket && count > 0) {
        out.add(HeartSample(lastAt ?? bucketStart, sum / count));
        bucketStart = s.at;
        sum = 0;
        count = 0;
      }
      sum += s.bpm;
      count++;
      lastAt = s.at;
    }
    if (count > 0 && bucketStart != null) {
      out.add(HeartSample(lastAt ?? bucketStart, sum / count));
    }
    return out;
  }

  static Future<List<HeartSample>> _samplesFromDb(
    String userId,
    Duration lookback,
  ) async {
    if (!Db.instance.isReady) return const [];
    final since =
        DateTime.now().toUtc().subtract(lookback).toIso8601String();
    final rows = await Db.instance.raw.query(
      'health_metrics',
      where: 'user_id = ? AND metric_type = ? AND recorded_at >= ?',
      whereArgs: [userId, 'heart_rate', since],
      orderBy: 'recorded_at ASC',
    );
    return [
      for (final r in rows)
        HeartSample(
          DateTime.parse(r['recorded_at'] as String).toLocal(),
          (r['value'] as num).toDouble(),
        ),
    ];
  }

  static String _statusLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'attention':
        return l10n.hrStatusAttention;
      case 'risk':
        return l10n.hrStatusRisk;
      default:
        return l10n.hrStatusNormal;
    }
  }

  static String _alertBody(AppLocalizations l10n, HeartRateAssessment a) {
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
    return l10n.hrAlertGenericBody;
  }

  /// Bucket 24h samples into hourly averages for sparkline charts.
  static List<({DateTime hour, double value})> hourlyBuckets(
    List<HeartSample> samples,
  ) {
    if (samples.isEmpty) return const [];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour)
        .subtract(const Duration(hours: 23));
    final sums = List<double>.filled(24, 0);
    final counts = List<int>.filled(24, 0);
    for (final s in samples) {
      final idx = s.at.difference(start).inHours;
      if (idx < 0 || idx >= 24) continue;
      sums[idx] += s.bpm;
      counts[idx]++;
    }
    return List.generate(24, (i) {
      final hour = start.add(Duration(hours: i));
      final v = counts[i] == 0 ? 0.0 : sums[i] / counts[i];
      return (hour: hour, value: v);
    });
  }

  static double chartCeiling(Iterable<double> values, {double minCeil = 100}) {
    var maxV = minCeil;
    for (final v in values) {
      if (v > maxV) maxV = v;
    }
    return math.max(minCeil, (maxV / 10).ceil() * 10.0);
  }
}
