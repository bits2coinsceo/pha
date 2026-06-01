import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth.dart';
import 'db.dart';
import 'onboarding_prefs.dart';
import 'profile_basics.dart';
import 'modals/psycho_test_modal.dart';
import 'modals/quick_action_modals.dart';
import 'pages/dashboard.dart';
import 'pages/history.dart';
import 'pages/insights.dart';
import 'pages/login.dart';
import 'pages/onboarding.dart';
import 'pages/profile.dart';
import 'telemetry_sync.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Db.instance.init();
  final auth = AuthProvider();
  await auth.bootstrap();
  runApp(
    ChangeNotifierProvider.value(value: auth, child: const PhaApp()),
  );
}

class PhaApp extends StatelessWidget {
  const PhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHA — Personal Health Assistant',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppContent(),
    );
  }
}

class AppContent extends StatefulWidget {
  const AppContent({super.key});

  @override
  State<AppContent> createState() => _AppContentState();
}

class _AppContentState extends State<AppContent> with WidgetsBindingObserver {
  String currentPage = 'home';
  bool? preOnboardingDone;
  bool? onboardingDone;
  String? checkedForUserId;
  int dashboardKey = 0;
  Future<void>? _telemetrySyncTask;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleTelemetrySync();
    }
  }

  void _scheduleTelemetrySync() {
    final auth = context.read<AuthProvider>();
    if (auth.user == null || onboardingDone != true) return;
    if (_telemetrySyncTask != null) return;

    final userId = auth.user!.id;
    _telemetrySyncTask = TelemetrySyncService.onAppOpen(userId).then((synced) {
      _telemetrySyncTask = null;
      if (synced && mounted) setState(() => dashboardKey++);
    });
  }

  Future<void> _checkPreOnboarding() async {
    final done = await OnboardingPrefs.isComplete();
    setState(() => preOnboardingDone = done);
  }

  Future<void> _checkOnboarding(String userId) async {
    await ProfileBasicsService.backfillWeightFromMetrics(userId);
    final rows = await Db.instance.raw.query('profiles',
        columns: ['onboarding_completed', 'age', 'height', 'weight'],
        where: 'id = ?',
        whereArgs: [userId]);
    final completed = rows.isNotEmpty && (rows.first['onboarding_completed'] as int) == 1;
    final hasBasics = rows.isNotEmpty &&
        rows.first['age'] != null &&
        rows.first['height'] != null &&
        rows.first['weight'] != null;
    setState(() {
      onboardingDone = completed && hasBasics;
      checkedForUserId = userId;
    });
    if (completed && hasBasics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleTelemetrySync();
      });
    }
  }

  void _openModal(Widget modal) {
    showDialog(context: context, builder: (_) => modal);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const _Splash();
    }

    if (preOnboardingDone == null) {
      _checkPreOnboarding();
      return const _Splash();
    }

    if (preOnboardingDone == false) {
      return OnboardingPage(
        beforeSignUp: true,
        onComplete: () => setState(() => preOnboardingDone = true),
      );
    }

    if (auth.user == null) {
      if (onboardingDone != null) {
        onboardingDone = null;
        checkedForUserId = null;
        currentPage = 'home';
      }
      return const LoginPage();
    }

    // Logged in — ensure onboarding status is loaded for this user.
    if (checkedForUserId != auth.user!.id) {
      _checkOnboarding(auth.user!.id);
      return const _Splash();
    }
    if (onboardingDone == null) return const _Splash();

    if (onboardingDone == false) {
      return OnboardingPage(
        beforeSignUp: false,
        onComplete: () {
          setState(() => onboardingDone = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scheduleTelemetrySync();
          });
        },
      );
    }

    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: AppBottomNav(
        current: currentPage,
        onChange: (p) => setState(() => currentPage = p),
      ),
    );
  }

  Widget _buildPage() {
    switch (currentPage) {
      case 'history':
        return const HistoryPage();
      case 'insights':
        return const InsightsPage();
      case 'profile':
        return const ProfilePage();
      default:
        final auth = context.read<AuthProvider>();
        return Dashboard(
          key: ValueKey('dashboard-$dashboardKey'),
          onOpenUpload: () => _openModal(
              UploadAnalysisModal(onNeedUpgrade: _needUpgrade)),
          onOpenAIChat: () => _openModal(
              AIChatModal(onNeedUpgrade: _needUpgrade)),
          onOpenStressTest: () => _openModal(const StressTestModal()),
          onOpenLogMetric: () => _openModal(
              LogMetricModal(onSaved: () => setState(() => dashboardKey++))),
          onOpenPsychoTest: () => auth.isPlus
              ? _openModal(const PsychoTestModal())
              : _openModal(const UpgradeModal()),
          onUpgrade: () => _openModal(const UpgradeModal()),
        );
    }
  }

  void _needUpgrade() {
    Navigator.of(context).pop();
    _openModal(const UpgradeModal());
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: C.gray50,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: C.blue500),
            SizedBox(height: 16),
            Text('Loading...', style: TextStyle(color: C.gray500, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
