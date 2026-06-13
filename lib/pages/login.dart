import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../cosmic_ui.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isSignUp = false;
  bool showPassword = false;
  bool loading = false;
  String error = '';
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      error = '';
      loading = true;
    });
    final auth = context.read<AuthProvider>();
    try {
      if (isSignUp) {
        if (_password.text.length < 8) throw Exception('Password must be at least 8 characters.');
        await auth.signUp(_email.text, _password.text, _name.text);
      } else {
        await auth.signIn(_email.text, _password.text);
      }
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _switchMode() {
    setState(() {
      isSignUp = !isSignUp;
      error = '';
      _email.clear();
      _password.clear();
      _name.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.gray50,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CosmicBackground(),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1024;
              return Row(
                children: [
                  if (wide) Expanded(child: _brandingPanel()),
                  Expanded(child: _formPanel(wide)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _brandingPanel() {
    final features = [
      (Icons.favorite, 'Track vitals & glucose', C.rose500, C.rose50),
      (Icons.monitor_heart, 'AI health insights', C.blue500, C.blue50),
      (Icons.shield, 'Private & secure', C.teal500, C.teal50),
      (Icons.auto_awesome, 'Smart analysis', C.amber500, C.amber50),
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: kNebulaGradient,
      ),
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: C.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.favorite, color: C.white, size: 32),
                ),
                SizedBox(height: 12),
                Text('PHA',
                    style: TextStyle(
                        color: C.white, fontWeight: FontWeight.bold, fontSize: 30, letterSpacing: -1)),
                Text('Personal Health Assistant',
                    style: TextStyle(color: C.onGradientMuted, fontSize: 14)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold, height: 1.2, color: C.white),
                  children: [
                    const TextSpan(text: 'Your health,\n'),
                    TextSpan(text: 'intelligently\n', style: TextStyle(color: C.teal200)),
                    const TextSpan(text: 'tracked.'),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Monitor your metrics, get AI-powered insights, and take control of your wellness journey.',
                style: TextStyle(color: C.onGradientMuted, fontSize: 18, height: 1.5),
              ),
              SizedBox(height: 32),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 3,
                children: features.map((f) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: f.$4, borderRadius: BorderRadius.circular(8)),
                          child: Icon(f.$1, size: 16, color: f.$3),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(f.$2,
                              style: TextStyle(
                                  color: C.white, fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Text('Trusted by health-conscious individuals worldwide.',
              style: TextStyle(color: C.blue200, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _formPanel(bool wide) {
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Column(
            children: [
              if (!wide) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: kBlueTealGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: C.glowShadow(blur: 10),
                  ),
                  child: Icon(Icons.favorite, color: C.white, size: 28),
                ),
                SizedBox(height: 12),
                Text('PHA',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 24, color: C.gray900)),
                Text('Personal Health Assistant',
                    style: TextStyle(color: C.gray500, fontSize: 14)),
                SizedBox(height: 32),
              ],
              Container(
                decoration: cardDecoration(),
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isSignUp ? 'Create your account' : 'Welcome back',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: C.gray900)),
                    SizedBox(height: 4),
                    Text(
                      isSignUp
                          ? 'Start tracking your health today — free forever.'
                          : 'Sign in to access your health dashboard.',
                      style: TextStyle(color: C.gray500, fontSize: 14),
                    ),
                    SizedBox(height: 24),
                    if (error.isNotEmpty) ...[
                      AppBanner(
                        text: error,
                        bg: C.red50,
                        border: C.red200,
                        fg: C.red700,
                        icon: Icons.error_outline,
                      ),
                      SizedBox(height: 16),
                    ],
                    if (isSignUp) ...[
                      _label('Full name'),
                      TextField(controller: _name, decoration: appInput('Jane Smith')),
                      SizedBox(height: 16),
                    ],
                    _label('Email address'),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: appInput('you@example.com'),
                    ),
                    SizedBox(height: 16),
                    _label('Password'),
                    TextField(
                      controller: _password,
                      obscureText: !showPassword,
                      decoration: appInput(isSignUp ? 'At least 8 characters' : '••••••••').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility,
                              size: 18, color: C.gray400),
                          onPressed: () => setState(() => showPassword = !showPassword),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    PrimaryButton(
                      label: loading
                          ? (isSignUp ? 'Creating account…' : 'Signing in…')
                          : (isSignUp ? 'Create account' : 'Sign in'),
                      onPressed: loading ? null : _submit,
                    ),
                    SizedBox(height: 24),
                    Divider(color: C.gray100, height: 1),
                    SizedBox(height: 24),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          Text(
                            isSignUp
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                            style: TextStyle(fontSize: 14, color: C.gray500),
                          ),
                          GestureDetector(
                            onTap: _switchMode,
                            child: Text(
                              isSignUp ? 'Sign in' : 'Sign up for free',
                              style: TextStyle(
                                  fontSize: 14, color: C.blue500, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSignUp) ...[
                SizedBox(height: 16),
                Text(
                  'By creating an account you agree to our Terms of Service and Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: C.gray400),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: C.gray700)),
      );
}
