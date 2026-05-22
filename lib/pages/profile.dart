import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../db.dart';
import '../theme.dart';
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
      if (age == null || age < 1 || age > 120) {
        setState(() {
          error = 'Age must be between 1 and 120.';
          saving = false;
        });
        return;
      }
    }
    int? height;
    if (_height.text.isNotEmpty) {
      height = int.tryParse(_height.text);
      if (height == null || height < 50 || height > 250) {
        setState(() {
          error = 'Height must be between 50 and 250 cm.';
          saving = false;
        });
        return;
      }
    }
    await Db.instance.raw.update(
      'profiles',
      {'display_name': _name.text, 'age': age, 'height': height},
      where: 'id = ?',
      whereArgs: [userId],
    );
    setState(() {
      saving = false;
      success = 'Profile updated successfully!';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: C.gray50,
      body: Column(
        children: [
          pageHeader('Profile', 'Manage your account settings'),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
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
                                const SizedBox(height: 24),
                              ],
                              if (success.isNotEmpty) ...[
                                AppBanner(
                                    text: success,
                                    bg: C.green50,
                                    border: C.green200,
                                    fg: C.teal700,
                                    icon: Icons.check_circle),
                                const SizedBox(height: 24),
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
                                          decoration: const BoxDecoration(
                                            gradient: kBlueTealGradient,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.person,
                                              color: C.white, size: 32),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Email',
                                                  style: TextStyle(
                                                      fontSize: 14, color: C.gray600)),
                                              Text(auth.user?.email ?? '',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: C.gray900)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    _label('Display Name', null, null),
                                    TextField(
                                        controller: _name,
                                        decoration: appInput('Your name')),
                                    const SizedBox(height: 16),
                                    _label('Age', Icons.account_circle, C.orange500),
                                    TextField(
                                        controller: _age, decoration: appInput('e.g. 32')),
                                    const SizedBox(height: 16),
                                    _label('Height (cm)', Icons.straighten, C.sky500),
                                    TextField(
                                        controller: _height,
                                        decoration: appInput('e.g. 175')),
                                    const SizedBox(height: 24),
                                    PrimaryButton(
                                      label: saving ? 'Saving...' : 'Save Changes',
                                      onPressed: saving ? null : _save,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                decoration: cardDecoration(border: C.gray200),
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Account',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: C.gray900)),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: () => auth.signOut(),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: C.red500,
                                        side: const BorderSide(color: C.red500, width: 2),
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                        minimumSize: const Size(double.infinity, 0),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
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
              const SizedBox(width: 6),
            ],
            Text(text,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: C.gray900)),
          ],
        ),
      );
}
