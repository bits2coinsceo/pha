import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
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

const _configs = <String, _MetricConfig>{
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
  List<HealthMetric> metrics = [];
  bool loading = true;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user!.id;
    final rows = await Db.instance.raw.query('health_metrics',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'recorded_at DESC', limit: 100);
    setState(() {
      metrics = rows.map(HealthMetric.fromRow).toList();
      loading = false;
    });
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
    final disp = toDisplayValue(m.metricType, m.value, sys);
    if (m.metricType == 'steps') return fmtThousands(m.value);
    if (m.metricType == 'glucose') {
      return sys == 'imperial' ? disp.round().toString() : disp.toStringAsFixed(1);
    }
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

    return Scaffold(
      backgroundColor: C.gray50,
      body: Column(
        children: [
          _pageHeader('Health History', 'Your recorded health metrics over time'),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1152),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                          child: metrics.isEmpty
                              ? _empty()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _chip('All', 'all'),
                                        ...types.map((t) =>
                                            _chip(_configs[t]?.label ?? t, t)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                        '${filtered.length} record${filtered.length != 1 ? 's' : ''}',
                                        style: const TextStyle(
                                            fontSize: 14, color: C.gray400)),
                                    const SizedBox(height: 16),
                                    ...grouped.entries.map((e) => _dateGroup(e.key, e.value, sys)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
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
          color: selected ? C.blue500 : C.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? C.blue500 : C.gray200),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? C.white : C.gray600)),
      ),
    );
  }

  Widget _dateGroup(String date, List<HealthMetric> items, String sys) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(date.toUpperCase(),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: C.gray500,
                letterSpacing: 0.5)),
        const SizedBox(height: 12),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cfg?.label ?? m.metricType,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, color: C.gray900)),
                        if (m.notes != null && m.notes!.isNotEmpty)
                          Text(m.notes!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: C.gray400)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_value(m, sys),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: C.gray900)),
                      Text(_unit(m.metricType, sys),
                          style: const TextStyle(fontSize: 12, color: C.gray400)),
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
            decoration: const BoxDecoration(color: C.gray100, shape: BoxShape.circle),
            child: const Icon(Icons.calendar_today, color: C.gray400, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('No metrics recorded yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: C.gray900)),
          const SizedBox(height: 8),
          const Text('Use the Log button on the dashboard to start tracking your health.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: C.gray500)),
        ],
      ),
    );
  }
}

Widget _pageHeader(String title, String subtitle) {
  return Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: C.white,
      border: Border(bottom: BorderSide(color: C.gray100)),
      boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1152),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 14, color: C.gray500)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget pageHeader(String title, String subtitle) => _pageHeader(title, subtitle);
