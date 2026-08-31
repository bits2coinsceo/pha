import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../daily_metric_store.dart';
import '../daily_vitals.dart';
import '../db.dart';
import '../health_index.dart';
import '../medical_guidelines.dart';
import '../profile_basics.dart';
import '../onboarding_hp.dart';
import '../cosmic_ui.dart';
import '../onboarding_prefs.dart';
import '../theme.dart';
import '../theme_mode.dart';
import '../units.dart';
import '../widgets.dart';
import '../widgets/language_picker.dart';
import '../l10n/l10n_ext.dart';
import 'onboarding_widgets.dart';

const _uuid = Uuid();

class OnboardingPage extends StatefulWidget {
  final bool beforeSignUp;
  final VoidCallback onComplete;

  const OnboardingPage({
    super.key,
    this.beforeSignUp = false,
    required this.onComplete,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int step = 1;
  String unitSystem = 'metric';
  String? gender;
  bool saving = false;
  String error = '';

  int hp = 0;
  bool quest1Done = false;
  bool quest2Done = false;
  bool quest3Done = false;
  bool vitalsBonus = false;

  final _badges = <String, bool>{
    'units': false,
    'foundation': false,
    'heart': false,
    'glucose': false,
    'champion': false,
  };

  String? _hpToastMsg;
  int _hpToastAmount = 0;

  late final AnimationController _bgFloat;
  late final AnimationController _toastCtrl;

  final _age = TextEditingController();
  final _heightCm = TextEditingController();
  final _heightFt = TextEditingController();
  final _heightIn = TextEditingController();
  final _weight = TextEditingController();
  final _systolic = TextEditingController();
  final _diastolic = TextEditingController();
  final _glucose = TextEditingController();

  int? _pendingAge;
  int? _pendingHeightCm;
  double? _pendingWeightKg;

  String? _userId;
  Timer? _basicsSaveTimer;
  bool _needBpToday = true;
  bool _needGlucoseToday = true;

  bool get isImperial => unitSystem == 'imperial';
  String get _vitalsScope =>
      beforeSignUp ? DailyVitalsService.preSignUpScope : (_userId ?? DailyVitalsService.preSignUpScope);
  bool get beforeSignUp => widget.beforeSignUp;

  int get _level => hp < hpUnitsReward ? 1 : (hp < hpUnitsReward + hpBasicReward ? 2 : 3);

  String _levelTitle(AppLocalizations l10n) {
    switch (_level) {
      case 1:
        return l10n.levelHealthRookie;
      case 2:
        return l10n.levelProfileBuilder;
      default:
        return l10n.levelVitalsPro;
    }
  }

  double get _power => (hp / maxOnboardingHp).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bgFloat = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _toastCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

    if (beforeSignUp) {
      _restoreDraft();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _userId = context.read<AuthProvider>().user?.id;
        _restoreUserProfile();
      });
    }
    _attachBasicsAutosave();
  }

  void _attachBasicsAutosave() {
    void schedule() => _scheduleBasicsSave();
    for (final c in [_age, _heightCm, _heightFt, _heightIn, _weight]) {
      c.addListener(schedule);
    }
  }

  void _scheduleBasicsSave() {
    _basicsSaveTimer?.cancel();
    _basicsSaveTimer = Timer(const Duration(milliseconds: 250), _persistBasicsDraft);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _basicsSaveTimer?.cancel();
      unawaited(_persistBasicsDraft());
    }
  }

  Future<void> _persistBasicsDraft() async {
    final ageVal = _parseAge();
    final heightCm = _parseHeightCm();
    final weightKg = _parseWeightKg();
    if (ageVal == null && heightCm == null && weightKg == null && gender == null) return;

    if (beforeSignUp) {
      await OnboardingPrefs.saveBasicsProgress(
        unitSystem: unitSystem,
        age: ageVal,
        heightCm: heightCm,
        weightKg: weightKg,
        gender: gender,
      );
      if (ageVal != null) _pendingAge = ageVal;
      if (heightCm != null) _pendingHeightCm = heightCm;
      if (weightKg != null) _pendingWeightKg = weightKg;
      return;
    }

    final userId = _userId;
    if (userId == null) return;
    await ProfileBasicsService.save(
      userId: userId,
      unitSystem: unitSystem,
      age: ageVal,
      heightCm: heightCm,
      weightKg: weightKg,
      gender: gender,
    );
  }

  void _fillBasicsFields({int? ageVal, int? heightCm, double? weightKg}) {
    if (ageVal != null) _age.text = '$ageVal';
    if (heightCm != null) {
      if (isImperial) {
        final r = cmToFtIn(heightCm.toDouble());
        _heightFt.text = '${r.ft}';
        _heightIn.text = '${r.inch}';
      } else {
        _heightCm.text = '$heightCm';
      }
    }
    if (weightKg != null) {
      _weight.text = isImperial
          ? (kgToLbs(weightKg) * 10).round().toString()
          : weightKg.toStringAsFixed(weightKg % 1 == 0 ? 0 : 1);
    }
    if (ageVal != null) _pendingAge = ageVal;
    if (heightCm != null) _pendingHeightCm = heightCm;
    if (weightKg != null) _pendingWeightKg = weightKg;
  }

  /// Restores saved profile fields for post-sign-up onboarding.
  Future<void> _restoreUserProfile() async {
    final userId = _userId;
    if (userId == null) return;

    final rows = await Db.instance.raw.query('profiles', where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty || !mounted) return;
    final r = rows.first;

    var ageVal = (r['age'] as num?)?.toInt();
    var heightCm = (r['height'] as num?)?.toInt();
    var weightKg = (r['weight'] as num?)?.toDouble();

    if (weightKg == null) {
      final wRows = await Db.instance.raw.query(
        'health_metrics',
        columns: ['value'],
        where: 'user_id = ? AND metric_type = ?',
        whereArgs: [userId, 'weight'],
        orderBy: 'recorded_at DESC',
        limit: 1,
      );
      if (wRows.isNotEmpty) weightKg = (wRows.first['value'] as num).toDouble();
    }

    final needBp = await DailyVitalsService.shouldPromptBp(_vitalsScope);
    final needGlucose = await DailyVitalsService.shouldPromptGlucose(_vitalsScope);

    final hasBasics = ageVal != null && heightCm != null && weightKg != null;
    final hpStored = (r['health_points'] as int?) ?? 0;

    setState(() {
      unitSystem = (r['unit_system'] as String?) ?? 'metric';
      gender = r['gender'] as String?;
      _fillBasicsFields(ageVal: ageVal, heightCm: heightCm, weightKg: weightKg);
      quest1Done = true;
      quest2Done = hasBasics;
      step = hasBasics ? 3 : 2;
      _badges['units'] = true;
      if (hasBasics) _badges['foundation'] = true;
      hp = hpStored.clamp(0, maxOnboardingHp);
      _needBpToday = needBp;
      _needGlucoseToday = needGlucose;
    });
  }

  /// Restores an interrupted pre-signup onboarding from the persisted draft so
  /// the user resumes where they left off instead of starting over.
  Future<void> _restoreDraft() async {
    final d = await OnboardingPrefs.load();
    if (d == null || !mounted) return;

    final needBp = await DailyVitalsService.shouldPromptBp(_vitalsScope);
    final needGlucose = await DailyVitalsService.shouldPromptGlucose(_vitalsScope);

    if (!mounted) return;
    setState(() {
      unitSystem = d.unitSystem;
      gender = d.gender;
      _fillBasicsFields(ageVal: d.age, heightCm: d.heightCm, weightKg: d.weightKg);
      _needBpToday = needBp;
      _needGlucoseToday = needGlucose;

      final sys = d.extraMetrics['blood_pressure_systolic'];
      final dia = d.extraMetrics['blood_pressure_diastolic'];
      final glucose = d.extraMetrics['glucose'];
      if (sys != null) _systolic.text = sys.round().toString();
      if (dia != null) _diastolic.text = dia.round().toString();
      if (glucose != null) {
        _glucose.text = isImperial
            ? glucose.round().toString()
            : mgdlToMmol(glucose).toStringAsFixed(1);
      }

      final hasPartialBasics =
          d.age != null || d.heightCm != null || d.weightKg != null;
      var restoredStep = d.completed ? 4 : d.step.clamp(1, 3);
      if (!d.completed && hasPartialBasics && restoredStep < 2) {
        restoredStep = 2;
      }
      step = restoredStep;
      quest1Done = d.step > 1 || hasPartialBasics;
      quest2Done = d.step > 2;
      quest3Done = d.completed;
      vitalsBonus = d.extraMetrics.isNotEmpty;

      _badges['units'] = quest1Done;
      _badges['foundation'] = quest2Done;
      _badges['champion'] = quest3Done;
      if (sys != null && dia != null) _badges['heart'] = true;
      if (glucose != null) _badges['glucose'] = true;

      hp = d.healthPoints > 0
          ? d.healthPoints.clamp(0, maxOnboardingHp)
          : _restoredHp(d).clamp(0, maxOnboardingHp);
    });
  }

  int _restoredHp(OnboardingDraftData d) {
    final sys = d.extraMetrics['blood_pressure_systolic'];
    final dia = d.extraMetrics['blood_pressure_diastolic'];
    return computeOnboardingHp(
      unitsDone: d.step > 1,
      basicDone: d.step > 2,
      hasBp: sys != null && dia != null,
      hasGlucose: d.extraMetrics.containsKey('glucose'),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _basicsSaveTimer?.cancel();
    unawaited(_persistBasicsDraft());
    _bgFloat.dispose();
    _toastCtrl.dispose();
    for (final c in [_age, _heightCm, _heightFt, _heightIn, _weight, _systolic, _diastolic, _glucose]) {
      c.dispose();
    }
    super.dispose();
  }

  void _grantHp(int amount, {String? toast, String? badgeKey}) {
    setState(() {
      hp = (hp + amount).clamp(0, maxOnboardingHp);
      if (toast != null) {
        _hpToastMsg = toast;
        _hpToastAmount = amount;
      }
      if (badgeKey != null) _badges[badgeKey] = true;
    });
    if (toast != null) {
      _toastCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _hpToastMsg = null);
      });
    }
  }

  Future<void> _insertMetrics(AuthProvider auth, List<Map<String, dynamic>> inserts) async {
    for (final row in inserts) {
      final type = row['metric_type'] as String;
      if (DailyMetricStore.isDailyLiveMetric(type)) {
        await DailyMetricStore.upsertToday(
          userId: row['user_id'] as String,
          metricType: type,
          value: (row['value'] as num).toDouble(),
          notes: row['notes'] as String?,
          source: row['source'] as String? ?? 'onboarding',
        );
      } else {
        await Db.instance.raw.insert('health_metrics', row);
      }
    }
  }

  List<Map<String, dynamic>> _metricRows(String userId, Map<String, double> types) {
    final now = DateTime.now().toUtc().toIso8601String();
    return types.entries
        .map((e) => {
              'id': _uuid.v4(),
              'user_id': userId,
              'metric_type': e.key,
              'value': e.value,
              'recorded_at': now,
              'created_at': now,
            })
        .toList();
  }

  int? _parseAge() {
    if (_age.text.trim().isEmpty) return null;
    final v = int.tryParse(_age.text.trim());
    if (v == null || v < 1 || v > 120) return null;
    return v;
  }

  int? _parseHeightCm() {
    if (isImperial) {
      if (_heightFt.text.trim().isEmpty && _heightIn.text.trim().isEmpty) return null;
      final ft = double.tryParse(_heightFt.text.trim()) ?? 0;
      final inch = double.tryParse(_heightIn.text.trim()) ?? 0;
      if (ft < 1 || ft > 8 || inch < 0 || inch >= 12) return null;
      return ftInToCm(ft, inch).round();
    }
    if (_heightCm.text.trim().isEmpty) return null;
    final v = int.tryParse(_heightCm.text.trim());
    if (v == null || v < 50 || v > 250) return null;
    return v;
  }

  double? _parseWeightKg() {
    if (_weight.text.trim().isEmpty) return null;
    final w = parseUserNumber(_weight.text);
    if (w == null) return null;
    if (isImperial) {
      if (w < 44 || w > 660) return null;
      return (lbsToKg(w) * 10).round() / 10;
    }
    if (w < 20 || w > 300) return null;
    return w;
  }

  Future<void> _completeQuest1() async {
    if (beforeSignUp) {
      await OnboardingPrefs.saveUnit(unitSystem);
    }
    if (quest1Done) {
      setState(() => step = 2);
      return;
    }
    setState(() {
      quest1Done = true;
      step = 2;
    });
    _grantHp(hpUnitsReward, toast: context.l10n.onboardingQuest1Complete, badgeKey: 'units');
  }

  Future<void> _submitGeneral() async {
    setState(() => error = '');
    final ageVal = _parseAge();
    final heightCm = _parseHeightCm();
    final weightKg = _parseWeightKg();

    if (ageVal == null) {
      setState(() => error = context.l10n.onboardingErrorAge);
      return;
    }
    if (gender == null) {
      setState(() => error = context.l10n.onboardingErrorGender);
      return;
    }
    if (heightCm == null) {
      setState(() => error = isImperial
          ? context.l10n.onboardingErrorHeightImperial
          : context.l10n.onboardingErrorHeightMetric);
      return;
    }
    if (weightKg == null) {
      setState(() => error = isImperial
          ? context.l10n.onboardingErrorWeightImperial
          : context.l10n.onboardingErrorWeightMetric);
      return;
    }

    setState(() => saving = true);

    if (beforeSignUp) {
      _pendingAge = ageVal;
      _pendingHeightCm = heightCm;
      _pendingWeightKg = weightKg;
      await OnboardingPrefs.saveGeneral(
        unitSystem: unitSystem,
        age: ageVal,
        heightCm: heightCm,
        weightKg: weightKg,
        gender: gender!,
      );
    } else {
      final auth = context.read<AuthProvider>();
      await ProfileBasicsService.save(
        userId: auth.user!.id,
        unitSystem: unitSystem,
        age: ageVal,
        heightCm: heightCm,
        weightKg: weightKg,
        gender: gender,
      );
      await _insertMetrics(auth, _metricRows(auth.user!.id, {'weight': weightKg}));
    }

    if (mounted) {
      setState(() {
        saving = false;
        quest2Done = true;
        step = 3;
        error = '';
      });
      _grantHp(hpBasicReward, toast: context.l10n.onboardingQuest2Complete, badgeKey: 'foundation');
    }
  }

  Future<void> _finish({required bool includeAdvanced}) async {
    setState(() => saving = true);
    final extraMetrics = <String, double>{};
    var bonusHp = 0;

    if (includeAdvanced) {
      setState(() => error = '');
      if (_needBpToday &&
          (_systolic.text.trim().isNotEmpty || _diastolic.text.trim().isNotEmpty)) {
        if (_systolic.text.trim().isEmpty || _diastolic.text.trim().isEmpty) {
          setState(() {
            error = context.l10n.vitalsBpBothOrNone;
            saving = false;
          });
          return;
        }
        final sys = double.tryParse(_systolic.text.trim());
        final dia = double.tryParse(_diastolic.text.trim());
        final bpErr = VitalValidation.bloodPressure(sys, dia, context.l10n);
        if (bpErr != null) {
          setState(() {
            error = bpErr;
            saving = false;
          });
          return;
        }
        extraMetrics['blood_pressure_systolic'] = sys!;
        extraMetrics['blood_pressure_diastolic'] = dia!;
        bonusHp += hpBpReward;
        _badges['heart'] = true;
        await DailyVitalsService.markBpLogged(_vitalsScope);
      }

      if (_needGlucoseToday && _glucose.text.trim().isNotEmpty) {
        final g = parseUserNumber(_glucose.text);
        double? glucoseMgdl;
        final gErr = VitalValidation.glucoseUserInput(
          g,
          isImperial ? 'imperial' : 'metric',
          context.l10n,
          onValid: (mgdl) => glucoseMgdl = mgdl,
        );
        if (gErr != null) {
          setState(() {
            error = gErr;
            saving = false;
          });
          return;
        }
        extraMetrics['glucose'] = glucoseMgdl!;
        bonusHp += hpGlucoseReward;
        _badges['glucose'] = true;
        await DailyVitalsService.markGlucoseLogged(_vitalsScope);
      }
      vitalsBonus = extraMetrics.isNotEmpty;
    }

    if (beforeSignUp) {
      if (_pendingAge == null || _pendingHeightCm == null || _pendingWeightKg == null) {
        setState(() { error = context.l10n.onboardingErrorQuest2First; saving = false; });
        return;
      }
      await OnboardingPrefs.complete(
        unitSystem: unitSystem,
        extraMetrics: extraMetrics,
        healthPoints: hp + bonusHp,
      );
    } else {
      final auth = context.read<AuthProvider>();
      if (extraMetrics.isNotEmpty) {
        await _insertMetrics(auth, _metricRows(auth.user!.id, extraMetrics));
      }
      final finalHp = (hp + bonusHp).clamp(0, maxOnboardingHp);
      await Db.instance.raw.update(
        'profiles',
        {
          'onboarding_completed': 1,
          'unit_system': unitSystem,
          'health_points': finalHp,
        },
        where: 'id = ?',
        whereArgs: [auth.user!.id],
      );
      await auth.refreshPlanStatus();
      await HealthIndexService.recalculate(auth.user!.id);
    }

    if (mounted) {
      setState(() {
        saving = false;
        quest3Done = true;
        step = 4;
      });
      if (bonusHp > 0) {
        _grantHp(bonusHp, toast: context.l10n.onboardingBonusComplete);
      }
      setState(() => _badges['champion'] = true);
    }
  }

  void _finishJourney() => widget.onComplete();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: C.gray50,
      body: Stack(
        children: [
          CosmicBackground(drift: _bgFloat),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      if (_hpToastMsg != null) ...[
                        OnboardingHpToast(message: _hpToastMsg!, hp: _hpToastAmount),
                        SizedBox(height: 6),
                      ],
                      OnboardingGameHud(
                        hp: hp,
                        level: _level,
                        levelTitle: _levelTitle(l10n),
                        power: _power,
                      ),
                      SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutCubic,
                        child: Container(
                          key: ValueKey(step),
                          margin: const EdgeInsets.only(top: 4),
                          decoration: cosmicPanelDecoration(radius: 24),
                          padding: EdgeInsets.all(step == 2 ? 16 : 24),
                          child: switch (step) {
                            1 => _stepUnits(),
                            2 => _stepGeneral(),
                            3 => _stepAdvanced(),
                            _ => _stepVictory(),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questHeader() {
    final l10n = context.l10n;
    return Column(
      children: [
        OnboardingQuestTrail(
          currentStep: step.clamp(1, 3),
          quest1Done: quest1Done,
          quest2Done: quest2Done,
          quest3Done: quest3Done,
        ),
        SizedBox(height: 14),
        OnboardingBadgeStrip(
          badges: [
            (emoji: '🎯', label: l10n.badgeUnitPro, unlocked: _badges['units']!),
            (emoji: '🏗', label: l10n.badgeFoundation, unlocked: _badges['foundation']!),
            (emoji: '♥', label: l10n.badgeHeartTrack, unlocked: _badges['heart']!),
            (emoji: '💧', label: l10n.badgeSugarSense, unlocked: _badges['glucose']!),
            (emoji: '🏆', label: l10n.badgeChampion, unlocked: _badges['champion']!),
          ],
        ),
      ],
    );
  }

  Widget _stepUnits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _questHeader(),
        SizedBox(height: 12),
        Text(
          beforeSignUp
              ? context.l10n.onboardingQuest1TitleBefore
              : context.l10n.onboardingQuest1TitleAfter,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.gray900),
        ),
        SizedBox(height: 6),
        Text(
          beforeSignUp
              ? context.l10n.onboardingQuest1BodyBefore
              : context.l10n.onboardingQuest1BodyAfter,
          textAlign: TextAlign.center,
          style: TextStyle(color: C.gray500, fontSize: 14, height: 1.4),
        ),
        SizedBox(height: 16),
        OnboardingQuestCard(
          title: context.l10n.onboardingQuest1CardTitle,
          subtitle: context.l10n.onboardingQuest1CardSubtitle,
          reward: '+$hpUnitsReward HP',
          icon: Icons.public,
          accent: C.blue500,
        ),
        SizedBox(height: 16),
        _unitOption('imperial', Icons.flag_outlined, context.l10n.imperial, context.l10n.imperialUnits, C.neonCyan),
        SizedBox(height: 10),
        _unitOption('metric', Icons.public, context.l10n.metric, context.l10n.metricUnits, C.neonMint),
        SizedBox(height: 16),
        LanguagePicker(expanded: true),
        SizedBox(height: 12),
        _themeToggle(),
        SizedBox(height: 12),
        PrimaryButton(
          label: context.l10n.startQuest1,
          cosmicGradient: true,
          icon: Icon(Icons.play_arrow_rounded, size: 20, color: C.white),
          onPressed: _completeQuest1,
        ),
      ],
    );
  }

  Widget _themeToggle() {
    final themeMode = context.watch<ThemeModeController>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: cardDecoration(radius: 12),
      child: Row(
        children: [
          Icon(
            themeMode.isDark ? Icons.dark_mode : Icons.light_mode,
            color: C.accentPrimary,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.theme,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: C.gray900,
                  ),
                ),
                Text(
                  themeMode.isDark ? context.l10n.themeDark : context.l10n.themeLight,
                  style: TextStyle(fontSize: 12, color: C.gray500),
                ),
              ],
            ),
          ),
          Switch(
            value: themeMode.isDark,
            activeThumbColor: C.white,
            activeTrackColor: C.accentSecondary,
            inactiveThumbColor: C.white,
            inactiveTrackColor: C.gray300,
            onChanged: (v) => themeMode.setDark(v),
          ),
        ],
      ),
    );
  }

  Widget _unitOption(String value, IconData icon, String title, String desc, Color accent) {
    final selected = unitSystem == value;
    return GestureDetector(
      onTap: () => setState(() => unitSystem = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? accent.withValues(alpha: 0.18) : C.gray100,
          border: Border.all(color: selected ? accent : C.gray200, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: accent),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16, color: C.gray900)),
                  SizedBox(height: 2),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected ? C.gray600 : C.gray500,
                          height: 1.3)),
                ],
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                child: Text(context.l10n.picked,
                    style: TextStyle(
                        color: C.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepGeneral() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _questHeader(),
        SizedBox(height: 8),
        _backChip(),
        SizedBox(height: 4),
        Text(
          l10n.onboardingQuest2BuildAvatar,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.gray900),
        ),
        SizedBox(height: 4),
        Text(
          l10n.onboardingQuest2FillFields(hpBasicReward),
          textAlign: TextAlign.center,
          style: TextStyle(color: C.gray500, fontSize: 12),
        ),
        SizedBox(height: 10),
        if (error.isNotEmpty) ...[
          AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700),
          SizedBox(height: 8),
        ],
        _genderSelector(),
        SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.stars_rounded, size: 15, color: C.amber500),
            SizedBox(width: 5),
            Text(
              l10n.rewardedStats,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: C.gray700,
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        _gameField(Icons.cake_outlined, C.orange50, C.orange500, l10n.age, l10n.unitYearsLong, true,
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) {},
              decoration: appInput(context.l10n.onboardingAgeHint),
            ),
            compact: true),
        SizedBox(height: 8),
        _gameField(
          Icons.straighten,
          C.sky50,
          C.sky500,
          l10n.height,
          isImperial ? 'ft & in' : l10n.unitCm,
          true,
          isImperial
              ? Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _heightFt,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) {},
                      decoration: appInput('ft'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _heightIn,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) {},
                      decoration: appInput('in'),
                    ),
                  ),
                ])
              : TextField(
                  controller: _heightCm,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) {},
                  decoration: appInput(context.l10n.onboardingHeightHintMetric),
                ),
          compact: true,
        ),
        SizedBox(height: 8),
        _gameField(
          Icons.monitor_weight_outlined,
          C.blue50,
          C.blue500,
          l10n.weight,
          isImperial ? l10n.unitLbs : l10n.unitKg,
          true,
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            onChanged: (_) {},
            decoration: appInput(isImperial ? context.l10n.onboardingWeightHintImperial : context.l10n.onboardingWeightHintMetric),
          ),
          compact: true,
        ),
        SizedBox(height: 12),
        PrimaryButton(
          label: saving ? l10n.saving : l10n.completeQuest2(hpBasicReward),
          color: C.teal600,
          icon: Icon(Icons.military_tech, size: 18, color: C.white),
          onPressed: saving ? null : _submitGeneral,
        ),
      ],
    );
  }

  Widget _stepAdvanced() {
    final l10n = context.l10n;
    final hasBp = _systolic.text.trim().isNotEmpty || _diastolic.text.trim().isNotEmpty;
    final hasGlucose = _glucose.text.trim().isNotEmpty;
    final showBp = _needBpToday;
    final showGlucose = _needGlucoseToday;
    final allLoggedToday = !showBp && !showGlucose;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _questHeader(),
        SizedBox(height: 12),
        GestureDetector(
          onTap: saving ? null : () => setState(() { step = 2; error = ''; }),
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 16, color: C.gray400),
              SizedBox(width: 4),
              Text(l10n.onboardingBackToQuest2, style: TextStyle(fontSize: 12, color: C.gray400)),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          l10n.onboardingQuest3PowerUp,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.gray900),
        ),
        SizedBox(height: 6),
        Text(
          allLoggedToday
              ? l10n.onboardingQuest3BpDone
              : l10n.onboardingQuest3Optional(hpBpReward, hpGlucoseReward),
          textAlign: TextAlign.center,
          style: TextStyle(color: C.gray500, fontSize: 13),
        ),
        SizedBox(height: 12),
        if (!allLoggedToday)
          Row(
            children: [
              if (showBp)
                Expanded(
                  child: _bonusTile(
                    '♥ BP',
                    '+$hpBpReward HP',
                    hasBp && _diastolic.text.isNotEmpty && _systolic.text.isNotEmpty,
                  ),
                ),
              if (showBp && showGlucose) SizedBox(width: 8),
              if (showGlucose)
                Expanded(
                  child: _bonusTile('💧 Glucose', '+$hpGlucoseReward HP', hasGlucose),
                ),
            ],
          ),
        SizedBox(height: 16),
        if (error.isNotEmpty) ...[
          AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700),
          SizedBox(height: 12),
        ],
        if (showBp) ...[
          _gameField(Icons.monitor_heart_outlined, C.red50, C.red500, l10n.bloodPressure, 'mmHg', false,
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _systolic,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    decoration: appInput(l10n.onboardingSys),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _diastolic,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    decoration: appInput(l10n.onboardingDia),
                  ),
                ),
              ])),
          SizedBox(height: 14),
        ],
        if (showGlucose)
          _gameField(Icons.water_drop_outlined, C.teal50, C.teal500, l10n.bloodGlucose,
              isImperial ? 'mg/dL' : 'mmol/L', false,
              TextField(
                controller: _glucose,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                decoration: appInput(isImperial ? context.l10n.vitalsGlucoseHintImperial : context.l10n.vitalsGlucoseHintMetric),
              )),
        SizedBox(height: 20),
        if (!allLoggedToday)
          PrimaryButton(
            label: saving ? l10n.calculatingRewards : l10n.claimBonusFinish,
            color: C.amber600,
            icon: Icon(Icons.emoji_events, size: 18, color: C.white),
            onPressed: saving ? null : () => _finish(includeAdvanced: true),
          ),
        SizedBox(height: 8),
        TextButton(
          onPressed: saving ? null : () => _finish(includeAdvanced: false),
          child: Text(
            l10n.skipBonusQuest,
            style: TextStyle(color: C.gray600, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _bonusTile(String label, String hpLabel, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? C.amber50 : C.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? C.amber400 : C.gray200, width: active ? 2 : 1),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(hpLabel,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active ? C.amber700 : C.gray400)),
        ],
      ),
    );
  }

  Widget _stepVictory() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('🎊', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
        SizedBox(height: 8),
        Text(
          l10n.onboardingAllQuestsComplete,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: C.gray900),
        ),
        SizedBox(height: 8),
        Text(
          l10n.onboardingEarnedHp(hp, _level, _levelTitle(l10n)),
          textAlign: TextAlign.center,
          style: TextStyle(color: C.teal400, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        if (hp >= maxOnboardingHp) ...[
          SizedBox(height: 8),
          Text(
            l10n.onboardingRedeemHp(maxOnboardingHp, hpFirstPurchaseDiscountPercent),
            textAlign: TextAlign.center,
            style: TextStyle(color: C.amber700, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
        if (vitalsBonus) ...[
          SizedBox(height: 6),
          Text(l10n.onboardingBonusVitals,
              textAlign: TextAlign.center,
              style: TextStyle(color: C.gray500, fontSize: 13)),
        ],
        SizedBox(height: 16),
        OnboardingBadgeStrip(
          badges: [
            (emoji: '🎯', label: l10n.badgeUnitPro, unlocked: _badges['units']!),
            (emoji: '🏗', label: l10n.badgeFoundation, unlocked: _badges['foundation']!),
            (emoji: '♥', label: l10n.badgeHeartTrack, unlocked: _badges['heart']!),
            (emoji: '💧', label: l10n.badgeSugarSense, unlocked: _badges['glucose']!),
            (emoji: '🏆', label: l10n.badgeChampion, unlocked: _badges['champion']!),
          ],
        ),
        SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: kBlueTealGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(l10n.healthPower,
                  style: TextStyle(color: C.white, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _power,
                  minHeight: 12,
                  backgroundColor: C.white.withValues(alpha: 0.3),
                  color: C.amber300,
                ),
              ),
              SizedBox(height: 6),
              Text(l10n.onboardingReadyForPha((_power * 100).round()),
                  style: TextStyle(color: C.white.withValues(alpha: 0.9), fontSize: 12)),
            ],
          ),
        ),
        SizedBox(height: 24),
        PrimaryButton(
          label: beforeSignUp ? l10n.onboardingCreateAccount : l10n.onboardingEnterDashboard,
          color: C.teal600,
          icon: Icon(Icons.rocket_launch, size: 20, color: C.white),
          onPressed: _finishJourney,
        ),
      ],
    );
  }

  Widget _backChip() {
    return GestureDetector(
      onTap: () => setState(() { step = 1; error = ''; }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chevron_left, size: 18, color: C.gray400),
          Text(isImperial ? context.l10n.imperial : context.l10n.metric,
              style: TextStyle(fontSize: 12, color: C.gray400, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _genderSelector() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.yourGender,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: C.gray700),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _genderOption('male', l10n.male, Icons.male)),
              SizedBox(width: 8),
              Expanded(child: _genderOption('female', l10n.female, Icons.female)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _genderOption(String value, String label, IconData icon) {
    final selected = gender == value;
    return InkWell(
      onTap: () {
        setState(() => gender = value);
        _scheduleBasicsSave();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? C.gray100 : C.gray50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? C.gray400 : C.gray200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? C.gray800 : C.gray500),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: selected ? C.gray900 : C.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameField(
    IconData icon,
    Color bg,
    Color fg,
    String label,
    String unit,
    bool required,
    Widget input, {
    bool compact = false,
  }) {
    final pad = compact ? 10.0 : 12.0;
    final iconSize = compact ? 32.0 : 36.0;
    final gap = compact ? 6.0 : 10.0;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: C.inputFill,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: C.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: compact ? 16 : 18, color: fg),
              ),
              SizedBox(width: compact ? 8 : 10),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: C.gray900,
                    fontSize: compact ? 14 : 15,
                  )),
              if (required) Text(' *', style: TextStyle(color: C.red500, fontWeight: FontWeight.bold)),
              Spacer(),
              Text(unit, style: TextStyle(fontSize: 11, color: C.gray400)),
            ],
          ),
          SizedBox(height: gap),
          input,
        ],
      ),
    );
  }
}
