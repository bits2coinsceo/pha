import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../db.dart';
import '../models.dart';
import '../services.dart';
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
  LastSync? lastSync;
  bool syncing = false;
  String syncError = '';
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
    await _loadLastSync();
    await _loadCreditCounts();
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

  Future<void> _loadLastSync() async {
    lastSync = await HealthConnectService.last(_userId);
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
    }
  }

  Future<void> _testSync() async {
    setState(() {
      syncing = true;
      syncError = '';
    });
    try {
      await HealthConnectService.sync(_userId, steps: 8500, distanceMeters: 6500);
      await _loadAll();
    } catch (e) {
      setState(() => syncError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => syncing = false);
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
        bgColor: C.blue100,
        credits: isPlus ? null : (used: uploadCount, total: 2),
        onTap: widget.onOpenUpload,
      ),
      QuickAction(
        title: 'AI Consultation',
        description: 'Chat with AI assistant',
        icon: Icons.chat_bubble_outline,
        color: C.teal600,
        bgColor: C.teal100,
        credits: isPlus ? null : (used: aiConsultCount, total: 3),
        onTap: widget.onOpenAIChat,
      ),
      QuickAction(
        title: 'Wellness Check',
        description: 'Check your wellbeing',
        icon: Icons.psychology,
        color: C.sky600,
        bgColor: C.sky100,
        onTap: widget.onOpenStressTest,
      ),
      QuickAction(
        title: 'PsychoTest',
        description: 'Stress & psychosomatic assessment',
        icon: Icons.science_outlined,
        color: C.teal600,
        bgColor: C.teal100,
        locked: !isPlus,
        onTap: widget.onOpenPsychoTest,
      ),
      QuickAction(
        title: 'Family Health Tracking',
        description: 'Add your family to track their health',
        icon: Icons.group,
        color: C.emerald600,
        bgColor: C.emerald100,
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

    return Scaffold(
      backgroundColor: C.gray50,
      body: Column(
        children: [
          _header(auth),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 768),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(today, style: const TextStyle(fontSize: 14, color: C.gray500)),
                        const SizedBox(height: 4),
                        Text('${_greeting()}${firstName.isNotEmpty ? ', $firstName' : ''}!',
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.bold, color: C.gray900)),
                        const SizedBox(height: 4),
                        const Text("Here's your health overview for today.",
                            style: TextStyle(color: C.gray500)),
                        const SizedBox(height: 32),
                        HealthIndexCard(score: healthIndex, status: 'good'),
                        const SizedBox(height: 24),
                        MetricsGrid(
                          calories: calories,
                          distance: double.tryParse(distanceFmt.value) ?? 0,
                          activeTime: activeTime,
                          distanceUnit: distanceFmt.unit,
                        ),
                        const SizedBox(height: 24),
                        StepsCard(current: steps, goal: 10000),
                        const SizedBox(height: 24),
                        _healthConnectCard(unit),
                        const SizedBox(height: 24),
                        _privacyBanner(),
                        const SizedBox(height: 24),
                        QuickActions(actions: actions, onUpgrade: widget.onUpgrade),
                        const SizedBox(height: 24),
                        HealthMetricsChart(metrics: healthMetrics),
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

  Widget _header(AuthProvider auth) {
    return Container(
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
              padding: EdgeInsets.fromLTRB(24, 16, logicalMm(5), 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                        BoxDecoration(color: C.blue500, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.favorite, color: C.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
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
                  const Spacer(),
                  if (auth.user != null) ...[
                    Flexible(
                      child: Text(auth.user!.email,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: C.gray500, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.notifications_outlined, size: 20, color: C.gray600),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: C.red500, shape: BoxShape.circle),
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

  Widget _healthConnectCard(String unit) {
    return Container(
      decoration: cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: C.green50, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.smartphone, color: C.green600, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Health Connect',
                      style: TextStyle(fontWeight: FontWeight.w600, color: C.gray900)),
                  Text('Android activity sync',
                      style: TextStyle(fontSize: 12, color: C.gray400)),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: syncing ? null : _testSync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.green500,
                  foregroundColor: C.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, size: 14),
                    const SizedBox(width: 6),
                    Text(syncing ? 'Syncing…' : 'Test Sync',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (syncError.isNotEmpty) ...[
            AppBanner(
                text: syncError,
                bg: C.red50,
                border: C.red50,
                fg: C.red600,
                icon: Icons.error_outline),
            const SizedBox(height: 12),
          ],
          if (lastSync != null)
            Row(
              children: [
                _syncStat('${lastSync!.steps}', 'steps'),
                const SizedBox(width: 12),
                _syncStat(formatDistance(lastSync!.distanceMeters / 1000, unit).value,
                    formatDistance(lastSync!.distanceMeters / 1000, unit).unit),
                const SizedBox(width: 12),
                _syncStat('${lastSync!.caloriesCalculated.toInt()}', 'kcal'),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No sync data yet. Press Test Sync.',
                    style: TextStyle(fontSize: 14, color: C.gray400)),
              ),
            ),
          if (lastSync != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: C.green500),
                const SizedBox(width: 6),
                Text(
                    'Last synced ${DateFormat('MMM d, h:mm a').format(lastSync!.syncedAt.toLocal())}',
                    style: const TextStyle(fontSize: 12, color: C.gray400)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _syncStat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(color: C.gray50, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: C.gray900)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 12, color: C.gray400)),
            ],
          ),
        ),
      );

  Widget _privacyBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [C.blue600, C.teal500]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: C.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.shield, color: C.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your health, our priority',
                    style: TextStyle(
                        color: C.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Track, analyze and improve your health with PHA. Your data stays private and secure.',
                  style: TextStyle(color: C.blue100, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
