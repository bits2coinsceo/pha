import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../db.dart';
import '../onboarding_prefs.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets.dart';
import 'onboarding_widgets.dart';

const _uuid = Uuid();
const _maxXp = 330;

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

class _OnboardingPageState extends State<OnboardingPage> with TickerProviderStateMixin {
  int step = 1;
  String unitSystem = 'metric';
  bool saving = false;
  String error = '';

  int xp = 0;
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

  String? _xpToastMsg;
  int _xpToastAmount = 0;

  bool _xpAge = false;
  bool _xpHeight = false;
  bool _xpWeight = false;

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

  bool get isImperial => unitSystem == 'imperial';
  bool get beforeSignUp => widget.beforeSignUp;

  int get _level => xp < 50 ? 1 : (xp < 170 ? 2 : 3);

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

  double get _power => (xp / _maxXp).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _bgFloat = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _toastCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

    _age.addListener(() {
      if (step == 2 && !_xpAge && _age.text.trim().isNotEmpty) _setXpAge();
    });
    _heightCm.addListener(() {
      if (step == 2 && !_xpHeight && _heightCm.text.trim().isNotEmpty) _setXpHeight();
    });
    _heightFt.addListener(() {
      if (step == 2 && !_xpHeight && _heightFt.text.trim().isNotEmpty) _setXpHeight();
    });
    _weight.addListener(() {
      if (step == 2 && !_xpWeight && _weight.text.trim().isNotEmpty) _setXpWeight();
    });
  }

  @override
  void dispose() {
    _bgFloat.dispose();
    _toastCtrl.dispose();
    for (final c in [_age, _heightCm, _heightFt, _heightIn, _weight, _systolic, _diastolic, _glucose]) {
      c.dispose();
    }
    super.dispose();
  }

  void _grantXp(int amount, {String? toast, String? badgeKey}) {
    setState(() {
      xp = (xp + amount).clamp(0, _maxXp);
      if (toast != null) {
        _xpToastMsg = toast;
        _xpToastAmount = amount;
      }
      if (badgeKey != null) _badges[badgeKey] = true;
    });
    if (toast != null) {
      _toastCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _xpToastMsg = null);
      });
    }
  }

  void _microFieldXp(bool Function() flag, VoidCallback setFlag, String toast) {
    if (flag()) return;
    setFlag();
    _grantXp(15, toast: toast);
  }

  void _setXpAge() => _microFieldXp(() => _xpAge, () => _xpAge = true, 'Age logged!');
  void _setXpHeight() => _microFieldXp(() => _xpHeight, () => _xpHeight = true, 'Height logged!');
  void _setXpWeight() => _microFieldXp(() => _xpWeight, () => _xpWeight = true, 'Weight logged!');

  Future<void> _markDone(AuthProvider auth) async {
    await Db.instance.raw.update(
      'profiles',
      {'onboarding_completed': 1, 'unit_system': unitSystem},
      where: 'id = ?',
      whereArgs: [auth.user!.id],
    );
    await auth.refreshPlanStatus();
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

  void _completeQuest1() {
    if (quest1Done) {
      setState(() => step = 2);
      return;
    }
    setState(() {
      quest1Done = true;
      step = 2;
    });
    _grantXp(50, toast: 'Quest 1 complete!', badgeKey: 'units');
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
    } else {
      final auth = context.read<AuthProvider>();
      await Db.instance.raw.update(
        'profiles',
        {'age': ageVal, 'height': heightCm, 'unit_system': unitSystem},
        where: 'id = ?',
        whereArgs: [auth.user!.id],
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
      _grantXp(120, toast: 'Quest 2 crushed!', badgeKey: 'foundation');
    }
  }

  Future<void> _finish({required bool includeAdvanced}) async {
    setState(() => saving = true);
    final extraMetrics = <String, double>{};
    var bonusXp = 0;

    if (includeAdvanced) {
      setState(() => error = '');
      if (_systolic.text.trim().isNotEmpty || _diastolic.text.trim().isNotEmpty) {
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
        bonusXp += 80;
        _badges['heart'] = true;
      }

      if (_glucose.text.trim().isNotEmpty) {
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
        bonusXp += 80;
        _badges['glucose'] = true;
      }
      vitalsBonus = extraMetrics.isNotEmpty;
    }

    if (beforeSignUp) {
      if (_pendingAge == null || _pendingHeightCm == null || _pendingWeightKg == null) {
        setState(() { error = 'Complete Quest 2 first.'; saving = false; });
        return;
      }
      await OnboardingPrefs.save(
        unitSystem: unitSystem,
        age: _pendingAge!,
        heightCm: _pendingHeightCm!,
        weightKg: _pendingWeightKg!,
        extraMetrics: extraMetrics,
      );
    } else {
      final auth = context.read<AuthProvider>();
      if (extraMetrics.isNotEmpty) {
        await _insertMetrics(auth, _metricRows(auth.user!.id, extraMetrics));
      }
      await _markDone(auth);
    }

    if (mounted) {
      setState(() {
        saving = false;
        quest3Done = true;
        step = 4;
      });
      final quest3Xp = includeAdvanced ? 40 + bonusXp : 40;
      _grantXp(quest3Xp, toast: includeAdvanced ? 'Bonus quest done!' : 'Quest 3 skipped');
      setState(() => _badges['champion'] = true);
    }
  }

  void _finishJourney() => widget.onComplete();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _animatedBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      if (_xpToastMsg != null) ...[
                        OnboardingXpToast(message: _xpToastMsg!, xp: _xpToastAmount),
                        const SizedBox(height: 6),
                      ],
                      OnboardingGameHud(
                        xp: xp,
                        level: _level,
                        levelTitle: _levelTitle,
                        power: _power,
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutCubic,
                        child: Container(
                          key: ValueKey(step),
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: C.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x28000000), blurRadius: 28, offset: Offset(0, 12)),
                            ],
                          ),
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

  Widget _animatedBackground() {
    return AnimatedBuilder(
      animation: _bgFloat,
      builder: (_, __) {
        final t = _bgFloat.value;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFDBEAFE), Color(0xFFCCFBF1), Color(0xFFD1FAE5)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -40 + t * 20,
                right: -30,
                child: _blob(140, C.blue200.withValues(alpha: 0.5)),
              ),
              Positioned(
                bottom: 80 - t * 15,
                left: -50,
                child: _blob(180, C.teal200.withValues(alpha: 0.45)),
              ),
              Positioned(
                top: 200 + t * 10,
                left: 40,
                child: _blob(90, C.amber200.withValues(alpha: 0.4)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
        const SizedBox(height: 14),
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
        const SizedBox(height: 12),
        Text(
          beforeSignUp ? 'Quest 1: Choose your world' : 'Pick your units',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.gray900),
        ),
        const SizedBox(height: 6),
        Text(
          beforeSignUp
              ? 'Start your health journey — 3 quick quests, then sign up.'
              : 'Tailor charts and tips to your region.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: C.gray500, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        const OnboardingQuestCard(
          title: 'Quest 1 · Measurement realm',
          subtitle: 'Unlock charts in your language',
          reward: '+50 XP',
          icon: Icons.public,
          accent: C.blue500,
        ),
        const SizedBox(height: 16),
        _unitOption('imperial', '🇺🇸', 'Imperial', 'ft · lbs · mg/dL', C.blue500, C.blue50),
        const SizedBox(height: 10),
        _unitOption('metric', '🌍', 'Metric', 'cm · kg · mmol/L', C.teal500, C.teal50),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Start Quest 1 →',
          color: C.blue600,
          icon: const Icon(Icons.play_arrow, size: 20, color: C.white),
          onPressed: _completeQuest1,
        ),
      ],
    );
  }

  Widget _unitOption(String value, String emoji, String title, String desc, Color accent, Color accentBg) {
    final selected = unitSystem == value;
    return GestureDetector(
      onTap: () => setState(() => unitSystem = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? accentBg : C.gray50,
          border: Border.all(color: selected ? accent : C.gray200, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: C.gray900)),
                  Text(desc, style: const TextStyle(fontSize: 12, color: C.gray500)),
                ],
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                child: const Text('PICKED',
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
        const SizedBox(height: 12),
        _backChip(),
        const SizedBox(height: 8),
        const Text(
          'Quest 2: Build your avatar',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.gray900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Fill all 3 fields — earn +15 XP per field, +120 XP on complete.',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.gray500, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (error.isNotEmpty) ...[
          AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700),
          const SizedBox(height: 12),
        ],
        _gameField(Icons.cake_outlined, C.orange50, C.orange500, 'Age', 'years', true,
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => _setXpAge(),
              decoration: appInput('e.g. 32'),
            )),
        const SizedBox(height: 14),
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
                      onChanged: (_) => _setXpHeight(),
                      decoration: appInput('ft'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _heightIn,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) => _setXpHeight(),
                      decoration: appInput('in'),
                    ),
                  ),
                ])
              : TextField(
                  controller: _heightCm,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => _setXpHeight(),
                  decoration: appInput('e.g. 175'),
                ),
        ),
        const SizedBox(height: 14),
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
            onChanged: (_) => _setXpWeight(),
            decoration: appInput(isImperial ? 'e.g. 165' : 'e.g. 70'),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: saving ? 'Saving…' : 'Complete Quest 2 (+120 XP)',
          color: C.teal600,
          icon: const Icon(Icons.military_tech, size: 18, color: C.white),
          onPressed: saving ? null : _submitGeneral,
        ),
      ],
    );
  }

  Widget _stepAdvanced() {
    final hasBp = _systolic.text.trim().isNotEmpty || _diastolic.text.trim().isNotEmpty;
    final hasGlucose = _glucose.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _questHeader(),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: saving ? null : () => setState(() { step = 2; error = ''; }),
          child: const Row(
            children: [
              Icon(Icons.arrow_back, size: 16, color: C.gray400),
              SizedBox(width: 4),
              Text('Back to Quest 2', style: TextStyle(fontSize: 12, color: C.gray400)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quest 3: Power-up (bonus)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.gray900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Optional vitals = up to +160 XP. Skip still earns +40 XP.',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.gray500, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bonusTile('❤️ BP', '+80 XP', hasBp && _diastolic.text.isNotEmpty && _systolic.text.isNotEmpty),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _bonusTile('💧 Glucose', '+80 XP', hasGlucose),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (error.isNotEmpty) ...[
          AppBanner(text: error, bg: C.red50, border: C.red200, fg: C.red700),
          const SizedBox(height: 12),
        ],
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
              const SizedBox(width: 10),
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
        const SizedBox(height: 14),
        _gameField(Icons.water_drop_outlined, C.teal50, C.teal500, 'Blood glucose',
            isImperial ? 'mg/dL' : 'mmol/L', false,
            TextField(
              controller: _glucose,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
              decoration: appInput(isImperial ? 'e.g. 95' : 'e.g. 5.3'),
            )),
        const SizedBox(height: 20),
        PrimaryButton(
          label: saving ? 'Calculating rewards…' : 'Claim bonus & finish 🏆',
          color: C.amber600,
          icon: const Icon(Icons.emoji_events, size: 18, color: C.white),
          onPressed: saving ? null : () => _finish(includeAdvanced: true),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: saving ? null : () => _finish(includeAdvanced: false),
          child: Text(
            'Skip bonus quest (+40 XP)',
            style: TextStyle(color: C.gray600, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _bonusTile(String label, String xp, bool active) {
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
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(xp,
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
        const Text('🎊', textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
        const SizedBox(height: 8),
        const Text(
          'All quests complete!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: C.gray900),
        ),
        const SizedBox(height: 8),
        Text(
          'You earned $xp XP · Level $_level $_levelTitle',
          textAlign: TextAlign.center,
          style: const TextStyle(color: C.teal600, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        if (vitalsBonus) ...[
          const SizedBox(height: 6),
          const Text('Bonus vitals unlocked extra insights!',
              textAlign: TextAlign.center,
              style: TextStyle(color: C.gray500, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        OnboardingBadgeStrip(
          badges: [
            (emoji: '🎯', label: 'Unit Pro', unlocked: _badges['units']!),
            (emoji: '🏗️', label: 'Foundation', unlocked: _badges['foundation']!),
            (emoji: '❤️', label: 'Heart Track', unlocked: _badges['heart']!),
            (emoji: '💧', label: 'Sugar Sense', unlocked: _badges['glucose']!),
            (emoji: '🏆', label: 'Champion', unlocked: _badges['champion']!),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: kBlueTealGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Health Power',
                  style: TextStyle(color: C.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _power,
                  minHeight: 12,
                  backgroundColor: C.white.withValues(alpha: 0.3),
                  color: C.amber300,
                ),
              ),
              const SizedBox(height: 6),
              Text('${(_power * 100).round()}% — ready for PHA',
                  style: TextStyle(color: C.white.withValues(alpha: 0.9), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: beforeSignUp ? 'Create account & play →' : 'Enter dashboard →',
          color: C.teal600,
          icon: const Icon(Icons.rocket_launch, size: 20, color: C.white),
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
          const Icon(Icons.chevron_left, size: 18, color: C.gray400),
          Text(isImperial ? 'Imperial' : 'Metric',
              style: const TextStyle(fontSize: 12, color: C.gray400, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _gameField(IconData icon, Color bg, Color fg, String label, String unit, bool required,
      Widget input) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.gray50,
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
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: C.gray800)),
              if (required) const Text(' *', style: TextStyle(color: C.red500, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(unit, style: const TextStyle(fontSize: 11, color: C.gray400)),
            ],
          ),
          const SizedBox(height: 10),
          input,
        ],
      ),
    );
  }
}
