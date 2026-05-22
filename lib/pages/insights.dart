import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../db.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'history.dart' show pageHeader;

class _StatusCfg {
  final String label;
  final Color bg, border, text, bar;
  const _StatusCfg(this.label, this.bg, this.border, this.text, this.bar);
}

const _statusCfg = <String, _StatusCfg>{
  'excellent': _StatusCfg('Excellent', C.green50, C.green200, C.teal700, C.green500),
  'good': _StatusCfg('Good', C.blue50, C.blue200, C.blue700, C.blue500),
  'fair': _StatusCfg('Fair', C.yellow50, C.yellow200, C.yellow700, C.yellow400),
  'needs_attention':
      _StatusCfg('Needs Attention', C.red50, C.red200, C.red700, C.red500),
};

class _FindingCfg {
  final IconData icon;
  final Color color, bg, border;
  const _FindingCfg(this.icon, this.color, this.bg, this.border);
}

const _findingCfg = <String, _FindingCfg>{
  'good': _FindingCfg(Icons.check_circle, C.green600, C.green50, C.green100),
  'info': _FindingCfg(Icons.info_outline, C.blue600, C.blue50, C.blue100),
  'warning': _FindingCfg(Icons.warning_amber, C.yellow600, C.yellow50, C.yellow100),
  'critical': _FindingCfg(Icons.error_outline, C.red600, C.red50, C.red100),
};

const _priorityDot = <String, Color>{
  'high': C.red500,
  'medium': C.yellow500,
  'low': C.green500,
};

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  List<StressTest> stressTests = [];
  List<HealthIndexEntry> healthIndexes = [];
  List<double> stepData = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user!.id;
    final db = Db.instance.raw;
    final stress = await db.query('stress_tests',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC', limit: 10);
    final idx = await db.query('health_index',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'calculated_at DESC', limit: 10);
    final steps = await db.query('health_metrics',
        columns: ['value'],
        where: 'user_id = ? AND metric_type = ?',
        whereArgs: [userId, 'steps'],
        orderBy: 'recorded_at ASC',
        limit: 14);
    setState(() {
      stressTests = stress.map(StressTest.fromRow).toList();
      healthIndexes = idx.map(HealthIndexEntry.fromRow).toList();
      stepData = steps.map((r) => (r['value'] as num).toDouble()).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final avgHealth = healthIndexes.isEmpty
        ? null
        : (healthIndexes.map((h) => h.score).reduce((a, b) => a + b) / healthIndexes.length)
            .round();
    final avgStress = stressTests.isEmpty
        ? null
        : (stressTests.map((t) => t.score).reduce((a, b) => a + b) / stressTests.length)
            .round();
    final healthValues = healthIndexes.reversed.map((h) => h.score).toList();
    final stressValues = stressTests.reversed.map((t) => t.score).toList();

    return Scaffold(
      backgroundColor: C.gray50,
      body: Column(
        children: [
          pageHeader('Health Insights', 'Trends and patterns from your health data'),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const HealthAnalysisCard(),
                        const SizedBox(height: 24),
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          _statCard(Icons.favorite, C.blue100, C.blue600,
                              'Avg Health Score', avgHealth, '/100', healthValues),
                          const SizedBox(height: 16),
                          _statCard(Icons.psychology, C.teal100, C.teal600,
                              'Avg Wellness Score', avgStress, '/100', stressValues),
                          const SizedBox(height: 16),
                          _stepStatCard(),
                          const SizedBox(height: 24),
                          _historyCard('Health Score History',
                              Icons.bar_chart, C.blue500, healthValues, true),
                          const SizedBox(height: 24),
                          _historyCard('Wellness Check History',
                              Icons.psychology, C.teal500, stressValues, false),
                          if (stepData.length > 1) ...[
                            const SizedBox(height: 24),
                            _stepActivityCard(),
                          ],
                          if (stressTests.isEmpty &&
                              healthIndexes.isEmpty &&
                              stepData.isEmpty) ...[
                            const SizedBox(height: 24),
                            _emptyInsights(),
                          ],
                        ],
                      ],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, Color iconBg, Color iconColor, String label, int? value,
      String suffix, List<num> trend) {
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
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: C.gray600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (value != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$value',
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.bold, color: C.gray900)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(suffix, style: const TextStyle(fontSize: 14, color: C.gray400)),
                ),
                const Spacer(),
                _trendIcon(trend),
              ],
            )
          else
            const Text('No data yet', style: TextStyle(fontSize: 14, color: C.gray400)),
        ],
      ),
    );
  }

  Widget _stepStatCard() {
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
                decoration:
                    BoxDecoration(color: C.green100, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.directions_walk, size: 16, color: C.green600),
              ),
              const SizedBox(width: 8),
              const Text('Step Trend',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: C.gray600)),
            ],
          ),
          const SizedBox(height: 12),
          if (stepData.isNotEmpty)
            Row(
              children: [
                Text(fmtThousands(stepData.last),
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.bold, color: C.gray900)),
                const Spacer(),
                _trendIcon(stepData),
              ],
            )
          else
            const Text('No data yet', style: TextStyle(fontSize: 14, color: C.gray400)),
        ],
      ),
    );
  }

  Widget _trendIcon(List<num> values) {
    if (values.length < 2) return const Icon(Icons.remove, size: 16, color: C.gray400);
    if (values.last > values.first) {
      return const Icon(Icons.trending_up, size: 16, color: C.green500);
    }
    if (values.last < values.first) {
      return const Icon(Icons.trending_down, size: 16, color: C.red500);
    }
    return const Icon(Icons.remove, size: 16, color: C.gray400);
  }

  Widget _scoreBadge(int score) {
    final color = score >= 70
        ? (C.teal700, C.green50, C.green200)
        : score >= 50
            ? (C.yellow600, C.yellow50, C.yellow200)
            : (C.red600, C.red50, C.red200);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.$2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.$3)),
      child: Text('$score/100',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.$1)),
    );
  }

  Widget _historyCard(String title, IconData icon, Color iconColor, List<num> values,
      bool isHealth) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: C.gray900)),
            ],
          ),
          const SizedBox(height: 16),
          if (values.isNotEmpty) ...[
            MiniBarChart(values: values, color: isHealth ? C.blue400 : C.teal400),
            const SizedBox(height: 16),
            ...(isHealth
                ? healthIndexes.take(5).map((h) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MMM d').format(h.calculatedAt.toLocal()),
                              style: const TextStyle(fontSize: 14, color: C.gray500)),
                          _scoreBadge(h.score),
                        ],
                      ),
                    ))
                : stressTests.take(5).map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('MMM d').format(t.createdAt.toLocal()),
                                  style: const TextStyle(fontSize: 14, color: C.gray500)),
                              Text(t.result,
                                  style: const TextStyle(fontSize: 12, color: C.gray400)),
                            ],
                          ),
                          _scoreBadge(t.score),
                        ],
                      ),
                    ))),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                    isHealth
                        ? 'No health index data recorded yet'
                        : 'No wellness checks yet. Try the Wellness Check on the home screen.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: C.gray400)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepActivityCard() {
    final minV = stepData.reduce((a, b) => a < b ? a : b);
    final maxV = stepData.reduce((a, b) => a > b ? a : b);
    final avg = stepData.reduce((a, b) => a + b) / stepData.length;
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_walk, size: 20, color: C.green500),
              const SizedBox(width: 8),
              const Text('Step Activity',
                  style: TextStyle(fontWeight: FontWeight.w600, color: C.gray900)),
              const Spacer(),
              Text('Last ${stepData.length} entries',
                  style: const TextStyle(fontSize: 12, color: C.gray400)),
            ],
          ),
          const SizedBox(height: 16),
          MiniBarChart(values: stepData, color: C.green400),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Min: ${fmtThousands(minV)}',
                  style: const TextStyle(fontSize: 12, color: C.gray400)),
              Text('Avg: ${fmtThousands(avg)}',
                  style: const TextStyle(fontSize: 12, color: C.gray400)),
              Text('Max: ${fmtThousands(maxV)}',
                  style: const TextStyle(fontSize: 12, color: C.gray400)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyInsights() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(64),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: C.gray100, shape: BoxShape.circle),
            child: const Icon(Icons.bar_chart, color: C.gray400, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('No insights yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: C.gray900)),
          const SizedBox(height: 8),
          const Text(
              'Start tracking your health metrics and completing wellness checks to see insights here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: C.gray500)),
        ],
      ),
    );
  }
}

// ── Health Analysis card ─────────────────────────────────────────────────────
class HealthAnalysisCard extends StatefulWidget {
  const HealthAnalysisCard({super.key});

  @override
  State<HealthAnalysisCard> createState() => _HealthAnalysisCardState();
}

class _HealthAnalysisCardState extends State<HealthAnalysisCard> {
  HealthAnalysis? analysis;
  bool loading = true;
  bool running = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final userId = context.read<AuthProvider>().user!.id;
    analysis = await HealthAnalysisService.latest(userId);
    setState(() => loading = false);
  }

  Future<void> _run() async {
    final userId = context.read<AuthProvider>().user!.id;
    setState(() {
      running = true;
      error = '';
    });
    try {
      analysis = await HealthAnalysisService.run(userId);
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = analysis != null
        ? (_statusCfg[analysis!.overallStatus] ?? _statusCfg['good']!)
        : null;
    return Container(
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [C.blue500, C.teal500]),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.auto_awesome, color: C.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Health Analysis',
                          style: TextStyle(fontWeight: FontWeight.w600, color: C.gray900)),
                      Text('Personalized assessment of your metrics',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: C.gray400)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: running ? null : _run,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.blue500,
                    foregroundColor: C.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, size: 14),
                      const SizedBox(width: 6),
                      Text(running
                          ? 'Analyzing…'
                          : analysis != null
                              ? 'Re-analyze'
                              : 'Analyze',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: AppBanner(
                  text: error,
                  bg: C.red50,
                  border: C.red50,
                  fg: C.red600,
                  icon: Icons.error_outline),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (analysis == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration:
                        const BoxDecoration(color: C.gray100, shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome, color: C.gray400, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                      'No analysis yet. Press Analyze to get a personalized health conclusion based on your logged metrics.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: C.gray500)),
                ],
              ),
            )
          else
            _analysisBody(cfg!),
        ],
      ),
    );
  }

  Widget _analysisBody(_StatusCfg cfg) {
    final a = analysis!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cfg.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cfg.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cfg.label.toUpperCase(),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cfg.text,
                              letterSpacing: 0.5)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${a.overallScore}',
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: C.gray900)),
                          const Text('/100',
                              style: TextStyle(fontSize: 16, color: C.gray400)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cfg.bg,
                      shape: BoxShape.circle,
                      border: Border.all(color: cfg.border, width: 4),
                    ),
                    alignment: Alignment.center,
                    child: Text('${a.overallScore}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: cfg.text)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: a.overallScore / 100,
                  minHeight: 8,
                  backgroundColor: C.white,
                  valueColor: AlwaysStoppedAnimation(cfg.bar),
                ),
              ),
              const SizedBox(height: 12),
              Text(a.summary,
                  style: const TextStyle(fontSize: 14, color: C.gray700, height: 1.4)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Metric Findings',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: C.gray700)),
              const SizedBox(height: 12),
              ...a.findings.map((f) {
                final fc = _findingCfg[f.status]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fc.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: fc.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(fc.icon, size: 16, color: fc.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(f.category,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: C.gray800)),
                                  ),
                                  if (f.value != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: fc.bg,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: fc.border)),
                                      child: Text(f.value!,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: fc.color)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(f.message,
                                  style: const TextStyle(
                                      fontSize: 12, color: C.gray600, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (a.recommendations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recommendations',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: C.gray700)),
                const SizedBox(height: 12),
                ...a.recommendations.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: C.gray50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.gray100),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                  color: _priorityDot[r.priority] ?? C.gray400,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(r.text,
                                  style: const TextStyle(
                                      fontSize: 14, color: C.gray700, height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Text(
              'Last analyzed: ${DateFormat('MMM d, h:mm a').format(analysis!.analyzedAt.toLocal())}',
              style: const TextStyle(fontSize: 12, color: C.gray400)),
        ),
      ],
    );
  }
}
