import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../daily_vitals.dart';
import '../db.dart';
import '../modals/quick_action_modals.dart';
import '../models.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';

class Dashboard extends StatefulWidget {
  final VoidCallback onOpenUpload;
  final VoidCallback onOpenAIChat;
  final VoidCallback onOpenStressTest;
  final VoidCallback onOpenLogMetric;
  final VoidCallback onOpenPsychoTest;
  final VoidCallback onUpgrade;

  const Dashboard({
    super.key,
    required this.onOpenUpload,
    required this.onOpenAIChat,
    required this.onOpenStressTest,
    required this.onOpenLogMetric,
    required this.onOpenPsychoTest,
    required this.onUpgrade,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int healthIndex = 84;
  int steps = 7842;
  num calories = 320;
  double distance = 5.6;
  int activeTime = 56;
  double? systolic, diastolic, glucose, weight, height;
  int? age;
  String displayName = '';
  int uploadCount = 0;
  int aiConsultCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String get _userId => context.read<AuthProvider>().user!.id;

  Future<void> _loadAll() async {
    await _loadHealthData();
    await _loadCreditCounts();
    if (mounted) setState(() {});
    await _maybePromptDailyVitals();
  }

  Future<void> _maybePromptDailyVitals() async {
    final needBp = await DailyVitalsService.shouldPromptBp(_userId);
    final needGlucose = await DailyVitalsService.shouldPromptGlucose(_userId);
    if (!needBp && !needGlucose) return;
    if (!mounted) return;

    final unit = context.read<AuthProvider>().unitSystem;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => DailyVitalsDialog(
        needBp: needBp,
        needGlucose: needGlucose,
        unitSystem: unit,
      ),
    );
    if (saved == true && mounted) await _loadHealthData();
    if (mounted) setState(() {});
  }

  Future<void> _loadCreditCounts() async {
    final db = Db.instance.raw;
    final u = await db.rawQuery(
        'SELECT COUNT(*) c FROM analysis_uploads WHERE user_id = ?', [_userId]);
    final a = await db.rawQuery(
        'SELECT COUNT(*) c FROM ai_consultations WHERE user_id = ?', [_userId]);
    uploadCount = (u.first['c'] as num).toInt();
    aiConsultCount = (a.first['c'] as num).toInt();
  }

  Future<void> _loadHealthData() async {
    final db = Db.instance.raw;
    final metrics = await db.query('health_metrics',
        columns: ['metric_type', 'value'],
        where: 'user_id = ?',
        whereArgs: [_userId],
        orderBy: 'recorded_at DESC',
        limit: 20);
    final seen = <String>{};
    for (final m in metrics) {
      final t = m['metric_type'] as String;
      if (seen.contains(t)) continue;
      seen.add(t);
      final v = (m['value'] as num).toDouble();
      switch (t) {
        case 'steps':
          steps = v.toInt();
        case 'calories':
          calories = v;
        case 'distance':
          distance = v;
        case 'active_time':
          activeTime = v.toInt();
        case 'blood_pressure_systolic':
          systolic = v;
        case 'blood_pressure_diastolic':
          diastolic = v;
        case 'glucose':
          glucose = v;
        case 'weight':
          weight = v;
      }
    }
    final idx = await db.query('health_index',
        columns: ['score'],
        where: 'user_id = ?',
        whereArgs: [_userId],
        orderBy: 'calculated_at DESC',
        limit: 1);
    if (idx.isNotEmpty) healthIndex = (idx.first['score'] as num).toInt();

    final profile = await db.query('profiles', where: 'id = ?', whereArgs: [_userId]);
    if (profile.isNotEmpty) {
      final p = profile.first;
      displayName = (p['display_name'] as String?) ?? '';
      age = (p['age'] as num?)?.toInt();
      height = (p['height'] as num?)?.toDouble();
      weight ??= (p['weight'] as num?)?.toDouble();
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isPlus = auth.isPlus;
    final unit = auth.unitSystem;
    final firstName = displayName.isNotEmpty
        ? displayName.split(' ').first
        : (auth.user?.email.split('@').first ?? '');

    final glucoseFmt = formatGlucose(glucose, unit);
    final weightFmt = formatWeight(weight, unit);
    final heightFmt = formatHeight(height, unit);
    final distanceFmt = formatDistance(distance, unit);
    final bpValue =
        systolic != null && diastolic != null ? '${systolic!.toInt()}/${diastolic!.toInt()}' : '—';

    final actions = [
      QuickAction(
        title: 'Upload Analysis',
        description: 'Analyze PDFs or photos',
        icon: Icons.upload_file,
        color: C.blue600,
        bgColor: C.blue50,
        credits: isPlus ? null : (used: uploadCount, total: 2),
        onTap: widget.onOpenUpload,
      ),
      QuickAction(
        title: 'AI Consultation',
        description: 'Chat with Ai Doc',
        icon: Icons.chat_bubble_outline,
        color: C.teal600,
        bgColor: C.teal50,
        credits: isPlus ? null : (used: aiConsultCount, total: 3),
        onTap: widget.onOpenAIChat,
      ),
      QuickAction(
        title: 'Wellness Check',
        description: 'Check your wellbeing',
        icon: Icons.psychology,
        color: C.sky600,
        bgColor: C.sky50,
        onTap: widget.onOpenStressTest,
      ),
      QuickAction(
        title: 'PsychoTest',
        description: 'Stress & psychosomatic assessment',
        icon: Icons.science_outlined,
        color: C.teal600,
        bgColor: C.teal50,
        locked: !isPlus,
        onTap: widget.onOpenPsychoTest,
      ),
      QuickAction(
        title: 'Family Health\nTracking',
        description: 'Add your family to track their health',
        icon: Icons.group,
        color: C.emerald600,
        bgColor: C.emerald50,
        comingSoon: true,
        onTap: () {},
      ),
    ];

    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    final healthMetrics = [
      ChartData('Age', age != null ? '$age' : '—', 'yrs', C.orange500, const []),
      ChartData('Height', heightFmt.value, heightFmt.unit, C.sky500, const []),
      ChartData('Weight', weightFmt.value, weightFmt.unit, C.blue500,
          weight != null ? [weight!] : const []),
      ChartData('Blood Pressure', bpValue, 'mmHg', C.green500,
          systolic != null && diastolic != null ? [systolic!] : const []),
      ChartData('Glucose', glucoseFmt.value, glucoseFmt.unit, C.red500,
          glucose != null ? [glucose!] : const []),
      ChartData('Steps', fmtThousands(steps), 'steps', C.teal500,
          [7500, 7600, 7700, 7800, steps.toDouble()]),
    ];

    return Column(
      children: [
        _header(),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 768),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(today,
                              style: TextStyle(fontSize: 14, color: C.gray500)),
                          if (auth.user != null)
                            Expanded(
                              child: Text(auth.user!.email,
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: C.gray500,
                                      fontWeight: FontWeight.w500)),
                            ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text('${_greeting()}${firstName.isNotEmpty ? ', $firstName' : ''}!',
                          style: TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold, color: C.gray900)),
                      SizedBox(height: 3),
                      Text("Here's your health overview for today.",
                          style: TextStyle(color: C.gray500)),
                      SizedBox(height: 26),
                      HealthIndexCard(
                        score: healthIndex,
                        status: 'good',
                        steps: steps,
                        stepsGoal: 10000,
                      ),
                      SizedBox(height: 20),
                      QuickActions(actions: actions, onUpgrade: widget.onUpgrade),
                      SizedBox(height: 20),
                      HealthMetricsChart(metrics: healthMetrics),
                      SizedBox(height: 20),
                      MetricsGrid(
                        calories: calories,
                        distance: double.tryParse(distanceFmt.value) ?? 0,
                        activeTime: activeTime,
                        distanceUnit: distanceFmt.unit,
                      ),
                      SizedBox(height: 20),
                      _privacyBanner(),
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

  Widget _header() {
    return Container(
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
                        Text('PHA',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18, color: C.gray900)),
                        Text('Personal Health Assistant',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: C.gray400)),
                      ],
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.notifications_outlined, size: 24, color: C.gray600),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration:
                              BoxDecoration(color: C.red500, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _privacyBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: kNebulaGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: C.glowShadow(blur: 16, alphaDark: 0.27, alphaLight: 0.1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: C.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.shield, color: C.white, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your health, our priority',
                    style: TextStyle(
                        color: C.white, fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  'Track, analyze and improve your health with PHA. Your data stays private and secure.',
                  style: TextStyle(color: C.onGradientMuted, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
