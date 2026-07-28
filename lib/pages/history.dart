import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../daily_metric_store.dart';
import '../db.dart';
import '../models.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';

class _MetricConfig {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  const _MetricConfig(this.label, this.icon, this.color, this.bg);
}

Map<String, _MetricConfig> get _configs => {
  'steps': _MetricConfig('Steps', Icons.directions_walk, C.green600, C.green100),
  'calories': _MetricConfig('Calories', Icons.local_fire_department, C.orange600, C.orange100),
  'distance': _MetricConfig('Distance', Icons.place, C.blue600, C.blue100),
  'active_time': _MetricConfig('Active Time', Icons.access_time, C.teal600, C.teal100),
  'weight': _MetricConfig('Weight', Icons.favorite, C.rose600, C.rose100),
  'water': _MetricConfig('Water', Icons.water_drop, C.sky600, C.sky100),
  'glucose': _MetricConfig('Blood Glucose', Icons.water_drop, C.red600, C.red100),
  'blood_pressure_systolic':
      _MetricConfig('BP Systolic', Icons.monitor_heart, C.purple600, C.purple100),
  'blood_pressure_diastolic':
      _MetricConfig('BP Diastolic', Icons.monitor_heart, C.pink600, C.pink100),
};

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _chartRanges = [7, 30, 90];

  List<HealthMetric> metrics = [];
  List<({DateTime day, double value})> stepSeries = const [];
  List<({DateTime day, double value})> healthIndexSeries = const [];
  int chartRangeDays = 7;
  bool loading = true;
  bool loadingCharts = false;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadChartSeries(String userId, int days) async {
    final steps = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'steps',
      days: days,
    );
    final index = await DailyMetricStore.lastNCalendarDaysHealthIndex(
      userId: userId,
      days: days,
    );
    if (!mounted) return;
    setState(() {
      stepSeries = steps;
      healthIndexSeries = index;
      chartRangeDays = days;
      loadingCharts = false;
    });
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user!.id;
    final rows = await Db.instance.raw.query('health_metrics',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'recorded_at DESC', limit: 200);
    // Keep one steps/distance/calories/active_time row per local day.
    final seenDaily = <String>{};
    final filtered = <HealthMetric>[];
    for (final r in rows) {
      final m = HealthMetric.fromRow(r);
      if (DailyMetricStore.isDailyLiveMetric(m.metricType)) {
        final key =
            '${m.metricType}|${DailyMetricStore.localDateKey(m.recordedAt)}';
        if (seenDaily.contains(key)) continue;
        seenDaily.add(key);
      }
      filtered.add(m);
      if (filtered.length >= 100) break;
    }
    final steps = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'steps',
      days: chartRangeDays,
    );
    final index = await DailyMetricStore.lastNCalendarDaysHealthIndex(
      userId: userId,
      days: chartRangeDays,
    );
    if (!mounted) return;
    setState(() {
      metrics = filtered;
      stepSeries = steps;
      healthIndexSeries = index;
      loading = false;
    });
  }

  Future<void> _setChartRange(int days) async {
    if (days == chartRangeDays) return;
    setState(() {
      chartRangeDays = days;
      loadingCharts = true;
    });
    final userId = context.read<AuthProvider>().user!.id;
    await _loadChartSeries(userId, days);
  }

  String _unit(String type, String sys) {
    switch (type) {
      case 'steps':
        return 'steps';
      case 'calories':
        return 'kcal';
      case 'active_time':
        return 'min';
      case 'water':
        return 'ml';
      case 'blood_pressure_systolic':
      case 'blood_pressure_diastolic':
        return 'mmHg';
      default:
        return getMetricUnit(type, sys);
    }
  }

  String _value(HealthMetric m, String sys) {
    if (m.metricType == 'steps') return fmtThousands(m.value);
    if (m.metricType == 'glucose') return formatGlucose(m.value, sys).value;
    final disp = toDisplayValue(m.metricType, m.value, sys);
    if (m.metricType == 'distance') return disp.toStringAsFixed(2);
    if (m.metricType == 'weight') return disp.toStringAsFixed(1);
    return m.value.toStringAsFixed(m.value == m.value.roundToDouble() ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final sys = context.watch<AuthProvider>().unitSystem;
    final filtered =
        filter == 'all' ? metrics : metrics.where((m) => m.metricType == filter).toList();
    final types = metrics.map((m) => m.metricType).toSet().toList();

    final grouped = <String, List<HealthMetric>>{};
    for (final m in filtered) {
      final key = DateFormat('EEEE, MMMM d, y').format(m.recordedAt.toLocal());
      grouped.putIfAbsent(key, () => []).add(m);
    }

    return Column(
        children: [
          _pageHeader('Health History', 'Your recorded health metrics over time'),
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1152),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _stepTrendChart(),
                              SizedBox(height: 24),
                              if (metrics.isEmpty)
                                _empty()
                              else ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _chip('All', 'all'),
                                    ...types.map((t) =>
                                        _chip(_configs[t]?.label ?? t, t)),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Text(
                                    '${filtered.length} record${filtered.length != 1 ? 's' : ''}',
                                    style: TextStyle(
                                        fontSize: 14, color: C.gray400)),
                                SizedBox(height: 16),
                                ...grouped.entries
                                    .map((e) => _dateGroup(e.key, e.value, sys)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
    );
  }

  Widget _stepTrendChart() {
    final stepAvg = stepSeries.isEmpty
        ? 0.0
        : stepSeries.map((e) => e.value).fold<double>(0, (a, b) => a + b) /
            stepSeries.length;
    final indexAvg = healthIndexSeries.isEmpty
        ? 0.0
        : healthIndexSeries
                .map((e) => e.value)
                .fold<double>(0, (a, b) => a + b) /
            healthIndexSeries.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dailyBarChartCard(
          title: 'Steps',
          icon: Icons.directions_walk,
          iconBg: C.green100,
          iconColor: C.green600,
          barColor: C.green400,
          todayBarColor: C.green500,
          accentColor: C.green600,
          series: stepSeries,
          subtitleRight: 'Avg ${fmtThousands(stepAvg)}/day',
          formatValue: (v) => v >= 1000
              ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
              : v.round().toString(),
          valueCeiling: null,
        ),
        SizedBox(height: 16),
        _dailyBarChartCard(
          title: 'Health Index',
          icon: Icons.favorite,
          iconBg: C.blue100,
          iconColor: C.blue600,
          barColor: C.blue400,
          todayBarColor: C.blue500,
          accentColor: C.blue600,
          series: healthIndexSeries,
          subtitleRight: 'Avg ${indexAvg.round()}/100',
          formatValue: (v) => v.round().toString(),
          valueCeiling: 100,
        ),
        SizedBox(height: 16),
        Row(
          children: [
            for (final days in _chartRanges) ...[
              if (days != _chartRanges.first) SizedBox(width: 8),
              Expanded(child: _rangeChip('$days days', days)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _dailyBarChartCard({
    required String title,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Color barColor,
    required Color todayBarColor,
    required Color accentColor,
    required List<({DateTime day, double value})> series,
    required String subtitleRight,
    required String Function(double v) formatValue,
    double? valueCeiling,
  }) {
    final values = series.map((e) => e.value).toList();
    final maxRaw = values.isEmpty
        ? 0.0
        : values.fold<double>(0, (a, b) => a > b ? a : b);
    final maxV = valueCeiling ?? (maxRaw <= 0 ? 1.0 : maxRaw);
    final today = DateTime.now().toLocal();
    final todayKey = DateTime(today.year, today.month, today.day);
    final showValueLabels = chartRangeDays <= 7;
    final showDayLabels = chartRangeDays <= 7;
    final first = series.isEmpty ? null : series.first.day;
    final last = series.isEmpty ? null : series.last.day;

    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: C.gray900,
                  ),
                ),
              ),
              Text(
                subtitleRight,
                style: TextStyle(fontSize: 12, color: C.gray400),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (loadingCharts)
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (showValueLabels) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in series)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          point.value <= 0 ? '' : formatValue(point.value),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _isSameDay(point.day, todayKey)
                                ? accentColor
                                : C.gray500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6),
            ],
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final point in series)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: chartRangeDays <= 7
                              ? 3
                              : chartRangeDays <= 30
                                  ? 1.5
                                  : 0.5,
                        ),
                        child: Builder(
                          builder: (context) {
                            final isToday = _isSameDay(point.day, todayKey);
                            final ratio =
                                maxV <= 0 ? 0.0 : (point.value / maxV);
                            final barH = point.value <= 0
                                ? 4.0
                                : (8.0 + ratio * 112).clamp(8.0, 120.0);
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: barH,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? todayBarColor
                                      : barColor.withValues(
                                          alpha:
                                              point.value <= 0 ? 0.25 : 0.85),
                                  borderRadius: BorderRadius.circular(
                                    chartRangeDays <= 7 ? 6 : 3,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (showDayLabels) ...[
              SizedBox(height: 10),
              Row(
                children: [
                  for (final point in series)
                    Expanded(
                      child: Text(
                        DateFormat('E').format(point.day),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _isSameDay(point.day, todayKey)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _isSameDay(point.day, todayKey)
                              ? accentColor
                              : C.gray500,
                        ),
                      ),
                    ),
                ],
              ),
            ] else if (first != null && last != null) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM d').format(first),
                    style: TextStyle(fontSize: 11, color: C.gray400),
                  ),
                  Text(
                    DateFormat('MMM d').format(last),
                    style: TextStyle(fontSize: 11, color: C.gray400),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _rangeChip(String label, int days) {
    final selected = chartRangeDays == days;
    return GestureDetector(
      onTap: loadingCharts ? null : () => _setChartRange(days),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.green50 : C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? C.green500 : C.gray200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? C.green600 : C.gray600,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = filter == value;
    return GestureDetector(
      onTap: () => setState(() => filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? C.navActiveBg : C.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? C.navActiveBorder : C.gray200),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? C.navActiveFg : C.gray600)),
      ),
    );
  }

  Widget _dateGroup(String date, List<HealthMetric> items, String sys) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Text(date.toUpperCase(),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: C.gray500,
                letterSpacing: 0.5)),
        SizedBox(height: 12),
        ...items.map((m) {
          final cfg = _configs[m.metricType];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(radius: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: cfg?.bg ?? C.gray100,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(cfg?.icon ?? Icons.monitor_heart,
                        size: 20, color: cfg?.color ?? C.gray500),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cfg?.label ?? m.metricType,
                            style: TextStyle(
                                fontWeight: FontWeight.w500, color: C.gray900)),
                        if (m.notes != null && m.notes!.isNotEmpty)
                          Text(m.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: C.gray400)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_value(m, sys),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: C.gray900)),
                      Text(_unit(m.metricType, sys),
                          style: TextStyle(fontSize: 12, color: C.gray400)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(64),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: C.gray100, shape: BoxShape.circle),
            child: Icon(Icons.calendar_today, color: C.gray400, size: 32),
          ),
          SizedBox(height: 16),
          Text('No metrics recorded yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: C.gray900)),
          SizedBox(height: 8),
          Text('Use the Log button on the dashboard to start tracking your health.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: C.gray500)),
        ],
      ),
    );
  }
}

Widget _pageHeader(String title, String subtitle) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: C.card,
      border: Border(bottom: BorderSide(color: C.cardBorder.withValues(alpha: 0.3))),
      boxShadow: C.glowShadow(),
    ),
    child: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 768),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: kBlueTealGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: C.glowShadow(blur: 8),
                  ),
                  child: Icon(Icons.favorite, color: C.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
                      SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 14, color: C.gray500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget pageHeader(String title, String subtitle) => _pageHeader(title, subtitle);
