import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../db.dart';
import '../legal.dart';
import '../medical_guidelines.dart';
import '../profile_basics.dart';
import '../cosmic_ui.dart';
import '../theme.dart';
import '../theme_mode.dart';
import '../widgets.dart';
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
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
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
    _weight.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user!.id;
    final rows = await Db.instance.raw.query('profiles', where: 'id = ?', whereArgs: [userId]);
    if (rows.isNotEmpty) {
      final r = rows.first;
      _name.text = (r['display_name'] as String?) ?? '';
      _age.text = r['age'] != null ? '${r['age']}' : '';
      _height.text = r['height'] != null ? '${(r['height'] as num).toInt()}' : '';
      _weight.text = r['weight'] != null
          ? (r['weight'] as num).toStringAsFixed((r['weight'] as num) % 1 == 0 ? 0 : 1)
          : '';
    }
    setState(() => loading = false);
  }

  Future<void> _save() async {
    final userId = context.read<AuthProvider>().user!.id;
    setState(() {
      saving = true;
      error = '';
      success = '';
    });
    int? age;
    if (_age.text.isNotEmpty) {
      age = int.tryParse(_age.text);
      if (VitalValidation.age(age) != null) {
        setState(() {
          error = VitalValidation.age(age)!;
          saving = false;
        });
        return;
      }
    }
    int? height;
    if (_height.text.isNotEmpty) {
      height = int.tryParse(_height.text);
      final hErr = VitalValidation.heightCm(height?.toDouble());
      if (hErr != null) {
        setState(() {
          error = hErr;
          saving = false;
        });
        return;
      }
    }
    double? weight;
    if (_weight.text.isNotEmpty) {
      weight = double.tryParse(_weight.text.trim());
      final wErr = VitalValidation.weightKg(weight);
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
      {'display_name': _name.text},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await ProfileBasicsService.save(
      userId: userId,
      age: age,
      heightCm: height,
      weightKg: weight,
    );
    setState(() {
      saving = false;
      success = 'Profile updated successfully!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeMode = context.watch<ThemeModeController>();
    return CosmicScaffold(
      body: Column(
        children: [
          pageHeader('Profile', 'Manage your account settings'),
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
                                              Text('Email',
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
                                    _label('Display Name', null, null),
                                    TextField(
                                      controller: _name,
                                      style: TextStyle(
                                        color: C.gray900,
                                        fontSize: 16,
                                      ),
                                      cursorColor: C.accentFocus,
                                      textInputAction: TextInputAction.next,
                                      decoration: appInput('Your name'),
                                    ),
                                    SizedBox(height: 16),
                                    _label('Age', Icons.account_circle, C.orange500),
                                    TextField(
                                      controller: _age,
                                      style: TextStyle(
                                        color: C.gray900,
                                        fontSize: 16,
                                      ),
                                      cursorColor: C.accentFocus,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      decoration: appInput('e.g. 32'),
                                    ),
                                    SizedBox(height: 16),
                                    _label('Height (cm)', Icons.straighten, C.sky500),
                                    TextField(
                                      controller: _height,
                                      style: TextStyle(
                                        color: C.gray900,
                                        fontSize: 16,
                                      ),
                                      cursorColor: C.accentFocus,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      decoration: appInput('e.g. 175'),
                                    ),
                                    SizedBox(height: 16),
                                    _label('Weight (kg)', Icons.monitor_weight, C.blue500),
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
                                      decoration: appInput('e.g. 70'),
                                    ),
                                    SizedBox(height: 24),
                                    PrimaryButton(
                                      label: saving ? 'Saving...' : 'Save Changes',
                                      onPressed: saving ? null : _save,
                                    ),
                                  ],
                                ),
                              ),
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
                                          Text('Appearance',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: C.gray900)),
                                          Text(
                                            themeMode.isDark ? 'Dark theme' : 'Light theme',
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
                                    Text('Account',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: C.gray900)),
                                    SizedBox(height: 12),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.description_outlined,
                                          color: C.blue500),
                                      title: Text('Agreement',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: C.gray900)),
                                      subtitle: Text('Terms of Service & Disclaimer',
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
                                      title: Text('Privacy Policy',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: C.gray900)),
                                      subtitle: Text('How we handle your data',
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
                                          Text('Sign Out',
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
}
