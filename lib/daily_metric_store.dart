import 'package:uuid/uuid.dart';

import 'db.dart';

const _uuid = Uuid();

/// Metrics that represent a single running total for the local calendar day.
///
/// Live sync / logs update today's row in place. Yesterday's last value stays
/// frozen after midnight — that becomes the historical Health Indicator point.
const kDailyLiveMetricTypes = {
  'steps',
  'distance',
  'calories',
  'active_time',
  'resting_heart_rate',
  'walking_heart_rate',
  'hrv_sdnn',
  'heart_rate_avg',
  'irregular_rhythm',
};

/// Upsert helpers so Health Indicator shows one value per day.
class DailyMetricStore {
  DailyMetricStore._();

  /// Local calendar key `YYYY-MM-DD`.
  static String localDateKey([DateTime? when]) {
    final d = (when ?? DateTime.now()).toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// UTC ISO bounds for the local calendar day of [when].
  static ({String startIso, String endIso}) localDayBounds([DateTime? when]) {
    final local = (when ?? DateTime.now()).toLocal();
    final startLocal = DateTime(local.year, local.month, local.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    return (
      startIso: startLocal.toUtc().toIso8601String(),
      endIso: endLocal.toUtc().toIso8601String(),
    );
  }

  static bool isDailyLiveMetric(String metricType) =>
      kDailyLiveMetricTypes.contains(metricType);

  /// Insert or update today's row for [metricType].
  ///
  /// Pass [at] to target another local calendar day (e.g. finalize yesterday
  /// from HealthKit). [recorded_at] always stays inside that day's bounds so
  /// history queries do not lose the row after midnight.
  static Future<void> upsertToday({
    required String userId,
    required String metricType,
    required double value,
    String? notes,
    String? source,
    DateTime? at,
  }) async {
    final local = (at ?? DateTime.now()).toLocal();
    await upsertOnLocalDay(
      userId: userId,
      metricType: metricType,
      value: value,
      day: local,
      notes: notes,
      source: source,
    );
  }

  /// Insert or update the single live row for [day]'s local calendar date.
  static Future<void> upsertOnLocalDay({
    required String userId,
    required String metricType,
    required double value,
    required DateTime day,
    String? notes,
    String? source,
  }) async {
    if (!Db.instance.isReady) return;
    final local = day.toLocal();
    final dayStart = DateTime(local.year, local.month, local.day);
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    // Today stays live (now); past days freeze at end-of-day so the timestamp
    // never drifts into the next calendar day.
    final stamp = dayStart.isAtSameMomentAs(todayStart)
        ? DateTime.now()
        : dayStart.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    final stampIso = stamp.toUtc().toIso8601String();
    final bounds = localDayBounds(dayStart);
    final existing = await Db.instance.raw.query(
      'health_metrics',
      columns: ['id'],
      where:
          'user_id = ? AND metric_type = ? AND recorded_at >= ? AND recorded_at < ?',
      whereArgs: [userId, metricType, bounds.startIso, bounds.endIso],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await Db.instance.raw.update(
        'health_metrics',
        {
          'value': value,
          'recorded_at': stampIso,
          'created_at': stampIso,
          if (notes != null) 'notes': notes,
          if (source != null) 'source': source,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }

    await Db.instance.raw.insert('health_metrics', {
      'id': _uuid.v4(),
      'user_id': userId,
      'metric_type': metricType,
      'value': value,
      'recorded_at': stampIso,
      'notes': notes,
      'source': source,
      'created_at': stampIso,
    });
  }

  /// Latest value per local day, oldest → newest, capped at [limit] days.
  static Future<List<double>> dailySeries({
    required String userId,
    required String metricType,
    int limit = 14,
  }) async {
    if (!Db.instance.isReady) return const [];
    final rows = await Db.instance.raw.query(
      'health_metrics',
      columns: ['value', 'recorded_at'],
      where: 'user_id = ? AND metric_type = ?',
      whereArgs: [userId, metricType],
      orderBy: 'recorded_at DESC',
      limit: limit * 8,
    );
    final byDay = <String, double>{};
    for (final r in rows) {
      final key = localDateKey(DateTime.parse(r['recorded_at'] as String));
      byDay.putIfAbsent(key, () => (r['value'] as num).toDouble());
    }
    final days = byDay.keys.toList()..sort();
    final chronological = days.map((d) => byDay[d]!).toList();
    if (chronological.length <= limit) return chronological;
    return chronological.sublist(chronological.length - limit);
  }

  /// Fixed local-calendar window ending today (oldest → newest).
  /// Missing days are filled with `0` so charts always show [days] bars.
  static Future<List<({DateTime day, double value})>> lastNCalendarDays({
    required String userId,
    required String metricType,
    int days = 7,
  }) async {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final byDay = <String, double>{};

    if (Db.instance.isReady) {
      final bounds = localDayBounds(start);
      final endBounds = localDayBounds(today);
      final rows = await Db.instance.raw.query(
        'health_metrics',
        columns: ['value', 'recorded_at'],
        where:
            'user_id = ? AND metric_type = ? AND recorded_at >= ? AND recorded_at < ?',
        whereArgs: [
          userId,
          metricType,
          bounds.startIso,
          endBounds.endIso,
        ],
        orderBy: 'recorded_at DESC',
      );
      for (final r in rows) {
        final key = localDateKey(DateTime.parse(r['recorded_at'] as String));
        byDay.putIfAbsent(key, () => (r['value'] as num).toDouble());
      }
    }

    return List.generate(days, (i) {
      final day = start.add(Duration(days: i));
      final key = localDateKey(day);
      return (day: day, value: byDay[key] ?? 0);
    });
  }

  /// Latest Health Index score per local day, oldest → newest.
  static Future<List<({DateTime at, int score, String status})>>
      dailyHealthIndexSeries({
    required String userId,
    int limit = 14,
  }) async {
    if (!Db.instance.isReady) return const [];
    final rows = await Db.instance.raw.query(
      'health_index',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'calculated_at DESC',
      limit: limit * 8,
    );
    final byDay = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final key = localDateKey(DateTime.parse(r['calculated_at'] as String));
      byDay.putIfAbsent(key, () => r);
    }
    final days = byDay.keys.toList()..sort();
    final chronological = days.map((d) {
      final r = byDay[d]!;
      return (
        at: DateTime.parse(r['calculated_at'] as String),
        score: (r['score'] as num).toInt(),
        status: r['status'] as String,
      );
    }).toList();
    if (chronological.length <= limit) return chronological;
    return chronological.sublist(chronological.length - limit);
  }

  /// Fixed local-calendar window of Health Index (oldest → newest).
  /// Days without a score use `0`.
  static Future<List<({DateTime day, double value})>> lastNCalendarDaysHealthIndex({
    required String userId,
    int days = 7,
  }) async {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final byDay = <String, double>{};

    if (Db.instance.isReady) {
      final bounds = localDayBounds(start);
      final endBounds = localDayBounds(today);
      final rows = await Db.instance.raw.query(
        'health_index',
        columns: ['score', 'calculated_at'],
        where: 'user_id = ? AND calculated_at >= ? AND calculated_at < ?',
        whereArgs: [userId, bounds.startIso, endBounds.endIso],
        orderBy: 'calculated_at DESC',
      );
      for (final r in rows) {
        final key = localDateKey(DateTime.parse(r['calculated_at'] as String));
        byDay.putIfAbsent(key, () => (r['score'] as num).toDouble());
      }
    }

    return List.generate(days, (i) {
      final day = start.add(Duration(days: i));
      final key = localDateKey(day);
      return (day: day, value: byDay[key] ?? 0);
    });
  }

  /// Keep one row per (user, metric, local day) for live daily metrics.
  static Future<void> collapseDuplicateDailyMetrics(dynamic db) async {
    final rows = await db.query(
      'health_metrics',
      where:
          "metric_type IN ('steps','distance','calories','active_time')",
      orderBy: 'recorded_at DESC',
    );
    final seen = <String>{};
    final deleteIds = <String>[];
    for (final r in rows) {
      final key =
          '${r['user_id']}|${r['metric_type']}|${localDateKey(DateTime.parse(r['recorded_at'] as String))}';
      if (seen.contains(key)) {
        deleteIds.add(r['id'] as String);
      } else {
        seen.add(key);
      }
    }
    for (final id in deleteIds) {
      await db.delete('health_metrics', where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Keep one Health Index row per (user, local day).
  static Future<void> collapseDuplicateHealthIndex(dynamic db) async {
    final rows = await db.query(
      'health_index',
      orderBy: 'calculated_at DESC',
    );
    final seen = <String>{};
    final deleteIds = <String>[];
    for (final r in rows) {
      final key =
          '${r['user_id']}|${localDateKey(DateTime.parse(r['calculated_at'] as String))}';
      if (seen.contains(key)) {
        deleteIds.add(r['id'] as String);
      } else {
        seen.add(key);
      }
    }
    for (final id in deleteIds) {
      await db.delete('health_index', where: 'id = ?', whereArgs: [id]);
    }
  }
}
