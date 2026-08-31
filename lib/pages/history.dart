import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../daily_metric_store.dart';
import '../db.dart';
import '../l10n/l10n_ext.dart';
import '../meal_calories.dart';
import '../medical_guidelines.dart';
import '../models.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';

class _MetricConfig {
  final String Function(AppLocalizations l10n) labelOf;
  final IconData icon;
  final Color color;
  final Color bg;
  const _MetricConfig(this.labelOf, this.icon, this.color, this.bg);
}

Map<String, _MetricConfig> get _configs => {
  'steps': _MetricConfig((l) => l.steps, Icons.directions_walk, C.green600, C.green100),
  'calories': _MetricConfig((l) => l.calories, Icons.local_fire_department, C.orange600, C.orange100),
  'distance': _MetricConfig((l) => l.distance, Icons.place, C.blue600, C.blue100),
  'active_time': _MetricConfig((l) => l.activeTime, Icons.access_time, C.teal600, C.teal100),
  'weight': _MetricConfig((l) => l.weight, Icons.favorite, C.rose600, C.rose100),
  'water': _MetricConfig((l) => l.water, Icons.water_drop, C.sky600, C.sky100),
  'glucose': _MetricConfig((l) => l.bloodGlucose, Icons.water_drop, C.red600, C.red100),
  'blood_pressure_systolic':
      _MetricConfig((l) => l.bpSystolic, Icons.monitor_heart, C.purple600, C.purple100),
  'blood_pressure_diastolic':
      _MetricConfig((l) => l.bpDiastolic, Icons.monitor_heart, C.pink600, C.pink100),
  'heart_rate':
      _MetricConfig((l) => l.hrCurrent, Icons.favorite, C.rose600, C.rose50),
  'resting_heart_rate':
      _MetricConfig((l) => l.hrResting, Icons.favorite, C.rose600, C.rose50),
  'walking_heart_rate':
      _MetricConfig((l) => l.hrWalking, Icons.directions_walk, C.rose600, C.rose50),
  'heart_rate_avg':
      _MetricConfig((l) => l.hrAvg, Icons.favorite_border, C.rose600, C.rose50),
  'hrv_sdnn':
      _MetricConfig((l) => l.hrHrv, Icons.graphic_eq, C.teal600, C.teal50),
  'irregular_rhythm':
      _MetricConfig((l) => l.hrIrregularRhythm, Icons.warning_amber_rounded, C.red600, C.red100),
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
  List<({DateTime day, double value})> calorieSeries = const [];
  List<({DateTime day, double value})> mealIntakeSeries = const [];
  List<({DateTime day, double value})> restingHrSeries = const [];
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
    final calories = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'calories',
      days: days,
    );
    final mealIntake = await MealCalorieService.lastNCalendarDaysIntake(
      userId: userId,
      days: days,
    );
    final restingHr = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'resting_heart_rate',
      days: days,
    );
    if (!mounted) return;
    setState(() {
      stepSeries = steps;
      healthIndexSeries = index;
      calorieSeries = calories;
      mealIntakeSeries = mealIntake;
      restingHrSeries = restingHr;
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
    final calories = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'calories',
      days: chartRangeDays,
    );
    final mealIntake = await MealCalorieService.lastNCalendarDaysIntake(
      userId: userId,
      days: chartRangeDays,
    );
    final restingHr = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'resting_heart_rate',
      days: chartRangeDays,
    );
    if (!mounted) return;
    setState(() {
      metrics = filtered;
      stepSeries = steps;
      healthIndexSeries = index;
      calorieSeries = calories;
      mealIntakeSeries = mealIntake;
      restingHrSeries = restingHr;
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

  String _unit(String type, String sys, AppLocalizations l10n) {
    switch (type) {
      case 'steps':
        return l10n.unitSteps;
      case 'calories':
        return l10n.unitKcal;
      case 'active_time':
        return l10n.unitMin;
      case 'water':
        return l10n.unitMl;
      case 'blood_pressure_systolic':
      case 'blood_pressure_diastolic':
        return l10n.unitMmhg;
      case 'heart_rate':
      case 'resting_heart_rate':
      case 'walking_heart_rate':
      case 'heart_rate_avg':
        return l10n.unitBpm;
      case 'hrv_sdnn':
        return l10n.unitMs;
      case 'irregular_rhythm':
        return l10n.hrEvents;
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
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final sys = context.watch<AuthProvider>().unitSystem;
    final filtered =
        filter == 'all' ? metrics : metrics.where((m) => m.metricType == filter).toList();
    final types = metrics.map((m) => m.metricType).toSet().toList();

    final grouped = <String, List<HealthMetric>>{};
    for (final m in filtered) {
      final key = DateFormat('EEEE, MMMM d, y', locale)
          .format(m.recordedAt.toLocal());
      grouped.putIfAbsent(key, () => []).add(m);
    }

    return Column(
        children: [
          _pageHeader(l10n.historyTitle, l10n.historySubtitle),
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
                              _stepTrendChart(l10n),
                              SizedBox(height: 24),
                              if (metrics.isEmpty)
                                _empty(l10n)
                              else ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _chip(l10n.allFilter, 'all'),
                                    ...types.map((t) => _chip(
                                        _configs[t]?.labelOf(l10n) ?? t, t)),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Text(
                                    filtered.length == 1
                                        ? l10n.recordCountOne
                                        : l10n.recordsCount(filtered.length),
                                    style: TextStyle(
                                        fontSize: 14, color: C.gray400)),
                                SizedBox(height: 16),
                                ...grouped.entries.map(
                                    (e) => _dateGroup(e.key, e.value, sys, l10n)),
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

  Widget _stepTrendChart(AppLocalizations l10n) {
    final localeTag = l10n.localeName;
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
    final calorieAvg = calorieSeries.isEmpty
        ? 0.0
        : calorieSeries.map((e) => e.value).fold<double>(0, (a, b) => a + b) /
            calorieSeries.length;
    final mealAvg = mealIntakeSeries.isEmpty
        ? 0.0
        : mealIntakeSeries
                .map((e) => e.value)
                .fold<double>(0, (a, b) => a + b) /
            mealIntakeSeries.length;
    final restingVals =
        restingHrSeries.where((e) => e.value > 0).map((e) => e.value).toList();
    final restingHrAvg = restingVals.isEmpty
        ? 0.0
        : restingVals.fold<double>(0, (a, b) => a + b) / restingVals.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dailyBarChartCard(
          title: l10n.stepsChartTitle,
          localeTag: localeTag,
          icon: Icons.directions_walk,
          iconBg: C.green100,
          iconColor: C.green600,
          barColor: C.green400,
          todayBarColor: C.green500,
          accentColor: C.green600,
          series: stepSeries,
          subtitleRight: l10n.stepsAvgPerDay(fmtThousands(stepAvg)),
          formatValue: (v) => v >= 1000
              ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
              : v.round().toString(),
          valueCeiling: null,
        ),
        SizedBox(height: 16),
        _dailyBarChartCard(
          title: l10n.healthIndex,
          localeTag: localeTag,
          icon: Icons.favorite,
          iconBg: C.blue100,
          iconColor: C.blue600,
          barColor: C.blue400,
          todayBarColor: C.blue500,
          accentColor: C.blue600,
          series: healthIndexSeries,
          subtitleRight: l10n.healthIndexAvgScore(indexAvg.round()),
          formatValue: (v) => v.round().toString(),
          valueCeiling: 100,
        ),
        SizedBox(height: 16),
        _dailyBarChartCard(
          title: l10n.calories,
          localeTag: localeTag,
          icon: Icons.local_fire_department,
          iconBg: C.orange100,
          iconColor: C.orange600,
          barColor: C.orange400,
          todayBarColor: C.orange500,
          accentColor: C.orange600,
          series: calorieSeries,
          subtitleRight: l10n.stepsAvgPerDay(fmtThousands(calorieAvg)),
          formatValue: (v) => v >= 1000
              ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
              : v.round().toString(),
          valueCeiling: null,
        ),
        SizedBox(height: 16),
        _dailyBarChartCard(
          title: l10n.mealIntakeChartTitle,
          localeTag: localeTag,
          icon: Icons.restaurant,
          iconBg: C.amber100,
          iconColor: C.amber600,
          barColor: C.green500,
          todayBarColor: C.green500,
          accentColor: C.amber600,
          series: mealIntakeSeries,
          subtitleRight: l10n.stepsAvgPerDay(fmtThousands(mealAvg)),
          formatValue: (v) => v >= 1000
              ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k'
              : v.round().toString(),
          valueCeiling: _mealIntakeCeiling(mealIntakeSeries),
          colorForValue: _mealIntakeBarColor,
          legend: _mealIntakeLegend(l10n),
        ),
        SizedBox(height: 16),
        _dailyBarChartCard(
          title: l10n.hrRestingChartTitle,
          localeTag: localeTag,
          icon: Icons.favorite,
          iconBg: C.rose50,
          iconColor: C.rose600,
          barColor: C.green500,
          todayBarColor: C.green500,
          accentColor: C.rose600,
          series: restingHrSeries,
          subtitleRight: restingHrAvg > 0
              ? l10n.hrAvgResting(restingHrAvg.round())
              : l10n.hrNoChartData,
          formatValue: (v) => v <= 0 ? '—' : v.round().toString(),
          valueCeiling: _restingHrCeiling(restingHrSeries),
          colorForValue: _restingHrBarColor,
          legend: _restingHrLegend(l10n),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            for (final days in _chartRanges) ...[
              if (days != _chartRanges.first) SizedBox(width: 8),
              Expanded(
                child: _rangeChip(
                  days == 7
                      ? l10n.days7
                      : days == 30
                          ? l10n.days30
                          : l10n.days90,
                  days,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _dailyBarChartCard({
    required String title,
    required String localeTag,
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
    Color Function(double value)? colorForValue,
    Widget? legend,
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
                                ? (colorForValue?.call(point.value) ??
                                    accentColor)
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
                            final zoneColor = colorForValue?.call(point.value);
                            final fill = zoneColor ??
                                (isToday
                                    ? todayBarColor
                                    : barColor.withValues(
                                        alpha:
                                            point.value <= 0 ? 0.25 : 0.85));
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: barH,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: zoneColor != null && point.value <= 0
                                      ? zoneColor.withValues(alpha: 0.25)
                                      : fill,
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
                        DateFormat('E', localeTag).format(point.day),
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
                    DateFormat('MMM d', localeTag).format(first),
                    style: TextStyle(fontSize: 11, color: C.gray400),
                  ),
                  Text(
                    DateFormat('MMM d', localeTag).format(last),
                    style: TextStyle(fontSize: 11, color: C.gray400),
                  ),
                ],
              ),
            ],
            if (legend != null) ...[
              SizedBox(height: 14),
              legend,
            ],
          ],
        ],
      ),
    );
  }

  double _mealIntakeCeiling(List<({DateTime day, double value})> series) {
    final maxRaw = series.isEmpty
        ? 0.0
        : series.map((e) => e.value).fold<double>(0, (a, b) => a > b ? a : b);
    return maxRaw < MedicalGuidelines.mealIntakeModerateMaxKcal
        ? MedicalGuidelines.mealIntakeModerateMaxKcal.toDouble()
        : maxRaw;
  }

  Color _mealIntakeBarColor(double kcal) {
    switch (MealCalorieService.intakeZone(kcal)) {
      case 'deficit':
        return C.green500;
      case 'moderate':
        return C.amber500;
      case 'surplus':
        return C.red500;
      default:
        return C.gray300;
    }
  }

  Widget _mealIntakeLegend(AppLocalizations l10n) {
    final deficit = MedicalGuidelines.mealIntakeDeficitMaxKcal;
    final moderate = MedicalGuidelines.mealIntakeModerateMaxKcal;
    final items = [
      (C.green500, l10n.mealZoneDeficit(deficit)),
      (C.amber500, l10n.mealZoneModerate(deficit, moderate)),
      (C.red500, l10n.mealZoneSurplus(moderate)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: item.$1,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12,
                      color: C.gray500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  double _restingHrCeiling(List<({DateTime day, double value})> series) {
    var maxRaw = MedicalGuidelines.restingHrMax.toDouble() + 20;
    for (final e in series) {
      if (e.value > maxRaw) maxRaw = e.value;
    }
    return maxRaw < 100 ? 100 : ((maxRaw / 10).ceil() * 10).toDouble();
  }

  Color _restingHrBarColor(double bpm) {
    if (bpm <= 0) return C.gray300;
    if (bpm < MedicalGuidelines.restingHrMin - 10 ||
        bpm >= MedicalGuidelines.restingHrElevatedHigh) {
      return C.red500;
    }
    if (bpm < MedicalGuidelines.restingHrMin ||
        bpm >= MedicalGuidelines.restingHrElevatedCutOff) {
      return C.amber500;
    }
    return C.green500;
  }

  Widget _restingHrLegend(AppLocalizations l10n) {
    final low = MedicalGuidelines.restingHrMin;
    final high = MedicalGuidelines.restingHrMax;
    final items = [
      (C.green500, l10n.hrZoneNormal(low, high)),
      (C.amber500, l10n.hrZoneAttention),
      (C.red500, l10n.hrZoneRisk),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: item.$1,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12,
                      color: C.gray500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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

  Widget _dateGroup(
      String date, List<HealthMetric> items, String sys, AppLocalizations l10n) {
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
                        Text(cfg?.labelOf(l10n) ?? m.metricType,
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
                      Text(_unit(m.metricType, sys, l10n),
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

  Widget _empty(AppLocalizations l10n) {
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
          Text(l10n.noMetricsYet,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: C.gray900)),
          SizedBox(height: 8),
          Text(l10n.noMetricsHint,
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
