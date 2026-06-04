import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../daily_vitals.dart';
import '../db.dart';
import '../profile_basics.dart';
import '../onboarding_hp.dart';
import '../cosmic_ui.dart';
import '../onboarding_prefs.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';
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

  String get _levelTitle {
    switch (_level) {
      case 1:
        return 'Health Rookie';
      case 2:
        return 'Profile Builder';
      default:
        return 'Vitals Pro';
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
    if (ageVal == null && heightCm == null && weightKg == null) return;

    if (beforeSignUp) {
      await OnboardingPrefs.saveBasicsProgress(
        unitSystem: unitSystem,
        age: ageVal,
        heightCm: heightCm,
        weightKg: weightKg,
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
      await Db.instance.raw.insert('health_metrics', row);
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
    final w = double.tryParse(_weight.text.trim());
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
    _grantHp(hpUnitsReward, toast: 'Quest 1 complete!', badgeKey: 'units');
  }

  Future<void> _submitGeneral() async {
    setState(() => error = '');
    final ageVal = _parseAge();
    final heightCm = _parseHeightCm();
    final weightKg = _parseWeightKg();

    if (ageVal == null) {
      setState(() => error = 'Enter your age to earn the Foundation badge.');
      return;
    }
    if (heightCm == null) {
      setState(() => error = isImperial
          ? 'Enter height (ft 1–8, in 0–11).'
          : 'Enter height between 50–250 cm.');
      return;
    }
    if (weightKg == null) {
      setState(() => error = isImperial
          ? 'Enter weight between 44–660 lbs.'
          : 'Enter weight between 20–300 kg.');
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
      );
    } else {
      final auth = context.read<AuthProvider>();
      await ProfileBasicsService.save(
        userId: auth.user!.id,
        unitSystem: unitSystem,
        age: ageVal,
        heightCm: heightCm,
        weightKg: weightKg,
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
      _grantHp(hpBasicReward, toast: 'Quest 2 crushed!', badgeKey: 'foundation');
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
            error = 'Enter both BP values, or leave both empty.';
            saving = false;
          });
          return;
        }
        final sys = double.tryParse(_systolic.text.trim());
        final dia = double.tryParse(_diastolic.text.trim());
        if (sys == null || sys < 60 || sys > 250 || dia == null || dia < 40 || dia > 150) {
          setState(() {
            error = 'Check blood pressure values.';
            saving = false;
          });
          return;
        }
        extraMetrics['blood_pressure_systolic'] = sys;
        extraMetrics['blood_pressure_diastolic'] = dia;
        bonusHp += hpBpReward;
        _badges['heart'] = true;
        await DailyVitalsService.markBpLogged(_vitalsScope);
      }

      if (_needGlucoseToday && _glucose.text.trim().isNotEmpty) {
        final g = double.tryParse(_glucose.text.trim());
        double? glucoseMgdl;
        if (isImperial) {
          if (g == null || g < 20 || g > 600) {
            setState(() {
              error = 'Glucose 20–600 mg/dL.';
              saving = false;
            });
            return;
          }
          glucoseMgdl = g;
        } else {
          if (g == null || g < 1 || g > 33) {
            setState(() {
              error = 'Glucose 1–33 mmol/L.';
              saving = false;
            });
            return;
          }
          glucoseMgdl = (mmolToMgdl(g) * 10).round() / 10;
        }
        extraMetrics['glucose'] = glucoseMgdl;
        bonusHp += hpGlucoseReward;
        _badges['glucose'] = true;
        await DailyVitalsService.markGlucoseLogged(_vitalsScope);
      }
      vitalsBonus = extraMetrics.isNotEmpty;
    }

    if (beforeSignUp) {
      if (_pendingAge == null || _pendingHeightCm == null || _pendingWeightKg == null) {
        setState(() { error = 'Complete Quest 2 first.'; saving = false; });
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
    }

    if (mounted) {
      setState(() {
        saving = false;
        quest3Done = true;
        step = 4;
      });
      if (bonusHp > 0) {
        _grantHp(bonusHp, toast: 'Bonus quest done!');
      }
      setState(() => _badges['champion'] = true);
    }
  }

  void _finishJourney() => widget.onComplete();

  @override
  Widget build(BuildContext context) {
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
                        levelTitle: _levelTitle,
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
                          padding: const EdgeInsets.all(24),
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
            (emoji: '🎯', label: 'Unit Pro', unlocked: _badges['units']!),
            (emoji: '🏗️', label: 'Foundation', unlocked: _badges['foundation']!),
            (emoji: '❤️', label: 'Heart Track', unlocked: _badges['heart']!),
            (emoji: '💧', label: 'Sugar Sense', unlocked: _badges['glucose']!),
            (emoji: '🏆', label: 'Champion', unlocked: _badges['champion']!),
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
          beforeSignUp ? 'Quest 1: Choose your world' : 'Pick your units',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.gray900),
        ),
        SizedBox(height: 6),
        Text(
          beforeSignUp
              ? 'Start your health journey — 3 quick quests, then sign up.'
              : 'Tailor charts and tips to your region.',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.gray500, fontSize: 14, height: 1.4),
        ),
        SizedBox(height: 16),
        OnboardingQuestCard(
          title: 'Quest 1 · Measurement realm',
          subtitle: 'Unlock charts in your language',
          reward: '+$hpUnitsReward HP',
          icon: Icons.public,
          accent: C.blue500,
        ),
        SizedBox(height: 16),
        _unitOption('imperial', '🇺🇸', 'Imperial', 'ft · lbs · mg/dL', C.neonCyan),
        SizedBox(height: 10),
        _unitOption('metric', '🌍', 'Metric', 'cm · kg · mmol/L', C.neonMint),
        SizedBox(height: 20),
        PrimaryButton(
          label: 'Start Quest 1 →',
          cosmicGradient: true,
          icon: Icon(Icons.play_arrow_rounded, size: 20, color: C.white),
          onPressed: _completeQuest1,
        ),
      ],
    );
  }

  Widget _unitOption(String value, String emoji, String title, String desc, Color accent) {
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
            Text(emoji, style: TextStyle(fontSize: 28)),
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
                child: Text('PICKED',
                    style: TextStyle(
                        color: C.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepGeneral() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _questHeader(),
        SizedBox(height: 12),
        _backChip(),
        SizedBox(height: 8),
        Text(
          'Quest 2: Build your avatar',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.gray900),
        ),
        SizedBox(height: 6),
        Text(
          'Fill all 3 fields — earn +$hpBasicReward HP on complete.',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.gray500, fontSize: 13),
        ),
        SizedBox(height: 16),
        if (error.isNotEmpty) ...[
          AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700),
          SizedBox(height: 12),
        ],
        _gameField(Icons.cake_outlined, C.orange50, C.orange500, 'Age', 'years', true,
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) {},
              decoration: appInput('e.g. 32'),
            )),
        SizedBox(height: 14),
        _gameField(
          Icons.straighten,
          C.sky50,
          C.sky500,
          'Height',
          isImperial ? 'ft & in' : 'cm',
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
                  SizedBox(width: 10),
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
                  decoration: appInput('e.g. 175'),
                ),
        ),
        SizedBox(height: 14),
        _gameField(
          Icons.monitor_weight_outlined,
          C.blue50,
          C.blue500,
          'Weight',
          isImperial ? 'lbs' : 'kg',
          true,
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            onChanged: (_) {},
            decoration: appInput(isImperial ? 'e.g. 165' : 'e.g. 70'),
          ),
        ),
        SizedBox(height: 20),
        PrimaryButton(
          label: saving ? 'Saving…' : 'Complete Quest 2 (+$hpBasicReward HP)',
          color: C.teal600,
          icon: Icon(Icons.military_tech, size: 18, color: C.white),
          onPressed: saving ? null : _submitGeneral,
        ),
      ],
    );
  }

  Widget _stepAdvanced() {
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
              Text('Back to Quest 2', style: TextStyle(fontSize: 12, color: C.gray400)),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Quest 3: Power-up (bonus)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.gray900),
        ),
        SizedBox(height: 6),
        Text(
          allLoggedToday
              ? 'You already logged BP and glucose today. Come back tomorrow for your next reading.'
              : 'Optional vitals — +$hpBpReward HP for BP, +$hpGlucoseReward HP for glucose. Once per day.',
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
                    '❤️ BP',
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
          _gameField(Icons.monitor_heart_outlined, C.red50, C.red500, 'Blood pressure', 'mmHg', false,
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _systolic,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    decoration: appInput('Sys'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _diastolic,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    decoration: appInput('Dia'),
                  ),
                ),
              ])),
          SizedBox(height: 14),
        ],
        if (showGlucose)
          _gameField(Icons.water_drop_outlined, C.teal50, C.teal500, 'Blood glucose',
              isImperial ? 'mg/dL' : 'mmol/L', false,
              TextField(
                controller: _glucose,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                decoration: appInput(isImperial ? 'e.g. 95' : 'e.g. 5.3'),
              )),
        SizedBox(height: 20),
        if (!allLoggedToday)
          PrimaryButton(
            label: saving ? 'Calculating rewards…' : 'Claim bonus & finish 🏆',
            color: C.amber600,
            icon: Icon(Icons.emoji_events, size: 18, color: C.white),
            onPressed: saving ? null : () => _finish(includeAdvanced: true),
          ),
        SizedBox(height: 8),
        TextButton(
          onPressed: saving ? null : () => _finish(includeAdvanced: false),
          child: Text(
            'Skip bonus quest',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('🎊', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
        SizedBox(height: 8),
        Text(
          'All quests complete!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: C.gray900),
        ),
        SizedBox(height: 8),
        Text(
          'You earned $hp HP · Level $_level $_levelTitle',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.teal400, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        if (hp >= maxOnboardingHp) ...[
          SizedBox(height: 8),
          Text(
            'Redeem your $maxOnboardingHp HP for $hpFirstPurchaseDiscountPercent% off your first 6-month or annual PHA Plus+ subscription.',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.amber700, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
        if (vitalsBonus) ...[
          SizedBox(height: 6),
          Text('Bonus vitals unlocked extra insights!',
              textAlign: TextAlign.center,
              style: TextStyle(color: C.gray500, fontSize: 13)),
        ],
        SizedBox(height: 16),
        OnboardingBadgeStrip(
          badges: [
            (emoji: '🎯', label: 'Unit Pro', unlocked: _badges['units']!),
            (emoji: '🏗️', label: 'Foundation', unlocked: _badges['foundation']!),
            (emoji: '❤️', label: 'Heart Track', unlocked: _badges['heart']!),
            (emoji: '💧', label: 'Sugar Sense', unlocked: _badges['glucose']!),
            (emoji: '🏆', label: 'Champion', unlocked: _badges['champion']!),
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
              Text('Health Power',
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
              Text('${(_power * 100).round()}% — ready for PHA',
                  style: TextStyle(color: C.white.withValues(alpha: 0.9), fontSize: 12)),
            ],
          ),
        ),
        SizedBox(height: 24),
        PrimaryButton(
          label: beforeSignUp ? 'Create account and become healthy →' : 'Enter dashboard →',
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
          Text(isImperial ? 'Imperial' : 'Metric',
              style: TextStyle(fontSize: 12, color: C.gray400, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _gameField(IconData icon, Color bg, Color fg, String label, String unit, bool required,
      Widget input) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: fg),
              ),
              SizedBox(width: 10),
              Text(label,
                  style: TextStyle(fontWeight: FontWeight.w700, color: C.gray900)),
              if (required) Text(' *', style: TextStyle(color: C.red500, fontWeight: FontWeight.bold)),
              Spacer(),
              Text(unit, style: TextStyle(fontSize: 11, color: C.gray400)),
            ],
          ),
          SizedBox(height: 10),
          input,
        ],
      ),
    );
  }
}
