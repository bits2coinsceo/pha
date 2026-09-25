import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../daily_metric_store.dart';
import '../l10n/l10n_ext.dart';
import '../meal_calories.dart';
import '../medical_guidelines.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _chartRanges = [7, 30, 90];

  List<({DateTime day, double value})> stepSeries = const [];
  List<({DateTime day, double value})> healthIndexSeries = const [];
  List<({DateTime day, double value})> calorieSeries = const [];
  List<({DateTime day, double value})> mealIntakeSeries = const [];
  List<({DateTime day, double value})> heartRateSeries = const [];
  List<({DateTime day, double value})> glucoseSeries = const [];
  List<({DateTime day, double value})> bpSystolicSeries = const [];
  List<({DateTime day, double value})> bpDiastolicSeries = const [];
  int chartRangeDays = 7;
  bool loading = true;
  bool loadingCharts = false;

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
    final heartRate = await _loadHeartRateSeries(userId, days);
    final glucose = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'glucose',
      days: days,
    );
    final bpSys = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'blood_pressure_systolic',
      days: days,
    );
    final bpDia = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'blood_pressure_diastolic',
      days: days,
    );
    if (!mounted) return;
    setState(() {
      stepSeries = steps;
      healthIndexSeries = index;
      calorieSeries = calories;
      mealIntakeSeries = mealIntake;
      heartRateSeries = heartRate;
      glucoseSeries = glucose;
      bpSystolicSeries = bpSys;
      bpDiastolicSeries = bpDia;
      chartRangeDays = days;
      loadingCharts = false;
    });
  }

  /// Prefer daily avg heart rate from the device; fall back to resting HR.
  Future<List<({DateTime day, double value})>> _loadHeartRateSeries(
    String userId,
    int days,
  ) async {
    final avg = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'heart_rate_avg',
      days: days,
    );
    final resting = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'resting_heart_rate',
      days: days,
    );
    return List.generate(days, (i) {
      final a = avg[i].value;
      final r = resting[i].value;
      return (day: avg[i].day, value: a > 0 ? a : r);
    });
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user!.id;
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
    final heartRate = await _loadHeartRateSeries(userId, chartRangeDays);
    final glucose = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'glucose',
      days: chartRangeDays,
    );
    final bpSys = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'blood_pressure_systolic',
      days: chartRangeDays,
    );
    final bpDia = await DailyMetricStore.lastNCalendarDays(
      userId: userId,
      metricType: 'blood_pressure_diastolic',
      days: chartRangeDays,
    );
    if (!mounted) return;
    setState(() {
      stepSeries = steps;
      healthIndexSeries = index;
      calorieSeries = calories;
      mealIntakeSeries = mealIntake;
      heartRateSeries = heartRate;
      glucoseSeries = glucose;
      bpSystolicSeries = bpSys;
      bpDiastolicSeries = bpDia;
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sys = context.watch<AuthProvider>().unitSystem;

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
                          child: _stepTrendChart(l10n, sys),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
    );
  }

  Widget _stepTrendChart(AppLocalizations l10n, String sys) {
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
        heartRateSeries.where((e) => e.value > 0).map((e) => e.value).toList();
    final heartRateAvg = restingVals.isEmpty
        ? 0.0
        : restingVals.fold<double>(0, (a, b) => a + b) / restingVals.length;

    final glucoseDisplay = glucoseSeries
        .map((e) => (
              day: e.day,
              value: e.value <= 0 ? 0.0 : toDisplayValue('glucose', e.value, sys),
            ))
        .toList();
    final glucoseVals =
        glucoseDisplay.where((e) => e.value > 0).map((e) => e.value).toList();
    final glucoseAvg = glucoseVals.isEmpty
        ? 0.0
        : glucoseVals.fold<double>(0, (a, b) => a + b) / glucoseVals.length;

    final bpSysVals =
        bpSystolicSeries.where((e) => e.value > 0).map((e) => e.value).toList();
    final bpDiaVals =
        bpDiastolicSeries.where((e) => e.value > 0).map((e) => e.value).toList();
    final bpSysAvg = bpSysVals.isEmpty
        ? 0.0
        : bpSysVals.fold<double>(0, (a, b) => a + b) / bpSysVals.length;
    final bpDiaAvg = bpDiaVals.isEmpty
        ? 0.0
        : bpDiaVals.fold<double>(0, (a, b) => a + b) / bpDiaVals.length;

    final glucoseUnit = getMetricUnit('glucose', sys);

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
          series: heartRateSeries,
          subtitleRight: heartRateAvg > 0
              ? l10n.hrAvgResting(heartRateAvg.round())
              : l10n.hrNoChartData,
          formatValue: (v) => v <= 0 ? '—' : v.round().toString(),
          valueCeiling: _restingHrCeiling(heartRateSeries),
          colorForValue: _restingHrBarColor,
          legend: _restingHrLegend(l10n),
        ),
        SizedBox(height: 16),
        _dailyBarChartCard(
          title: l10n.bloodGlucose,
          localeTag: localeTag,
          icon: Icons.water_drop,
          iconBg: C.red100,
          iconColor: C.red600,
          barColor: C.red400,
          todayBarColor: C.red500,
          accentColor: C.red600,
          series: glucoseDisplay,
          subtitleRight: glucoseAvg > 0
              ? l10n.historyGlucoseAvg(
                  sys == 'imperial'
                      ? glucoseAvg.round().toString()
                      : glucoseAvg.toStringAsFixed(1),
                  glucoseUnit,
                )
              : l10n.hrNoChartData,
          formatValue: (v) {
            if (v <= 0) return '—';
            return sys == 'imperial'
                ? v.round().toString()
                : v.toStringAsFixed(1);
          },
          valueCeiling: _glucoseCeiling(glucoseDisplay, sys),
          colorForValue: (v) => _glucoseBarColor(v, sys),
          legend: _glucoseLegend(l10n, sys),
        ),
        SizedBox(height: 16),
        _dailyBarChartCard(
          title: l10n.bloodPressure,
          localeTag: localeTag,
          icon: Icons.monitor_heart,
          iconBg: C.purple100,
          iconColor: C.purple600,
          barColor: C.purple600.withValues(alpha: 0.55),
          todayBarColor: C.purple600,
          accentColor: C.purple600,
          series: bpSystolicSeries,
          subtitleRight: bpSysAvg > 0
              ? l10n.historyBpAvg(
                  bpSysAvg.round(),
                  bpDiaAvg > 0 ? bpDiaAvg.round() : 0,
                )
              : l10n.hrNoChartData,
          formatValue: (v) => v <= 0 ? '—' : v.round().toString(),
          valueCeiling: _bpCeiling(bpSystolicSeries),
          colorForValue: _bpBarColor,
          legend: _bpLegend(l10n),
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
    return _chartLegend(items);
  }

  double _glucoseCeiling(
    List<({DateTime day, double value})> series,
    String sys,
  ) {
    final fallback = sys == 'imperial' ? 180.0 : 10.0;
    var maxRaw = fallback;
    for (final e in series) {
      if (e.value > maxRaw) maxRaw = e.value;
    }
    return sys == 'imperial'
        ? ((maxRaw / 10).ceil() * 10).toDouble()
        : ((maxRaw * 2).ceil() / 2).toDouble();
  }

  Color _glucoseBarColor(double displayValue, String sys) {
    if (displayValue <= 0) return C.gray300;
    final mgdl = sys == 'imperial'
        ? displayValue
        : mmolToMgdl(displayValue);
    if (mgdl < MedicalGuidelines.glucoseHypoMax) return C.amber500;
    if (mgdl <= MedicalGuidelines.glucoseNormalMax) return C.green500;
    if (mgdl <= MedicalGuidelines.glucosePrediabetesMax) return C.amber500;
    return C.red500;
  }

  Widget _glucoseLegend(AppLocalizations l10n, String sys) {
    if (sys == 'imperial') {
      return _chartLegend([
        (C.green500, l10n.historyGlucoseZoneNormalImperial),
        (C.amber500, l10n.historyGlucoseZoneAttention),
        (C.red500, l10n.historyGlucoseZoneHigh),
      ]);
    }
    return _chartLegend([
      (C.green500, l10n.historyGlucoseZoneNormalMetric),
      (C.amber500, l10n.historyGlucoseZoneAttention),
      (C.red500, l10n.historyGlucoseZoneHigh),
    ]);
  }

  double _bpCeiling(List<({DateTime day, double value})> series) {
    var maxRaw = 160.0;
    for (final e in series) {
      if (e.value > maxRaw) maxRaw = e.value;
    }
    return ((maxRaw / 10).ceil() * 10).toDouble();
  }

  Color _bpBarColor(double sys) {
    if (sys <= 0) return C.gray300;
    if (sys < 90) return C.amber500;
    if (sys <= 120) return C.green500;
    if (sys <= 139) return C.amber500;
    return C.red500;
  }

  Widget _bpLegend(AppLocalizations l10n) {
    return _chartLegend([
      (C.green500, l10n.historyBpZoneNormal),
      (C.amber500, l10n.historyBpZoneElevated),
      (C.red500, l10n.historyBpZoneHigh),
    ]);
  }

  Widget _chartLegend(List<(Color, String)> items) {
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
