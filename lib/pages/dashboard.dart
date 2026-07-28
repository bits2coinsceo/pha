import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../core/app_logger.dart';
import '../daily_metric_store.dart';
import '../daily_notifications.dart';
import '../daily_vitals.dart';
import '../db.dart';
import '../health_index.dart';
import '../medical_guidelines.dart';
import '../meal_calories.dart';
import '../modals/quick_action_modals.dart';
import '../physical_activity.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';

class Dashboard extends StatefulWidget {
  final VoidCallback onOpenUpload;
  final VoidCallback onOpenMealCalories;
  final VoidCallback onOpenAIChat;
  final VoidCallback onOpenStressTest;
  final VoidCallback onOpenBadHabits;
  final VoidCallback onOpenPhysicalActivity;
  final VoidCallback onOpenLogMetric;
  final VoidCallback onOpenPsychoTest;
  final VoidCallback onOpenTreatmentSchedule;
  final VoidCallback onUpgrade;
  final VoidCallback onOpenInsights;
  /// Bumped when telemetry/metrics change — reloads data without remounting.
  final int refreshToken;

  const Dashboard({
    super.key,
    required this.onOpenUpload,
    required this.onOpenMealCalories,
    required this.onOpenAIChat,
    required this.onOpenStressTest,
    required this.onOpenBadHabits,
    required this.onOpenPhysicalActivity,
    required this.onOpenLogMetric,
    required this.onOpenPsychoTest,
    required this.onOpenTreatmentSchedule,
    required this.onUpgrade,
    required this.onOpenInsights,
    this.refreshToken = 0,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int healthIndex = 72;
  String healthIndexStatus = 'good';
  int steps = 0;
  List<double> stepHistory = const [];
  num calories = 320;
  double distance = 5.6;
  int activeTime = 56;
  double? systolic, diastolic, glucose, weight, height;
  int? age;
  String displayName = '';
  int uploadCount = 0;
  int aiConsultCount = 0;
  int mealChecks24h = 0;
  int unreadNotifications = 0;
  bool _didInitialPrompt = false;

  @override
  void initState() {
    super.initState();
    _loadAll(promptVitals: true);
  }

  @override
  void didUpdateWidget(covariant Dashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      // Refresh metrics only — never re-open Today's vitals.
      unawaited(_loadAll(promptVitals: false));
    }
  }

  String get _userId => context.read<AuthProvider>().user!.id;

  Future<void> _loadAll({required bool promptVitals}) async {
    AppLogger.d('Dashboard loading…', category: LogCategory.dashboard);
    await _loadHealthData();
    await _loadCreditCounts();
    await _loadNotificationBadge();
    if (mounted) setState(() {});
    AppLogger.i(
      'Dashboard ready (index=$healthIndex, steps=$steps)',
      category: LogCategory.dashboard,
    );
    if (promptVitals && !_didInitialPrompt) {
      _didInitialPrompt = true;
      await _maybePromptDailyVitals();
      await _maybePromptPhysicalActivityCheckin();
    }
  }

  Future<void> _maybePromptPhysicalActivityCheckin() async {
    if (!await PhysicalActivityService.shouldPromptCheckin(_userId)) return;
    if (!mounted) return;
    final program = await PhysicalActivityService.activeProgram(_userId);
    if (program == null || !mounted) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PhysicalActivityCheckinDialog(
        userId: _userId,
        programLabel: program['program_label'] as String? ?? 'your program',
      ),
    );
  }

  Future<void> _loadNotificationBadge() async {
    unreadNotifications = await DailyNotificationService.unreadCount(_userId);
  }

  Future<void> _openNotifications() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => TodayNotificationsPanel(userId: _userId),
    );
    await DailyNotificationService.markAllReadToday(_userId);
    if (!mounted) return;
    // Refresh index in case check-in answers were saved inline.
    await _loadNotificationBadge();
    await _loadHealthData();
    if (mounted) setState(() {});
  }

  Future<void> _maybePromptDailyVitals() async {
    if (DailyVitalsService.promptDialogOpen) return;

    final needBp = await DailyVitalsService.shouldPromptBp(_userId);
    final needGlucose = await DailyVitalsService.shouldPromptGlucose(_userId);
    if (!needBp && !needGlucose) return;
    if (!mounted) return;

    // Claim today's slot immediately so a Dashboard remount cannot stack dialogs.
    DailyVitalsService.promptDialogOpen = true;
    await DailyVitalsService.claimPromptShown(
      _userId,
      bp: needBp,
      glucose: needGlucose,
    );

    if (!mounted) {
      DailyVitalsService.promptDialogOpen = false;
      return;
    }

    final unit = context.read<AuthProvider>().unitSystem;
    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => DailyVitalsDialog(
          needBp: needBp,
          needGlucose: needGlucose,
          unitSystem: unit,
        ),
      );
      if (saved == true && mounted) await _loadHealthData();
      if (mounted) setState(() {});
    } finally {
      DailyVitalsService.promptDialogOpen = false;
    }
  }

  Future<void> _loadCreditCounts() async {
    final db = Db.instance.raw;
    final u = await db.rawQuery(
        'SELECT COUNT(*) c FROM analysis_uploads WHERE user_id = ?', [_userId]);
    final a = await db.rawQuery(
        'SELECT COUNT(*) c FROM ai_consultations WHERE user_id = ?', [_userId]);
    mealChecks24h = await MealCalorieService.countLast24Hours(_userId);
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
    stepHistory = await DailyMetricStore.dailySeries(
      userId: _userId,
      metricType: 'steps',
      limit: 7,
    );
    final profile = await db.query('profiles', where: 'id = ?', whereArgs: [_userId]);
    if (profile.isNotEmpty) {
      final p = profile.first;
      displayName = (p['display_name'] as String?) ?? '';
      age = (p['age'] as num?)?.toInt();
      height = (p['height'] as num?)?.toDouble();
      weight ??= (p['weight'] as num?)?.toDouble();
    }

    try {
      final result = await HealthIndexService.recalculate(_userId);
      healthIndex = result.score;
      healthIndexStatus = result.status;
      AppLogger.d(
        'Health index recalculated: $healthIndex ($healthIndexStatus)',
        category: LogCategory.healthIndex,
      );
    } catch (e, st) {
      AppLogger.w(
        'Health index recalculate failed — using cached value',
        error: e,
        stackTrace: st,
        category: LogCategory.healthIndex,
      );
      final idx = await db.query('health_index',
          columns: ['score', 'status'],
          where: 'user_id = ?',
          whereArgs: [_userId],
          orderBy: 'calculated_at DESC',
          limit: 1);
      if (idx.isNotEmpty) {
        healthIndex = (idx.first['score'] as num).toInt();
        healthIndexStatus = (idx.first['status'] as String?) ?? 'good';
      }
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
    final trialLocked = !isPlus && auth.isTrialExpired;
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
        credits: isPlus || trialLocked ? null : (used: uploadCount, total: 2),
        locked: trialLocked,
        onTap: widget.onOpenUpload,
      ),
      QuickAction(
        title: 'AI Consultation',
        description: 'Chat with Ai Doc',
        icon: Icons.chat_bubble_outline,
        color: C.teal600,
        bgColor: C.teal50,
        credits: isPlus || trialLocked ? null : (used: aiConsultCount, total: 3),
        locked: trialLocked,
        onTap: widget.onOpenAIChat,
      ),
      QuickAction(
        title: 'Wellness Check',
        description: 'Check your wellbeing',
        icon: Icons.psychology,
        color: C.sky600,
        bgColor: C.sky50,
        locked: trialLocked,
        onTap: widget.onOpenStressTest,
      ),
      QuickAction(
        title: 'Check Your Bad Habits',
        description: 'Smoking, alcohol & screen time',
        icon: Icons.fact_check_outlined,
        color: C.rose600,
        bgColor: C.rose50,
        locked: !isPlus,
        onTap: widget.onOpenBadHabits,
      ),
      QuickAction(
        title: 'Start physical activity',
        description: 'Choose your daily workout program',
        icon: Icons.fitness_center_outlined,
        color: C.emerald600,
        bgColor: C.emerald50,
        locked: !isPlus,
        onTap: widget.onOpenPhysicalActivity,
      ),
      QuickAction(
        title: 'Check Meal Calories',
        description: 'Photo → calories & nutrition advice',
        icon: Icons.restaurant_outlined,
        color: C.orange600,
        bgColor: C.orange50,
        credits: isPlus || trialLocked
            ? null
            : (used: mealChecks24h, total: MealCalorieService.freeDailyLimit),
        locked: trialLocked,
        onTap: widget.onOpenMealCalories,
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
        title: 'Treatment Schedule',
        description: 'Medicines & supplements reminders',
        icon: Icons.medication_outlined,
        color: C.purple600,
        bgColor: C.purple100,
        locked: !isPlus,
        onTap: widget.onOpenTreatmentSchedule,
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
          weight != null ? [weight!.toDouble()] : const []),
      ChartData('Blood Pressure', bpValue, 'mmHg', C.green500,
          systolic != null && diastolic != null ? [systolic!.toDouble()] : const []),
      ChartData('Glucose', glucoseFmt.value, glucoseFmt.unit, C.red500,
          glucose != null ? [glucose!.toDouble()] : const []),
      ChartData('Steps', fmtThousands(steps), 'steps', C.teal500, stepHistory),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
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
                      const SizedBox(height: 2),
                      Text('${_greeting()}${firstName.isNotEmpty ? ', $firstName' : ''}!',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: C.gray900)),
                      const SizedBox(height: 2),
                      Text("Here's your health overview for today.",
                          style: TextStyle(color: C.gray500)),
                      const SizedBox(height: 16),
                      HealthIndexCard(
                        score: healthIndex,
                        status: healthIndexStatus,
                        steps: steps,
                        stepsGoal: MedicalGuidelines.stepsGoal,
                        onHealthIndexTap: widget.onOpenInsights,
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
    final auth = context.watch<AuthProvider>();
    final showTrialPill = !auth.isPlus &&
        auth.trialDaysRemaining != null &&
        auth.trialDaysRemaining! > 0;

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
                  if (showTrialPill) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: C.blue50,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: C.blue100),
                      ),
                      child: Text(
                        '7-day free trial',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: C.blue700,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  GestureDetector(
                    onTap: _openNotifications,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.notifications_outlined, size: 24, color: C.gray600),
                        if (unreadNotifications > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              decoration: BoxDecoration(
                                color: C.red500,
                                shape: BoxShape.circle,
                                border: Border.all(color: C.card, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
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
                  style: TextStyle(
                    color: C.white.withValues(alpha: 0.92),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
