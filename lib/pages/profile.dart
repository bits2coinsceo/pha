import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../daily_vitals.dart';
import '../db.dart';
import '../l10n/l10n_ext.dart';
import '../legal.dart';
import '../medical_guidelines.dart';
import '../profile_basics.dart';
import '../cosmic_ui.dart';
import '../theme.dart';
import '../theme_mode.dart';
import '../units.dart';
import '../widgets.dart';
import '../widgets/language_picker.dart';
import 'history.dart' show pageHeader;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool loading = true;
  bool saving = false;
  String error = '';
  String success = '';
  VitalsPromptMode _vitalsPromptMode = VitalsPromptMode.daily;
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _heightFt = TextEditingController();
  final _heightIn = TextEditingController();
  final _weight = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _heightFt.dispose();
    _heightIn.dispose();
    _weight.dispose();
    super.dispose();
  }

  bool get _isImperial =>
      context.read<AuthProvider>().unitSystem == 'imperial';

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user!.id;
    final imperial = auth.unitSystem == 'imperial';
    final rows = await Db.instance.raw.query('profiles', where: 'id = ?', whereArgs: [userId]);
    if (rows.isNotEmpty) {
      final r = rows.first;
      _name.text = (r['display_name'] as String?) ?? '';
      _age.text = r['age'] != null ? '${r['age']}' : '';
      final heightCm = (r['height'] as num?)?.toDouble();
      final weightKg = (r['weight'] as num?)?.toDouble();
      if (heightCm != null) {
        if (imperial) {
          final h = cmToFtIn(heightCm);
          _heightFt.text = '${h.ft}';
          _heightIn.text = '${h.inch}';
        } else {
          _height.text = '${heightCm.round()}';
        }
      }
      if (weightKg != null) {
        _weight.text = imperial
            ? kgToLbs(weightKg).toStringAsFixed(0)
            : weightKg.toStringAsFixed(weightKg % 1 == 0 ? 0 : 1);
      }
    }
    final mode = await DailyVitalsService.getPromptMode(userId);
    if (!mounted) return;
    setState(() {
      _vitalsPromptMode = mode;
      loading = false;
    });
  }

  Future<void> _setVitalsPromptMode(VitalsPromptMode mode) async {
    final userId = context.read<AuthProvider>().user!.id;
    setState(() => _vitalsPromptMode = mode);
    await DailyVitalsService.setPromptMode(userId, mode);
  }

  double? _parseHeightCm() {
    if (_isImperial) {
      if (_heightFt.text.trim().isEmpty && _heightIn.text.trim().isEmpty) {
        return null;
      }
      final ft = parseUserNumber(_heightFt.text) ?? 0;
      final inch = parseUserNumber(_heightIn.text) ?? 0;
      return ftInToCm(ft, inch);
    }
    if (_height.text.trim().isEmpty) return null;
    return parseUserNumber(_height.text);
  }

  double? _parseWeightKg() {
    if (_weight.text.trim().isEmpty) return null;
    final v = parseUserNumber(_weight.text);
    if (v == null) return null;
    return _isImperial ? lbsToKg(v) : v;
  }

  Future<void> _save() async {
    final userId = context.read<AuthProvider>().user!.id;
    final l10n = context.l10n;
    setState(() {
      saving = true;
      error = '';
      success = '';
    });
    int? age;
    if (_age.text.isNotEmpty) {
      age = int.tryParse(_age.text);
      if (VitalValidation.age(age, l10n) != null) {
        setState(() {
          error = VitalValidation.age(age, l10n)!;
          saving = false;
        });
        return;
      }
    }
    final heightCm = _parseHeightCm();
    if (_height.text.isNotEmpty ||
        _heightFt.text.isNotEmpty ||
        _heightIn.text.isNotEmpty) {
      final hErr = VitalValidation.heightCm(heightCm, l10n);
      if (hErr != null) {
        setState(() {
          error = hErr;
          saving = false;
        });
        return;
      }
    }
    final weightKg = _parseWeightKg();
    if (_weight.text.isNotEmpty) {
      final wErr = VitalValidation.weightKg(weightKg, l10n);
      if (wErr != null) {
        setState(() {
          error = wErr;
          saving = false;
        });
        return;
      }
    }
    await Db.instance.raw.update(
      'profiles',
      // Keep the name exactly as the user typed it — never localize/transliterate.
      {'display_name': _name.text.trim()},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await ProfileBasicsService.save(
      userId: userId,
      age: age,
      heightCm: heightCm?.round(),
      weightKg: weightKg,
    );
    setState(() {
      saving = false;
      success = l10n.profileUpdatedSuccess;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final imperial = auth.unitSystem == 'imperial';
    final themeMode = context.watch<ThemeModeController>();
    final l10n = context.l10n;
    return CosmicScaffold(
      body: Column(
        children: [
          pageHeader(context.l10n.profileTitle, context.l10n.profileSubtitle),
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 672),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                          child: Column(
                            children: [
                              if (error.isNotEmpty) ...[
                                AppBanner(
                                    text: error,
                                    bg: C.red50,
                                    border: C.red200,
                                    fg: C.red700,
                                    icon: Icons.error_outline),
                                SizedBox(height: 24),
                              ],
                              if (success.isNotEmpty) ...[
                                AppBanner(
                                    text: success,
                                    bg: C.green50,
                                    border: C.green200,
                                    fg: C.teal700,
                                    icon: Icons.check_circle),
                                SizedBox(height: 24),
                              ],
                              Container(
                                decoration: cardDecoration(border: C.gray200),
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: kBlueTealGradient,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.person,
                                              color: C.white, size: 32),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(context.l10n.email,
                                                  style: TextStyle(
                                                      fontSize: 14, color: C.gray600)),
                                              Text(auth.user?.email ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: C.gray900)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 32),
                                    _label(context.l10n.displayName, null, null),
                                    TextField(
                                      controller: _name,
                                      style: TextStyle(
                                        color: C.gray900,
                                        fontSize: 16,
                                      ),
                                      cursorColor: C.accentFocus,
                                      textInputAction: TextInputAction.next,
                                      decoration: appInput(context.l10n.yourName),
                                    ),
                                    SizedBox(height: 16),
                                    _label(context.l10n.age, Icons.account_circle, C.orange500),
                                    TextField(
                                      controller: _age,
                                      style: TextStyle(
                                        color: C.gray900,
                                        fontSize: 16,
                                      ),
                                      cursorColor: C.accentFocus,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      decoration: appInput(context.l10n.onboardingAgeHint),
                                    ),
                                    SizedBox(height: 16),
                                    _label(
                                      imperial
                                          ? 'ft & in'
                                          : l10n.heightCm,
                                      Icons.straighten,
                                      C.sky500,
                                    ),
                                    if (imperial)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _heightFt,
                                              style: TextStyle(
                                                color: C.gray900,
                                                fontSize: 16,
                                              ),
                                              cursorColor: C.accentFocus,
                                              keyboardType:
                                                  TextInputType.number,
                                              textInputAction:
                                                  TextInputAction.next,
                                              decoration: appInput('ft'),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: TextField(
                                              controller: _heightIn,
                                              style: TextStyle(
                                                color: C.gray900,
                                                fontSize: 16,
                                              ),
                                              cursorColor: C.accentFocus,
                                              keyboardType:
                                                  TextInputType.number,
                                              textInputAction:
                                                  TextInputAction.next,
                                              decoration: appInput('in'),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      TextField(
                                        controller: _height,
                                        style: TextStyle(
                                          color: C.gray900,
                                          fontSize: 16,
                                        ),
                                        cursorColor: C.accentFocus,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        decoration: appInput(
                                          l10n.onboardingHeightHintMetric,
                                        ),
                                      ),
                                    SizedBox(height: 16),
                                    _label(
                                      imperial
                                          ? l10n.unitLbs
                                          : l10n.weightKg,
                                      Icons.monitor_weight,
                                      C.blue500,
                                    ),
                                    TextField(
                                      controller: _weight,
                                      style: TextStyle(
                                        color: C.gray900,
                                        fontSize: 16,
                                      ),
                                      cursorColor: C.accentFocus,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      textInputAction: TextInputAction.done,
                                      decoration: appInput(
                                        imperial
                                            ? l10n.onboardingWeightHintImperial
                                            : l10n.onboardingWeightHintMetric,
                                      ),
                                    ),
                                    SizedBox(height: 24),
                                    PrimaryButton(
                                      label: saving ? context.l10n.loading : context.l10n.saveChanges,
                                      onPressed: saving ? null : _save,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24),
                              _vitalsPromptCard(l10n),
                              SizedBox(height: 24),
                              // Not const — must rebuild with ThemeModeController / C.* colors.
                              LanguagePicker(expanded: true),
                              SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                decoration: cardDecoration(border: C.gray200),
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: C.blue50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        themeMode.isDark ? Icons.dark_mode : Icons.light_mode,
                                        color: C.accentPrimary,
                                        size: 22,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(context.l10n.appearance,
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: C.gray900)),
                                          Text(
                                            themeMode.isDark
                                                ? context.l10n.themeDark
                                                : context.l10n.themeLight,
                                            style: TextStyle(
                                                fontSize: 13, color: C.gray500),
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
                              ),
                              SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                decoration: cardDecoration(border: C.gray200),
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.l10n.account,
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: C.gray900)),
                                    SizedBox(height: 12),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.description_outlined,
                                          color: C.blue500),
                                      title: Text(context.l10n.agreement,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: C.gray900)),
                                      subtitle: Text(context.l10n.termsOfService,
                                          style: TextStyle(
                                              fontSize: 12, color: C.gray500)),
                                      trailing: Icon(Icons.chevron_right,
                                          color: C.gray400),
                                      onTap: () => LegalDocumentPage.open(
                                          context, LegalDocument.termsOfService),
                                    ),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.privacy_tip_outlined,
                                          color: C.teal600),
                                      title: Text(context.l10n.privacyPolicy,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: C.gray900)),
                                      subtitle: Text(context.l10n.howWeHandleData,
                                          style: TextStyle(
                                              fontSize: 12, color: C.gray500)),
                                      trailing: Icon(Icons.chevron_right,
                                          color: C.gray400),
                                      onTap: () => LegalDocumentPage.open(
                                          context, LegalDocument.privacyPolicy),
                                    ),
                                    SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () => auth.signOut(),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: C.red500,
                                        side: BorderSide(color: C.red500, width: 2),
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                        minimumSize: const Size(double.infinity, 0),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.logout, size: 20),
                                          SizedBox(width: 8),
                                          Text(context.l10n.signOut,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w500)),
                                        ],
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
          ),
        ],
      ),
    );
  }

  Widget _label(String text, IconData? icon, Color? iconColor) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor),
              SizedBox(width: 6),
            ],
            Text(text,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: C.gray900)),
          ],
        ),
      );

  Widget _vitalsPromptCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      decoration: cardDecoration(border: C.gray200),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: C.rose50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.monitor_heart_outlined,
                    color: C.rose600, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.vitalsPromptSectionTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: C.gray900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.vitalsPromptSectionSubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: C.gray500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _vitalsPromptOption(
            mode: VitalsPromptMode.daily,
            title: l10n.vitalsPromptDaily,
            subtitle: l10n.vitalsPromptDailyHint,
          ),
          _vitalsPromptOption(
            mode: VitalsPromptMode.every5Days,
            title: l10n.vitalsPromptEvery5Days,
            subtitle: l10n.vitalsPromptEvery5DaysHint,
          ),
          _vitalsPromptOption(
            mode: VitalsPromptMode.off,
            title: l10n.vitalsPromptNever,
            subtitle: l10n.vitalsPromptNeverHint,
          ),
        ],
      ),
    );
  }

  Widget _vitalsPromptOption({
    required VitalsPromptMode mode,
    required String title,
    required String subtitle,
  }) {
    final selected = _vitalsPromptMode == mode;
    return InkWell(
      onTap: () => _setVitalsPromptMode(mode),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 22,
                color: selected ? C.accentPrimary : C.gray400,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: C.gray900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: C.gray500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
