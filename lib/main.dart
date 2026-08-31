import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'auth.dart';
import 'api.dart';
import 'core/app_logger.dart';
import 'db.dart';
import 'daily_notifications.dart';
import 'onboarding_prefs.dart';
import 'physical_activity.dart';
import 'profile_basics.dart';
import 'modals/psycho_test_modal.dart';
import 'modals/treatment_schedule_modal.dart';
import 'modals/quick_action_modals.dart';
import 'modals/heart_rate_modal.dart';
import 'services.dart';
import 'pages/dashboard.dart';
import 'pages/history.dart';
import 'pages/insights.dart';
import 'pages/login.dart';
import 'pages/onboarding.dart';
import 'pages/profile.dart';
import 'telemetry_sync.dart';
import 'cosmic_ui.dart';
import 'theme.dart';
import 'theme_mode.dart';
import 'locale_controller.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/l10n_ext.dart';
import 'widgets.dart';

bool _errorWidgetInstalled = false;

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      AppLogger.init();
      AppLogger.i('PHA starting', category: LogCategory.bootstrap);
      C.applyDarkMode(false);
      _installGlobalErrorHandlers();
      runApp(const PhaRoot());
    },
    (error, stack) {
      AppLogger.e(
        'Uncaught zoned error',
        error: error,
        stackTrace: stack,
        category: LogCategory.core,
      );
    },
  );
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    AppLogger.e(
      'FlutterError: ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
      category: LogCategory.core,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e(
      'PlatformDispatcher error',
      error: error,
      stackTrace: stack,
      category: LogCategory.core,
    );
    return true;
  };
}

Widget _materialAppBuilder(BuildContext context, Widget? child) {
  if (!_errorWidgetInstalled) {
    _errorWidgetInstalled = true;
    ErrorWidget.builder = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      debugPrint('ErrorWidget: ${details.exception}');
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error: ${details.exception}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF334155), fontSize: 14),
            ),
          ),
        ),
      );
    };
  }
  if (child == null) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Center(child: Text(l10n?.noContent ?? 'No content')),
    );
  }
  return child;
}

/// Boots after first frame. [runApp] is called immediately in [main].
class PhaRoot extends StatefulWidget {
  const PhaRoot({super.key});

  @override
  State<PhaRoot> createState() => _PhaRootState();
}

class _PhaRootState extends State<PhaRoot> {
  final AuthProvider _auth = AuthProvider();
  final ThemeModeController _themeMode = ThemeModeController();
  final LocaleController _locale = LocaleController();

  bool _ready = false;
  Object? _fatalError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_bootstrap()));
  }

  Future<void> _bootstrap() async {
    Object? fatal;
    AppLogger.i('Bootstrap started', category: LogCategory.bootstrap);

    try {
      AppLogger.d('Loading API config…', category: LogCategory.bootstrap);
      await ApiConfig.ensureLoaded().timeout(const Duration(seconds: 3));
      AppLogger.i(
        'API config OK (key ${ApiConfig.apiKey.isEmpty ? "missing" : "set"})',
        category: LogCategory.bootstrap,
      );
    } catch (e, st) {
      AppLogger.e(
        'API config failed',
        error: e,
        stackTrace: st,
        category: LogCategory.bootstrap,
      );
    }

    // Database
    try {
      AppLogger.d('Initializing database…', category: LogCategory.db);
      await Db.instance.init().timeout(const Duration(seconds: 12));
      AppLogger.i('Database OK', category: LogCategory.db);
    } catch (e, st) {
      fatal ??= e;
      AppLogger.e(
        'Database init failed',
        error: e,
        stackTrace: st,
        category: LogCategory.db,
      );
    }

    // Notifications (non-fatal — must not block cold start)
    try {
      AppLogger.d('Initializing notifications…', category: LogCategory.notifications);
      await DailyNotificationService.init().timeout(const Duration(seconds: 8));
      AppLogger.i('Notifications OK', category: LogCategory.notifications);
    } catch (e, st) {
      AppLogger.w(
        'Notifications init failed (non-fatal)',
        error: e,
        stackTrace: st,
        category: LogCategory.notifications,
      );
    }

    // Auth session
    try {
      AppLogger.d('Bootstrapping auth…', category: LogCategory.auth);
      await _auth.bootstrap().timeout(const Duration(seconds: 8));
      AppLogger.i('Auth OK', category: LogCategory.auth);
    } catch (e, st) {
      AppLogger.e(
        'Auth bootstrap failed',
        error: e,
        stackTrace: st,
        category: LogCategory.auth,
      );
    }

    // Theme
    try {
      AppLogger.d('Loading theme…', category: LogCategory.bootstrap);
      await _themeMode.load().timeout(const Duration(seconds: 5));
      AppLogger.i('Theme OK', category: LogCategory.bootstrap);
    } catch (e, st) {
      AppLogger.w(
        'Theme load failed (non-fatal)',
        error: e,
        stackTrace: st,
        category: LogCategory.bootstrap,
      );
    }

    // Locale
    try {
      AppLogger.d('Loading locale…', category: LogCategory.bootstrap);
      await _locale.load().timeout(const Duration(seconds: 5));
      AppLogger.i(
        'Locale OK (${_locale.locale.languageCode})',
        category: LogCategory.bootstrap,
      );
    } catch (e, st) {
      AppLogger.w(
        'Locale load failed (non-fatal)',
        error: e,
        stackTrace: st,
        category: LogCategory.bootstrap,
      );
    }

    if (!mounted) return;
    setState(() {
      _fatalError = fatal;
      _ready = true;
    });
    AppLogger.i(
      'Bootstrap done (fatal=${fatal != null})',
      category: LogCategory.bootstrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (!_ready) {
      home = const _ColdStartSplash();
    } else if (_fatalError != null) {
      home = _StartupError(error: _fatalError!);
    } else {
      home = const AppContent();
    }

    // Providers must wrap MaterialApp so dialogs/modals can read AuthProvider.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _themeMode),
        ChangeNotifierProvider.value(value: _locale),
      ],
      child: AnimatedBuilder(
        animation: Listenable.merge([_themeMode, _locale]),
        builder: (context, _) {
          return MaterialApp(
            title: 'PHA',
            onGenerateTitle: (context) {
              try {
                return context.l10n.appTitle;
              } catch (_) {
                return 'PHA';
              }
            },
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(isDark: false),
            darkTheme: buildAppTheme(isDark: true),
            themeMode: _ready ? _themeMode.mode : ThemeMode.light,
            locale: _locale.locale,
            supportedLocales: LocaleController.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: _materialAppBuilder,
            home: home,
          );
        },
      ),
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
  bool _trialExpiredPopupShown = false;
  bool _openingFromNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loadPreOnboarding()));
    DailyNotificationService.addTapListener(_onOsNotificationTap);
  }

  @override
  void dispose() {
    DailyNotificationService.removeTapListener(_onOsNotificationTap);
    WidgetsBinding.instance.removeObserver(this);
    TelemetrySyncService.stopLiveSync();
    super.dispose();
  }

  void _onOsNotificationTap(NotificationResponse response) {
    // Defer to next frame so MaterialApp / navigator exist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_openFromNotification(response));
    });
  }

  Future<void> _openFromNotification(NotificationResponse response) async {
    if (!mounted || _openingFromNotification) return;
    final auth = context.read<AuthProvider>();
    if (auth.user == null || onboardingDone != true) {
      // Keep until the user reaches the main shell.
      DailyNotificationService.pendingTap = response;
      return;
    }
    _openingFromNotification = true;
    DailyNotificationService.takePendingTap();

    try {
      final payload = response.payload ?? '';
      if (payload == 'physical_activity_checkin') {
        final program =
            await PhysicalActivityService.activeProgram(auth.user!.id);
        if (!mounted) return;
        if (program != null) {
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PhysicalActivityCheckinDialog(
              userId: auth.user!.id,
              programLabel: program['program_label'] as String? ??
                  ctx.l10n.activityYourProgramFallback,
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      setState(() => currentPage = 'home');
      await showDialog<void>(
        context: context,
        builder: (_) => TodayNotificationsPanel(userId: auth.user!.id),
      );
    } catch (e, st) {
      debugPrint('openFromNotification failed: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      _openingFromNotification = false;
    }
  }

  Future<void> _consumePendingNotificationTap() async {
    final tap = DailyNotificationService.takePendingTap();
    if (tap != null) await _openFromNotification(tap);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleTelemetrySync();
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        unawaited(_syncPatientHistorySafely(auth));
      }
      if (mounted) setState(() => dashboardKey++);
    }
  }

  Future<void> _loadPreOnboarding() async {
    try {
      if (!Db.instance.isReady) {
        if (mounted) setState(() => preOnboardingDone = false);
        return;
      }
      final done = await OnboardingPrefs.isComplete();
      if (mounted) setState(() => preOnboardingDone = done);
    } catch (e, st) {
      debugPrint('_loadPreOnboarding failed: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) setState(() => preOnboardingDone = false);
    }
  }

  void _scheduleTelemetrySync() {
    final auth = context.read<AuthProvider>();
    if (auth.user == null || onboardingDone != true) {
      TelemetrySyncService.stopLiveSync();
      return;
    }

    final userId = auth.user!.id;
    TelemetrySyncService.startLiveSync(userId, () {
      if (mounted) setState(() => dashboardKey++);
    });

    if (_telemetrySyncTask != null) return;
    _telemetrySyncTask = _runTelemetrySync(userId);
  }

  Future<void> _checkOnboarding(String userId) async {
    try {
      if (!Db.instance.isReady) {
        if (mounted) {
          setState(() {
            onboardingDone = false;
            checkedForUserId = userId;
          });
        }
        return;
      }
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
      if (mounted) {
        setState(() {
          onboardingDone = completed && hasBasics;
          checkedForUserId = userId;
        });
      }
      if (completed && hasBasics) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scheduleTelemetrySync();
            _scheduleTrialExpiredPopup();
            unawaited(_consumePendingNotificationTap());
          }
        });
      }
    } catch (e, st) {
      debugPrint('_checkOnboarding failed for $userId: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        setState(() {
          onboardingDone = false;
          checkedForUserId = userId;
        });
      }
    }
  }

  void _scheduleTrialExpiredPopup() {
    final auth = context.read<AuthProvider>();
    if (auth.isPlus || !auth.isTrialExpired || _trialExpiredPopupShown) return;
    _trialExpiredPopupShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openModal(const UpgradeModal(trialExpired: true));
    });
  }

  void _guardFreeFeature(VoidCallback action) {
    final auth = context.read<AuthProvider>();
    if (!auth.hasFreeAccess) {
      _openModal(const UpgradeModal(trialExpired: true));
      return;
    }
    action();
  }

  void _openModal(Widget modal) {
    try {
      showDialog(context: context, builder: (_) => modal);
    } catch (e, st) {
      debugPrint('_openModal failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _openFullScreen(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final auth = context.watch<AuthProvider>();

      if (auth.loading || preOnboardingDone == null) {
        return const _Splash();
      }

      if (preOnboardingDone == false) {
        return OnboardingPage(
          beforeSignUp: true,
          onComplete: () => setState(() => preOnboardingDone = true),
        );
      }

      if (auth.user == null) {
        TelemetrySyncService.stopLiveSync();
        _trialExpiredPopupShown = false;
        _openingFromNotification = false;
        if (onboardingDone != null) {
          onboardingDone = null;
          checkedForUserId = null;
          currentPage = 'home';
        }
        return const LoginPage();
      }

      if (checkedForUserId != auth.user!.id) {
        checkedForUserId = auth.user!.id;
        onboardingDone = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkOnboarding(auth.user!.id);
        });
        return const _Splash();
      }
      if (onboardingDone == null) return const _Splash();

      if (onboardingDone == false) {
        return OnboardingPage(
          beforeSignUp: false,
          onComplete: () {
            setState(() => onboardingDone = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _scheduleTelemetrySync();
                unawaited(_consumePendingNotificationTap());
              }
            });
          },
        );
      }

      return CosmicScaffold(
        body: _buildPage(),
        bottomNavigationBar: AppBottomNav(
          current: currentPage,
          onChange: (p) => setState(() => currentPage = p),
        ),
      );
    } catch (e, st) {
      debugPrint('AppContent.build failed: $e');
      debugPrintStack(stackTrace: st);
      return _StartupError(error: e);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (onboardingDone == true) {
      _scheduleTrialExpiredPopup();
    }
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
          refreshToken: dashboardKey,
          onOpenUpload: () => _guardFreeFeature(() => _openModal(UploadAnalysisModal(
            onNeedUpgrade: _needUpgrade,
            onAnalysisDelivered: (analysis, fileName) {
              // Close upload sheet, then open Ai Doc with the analysis already in chat.
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final l10n = context.l10n;
                _openFullScreen(AIChatModal(
                  onNeedUpgrade: _needUpgrade,
                  seedMessages: [
                    AiChatSeedMessage(
                      true,
                      l10n.aiDocUploadedAnalysis(fileName),
                    ),
                    AiChatSeedMessage(false, analysis),
                  ],
                ));
              });
            },
          ))),
          onOpenMealCalories: () => _guardFreeFeature(() => _openModal(
              CheckMealCaloriesModal(onNeedUpgrade: _needUpgrade))),
          onOpenAIChat: () => _guardFreeFeature(() => _openFullScreen(
              AIChatModal(onNeedUpgrade: _needUpgrade))),
          onOpenStressTest: () => _guardFreeFeature(
              () => _openModal(const StressTestModal())),
          onOpenBadHabits: () => auth.isPlus
              ? _openModal(const BadHabitsModal())
              : _openModal(const UpgradeModal()),
          onOpenPhysicalActivity: () => auth.isPlus
              ? _openModal(const PhysicalActivityModal())
              : _openModal(const UpgradeModal()),
          onOpenHeartRate: () => auth.isPlus
              ? _openModal(const HeartRateModal())
              : _openModal(const UpgradeModal()),
          onOpenLogMetric: () => _openModal(
              LogMetricModal(onSaved: () => setState(() => dashboardKey++))),
          onOpenPsychoTest: () => auth.isPlus
              ? _openModal(const PsychoTestModal())
              : _openModal(const UpgradeModal()),
          onOpenTreatmentSchedule: () => auth.isPlus
              ? _openModal(const TreatmentScheduleModal())
              : _openModal(const UpgradeModal()),
          onUpgrade: () => _openModal(const UpgradeModal()),
          onOpenInsights: () => setState(() => currentPage = 'insights'),
        );
    }
  }

  void _needUpgrade() {
    Navigator.of(context).pop();
    final trialExpired = context.read<AuthProvider>().isTrialExpired;
    _openModal(UpgradeModal(trialExpired: trialExpired));
  }

  Future<void> _runTelemetrySync(String userId) async {
    try {
      final synced = await TelemetrySyncService.onAppOpen(userId);
      if (synced && mounted) setState(() => dashboardKey++);
    } catch (e, st) {
      debugPrint('Telemetry sync failed for $userId: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      _telemetrySyncTask = null;
    }
  }

  Future<void> _syncPatientHistorySafely(AuthProvider auth) async {
    try {
      await auth.syncPatientHistory();
    } catch (e, st) {
      debugPrint('syncPatientHistory failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
}

class _ColdStartSplash extends StatelessWidget {
  const _ColdStartSplash();

  @override
  Widget build(BuildContext context) {
    String label = 'Starting PHA…';
    try {
      label = AppLocalizations.of(context).startingPha;
    } catch (_) {}
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF4F46E5)),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return CosmicScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: C.accentPrimary),
            SizedBox(height: 16),
            Text(
              context.l10n.loading,
              style: TextStyle(
                color: C.gray600,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object error;

  const _StartupError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: C.red500, size: 40),
              SizedBox(height: 16),
              Text(
                context.l10n.startupFailed,
                style: TextStyle(
                  color: C.gray900,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.gray600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
