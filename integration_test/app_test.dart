import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pha_flutter/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding → sign up → all pages', (tester) async {
    await binding.convertFlutterSurfaceToImage();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    // ── Onboarding first (before login) ──
    expect(find.textContaining('Quest 1'), findsOneWidget);
    await shot('01_onboarding_units');
    await tester.tap(find.text('Start Quest 1 →'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Quest 2'), findsOneWidget);
    await shot('02_onboarding_general');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 32'), '30');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 175'), '180');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 70'), '72');
    await tester.tap(find.text('Complete Quest 2 (+5 HP)'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.textContaining('Quest 3'), findsOneWidget);
    await shot('03_onboarding_advanced');
    await tester.tap(find.text('Skip bonus quest'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.textContaining('All quests complete'), findsOneWidget);
    await tester.tap(find.text('Create account and become healthy →'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // ── Login / sign up ──
    expect(find.text('Welcome back'), findsOneWidget);
    await shot('04_login');
    await tester.tap(find.text('Sign up for free'));
    await tester.pumpAndSettle();

    final email = 'test_${DateTime.now().millisecondsSinceEpoch}@example.com';
    await tester.enterText(find.widgetWithText(TextField, 'Jane Smith'), 'Test User');
    await tester.enterText(find.widgetWithText(TextField, 'you@example.com'), email);
    await tester.enterText(
        find.widgetWithText(TextField, 'At least 8 characters'), 'password123');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ── Dashboard (no second onboarding) ──
    expect(find.text('Quick Actions'), findsOneWidget);
    await shot('05_dashboard');

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Health History'), findsOneWidget);
    await shot('06_history');

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Health Insights'), findsOneWidget);
    await shot('07_insights');

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Manage your account settings'), findsOneWidget);
    await shot('08_profile');

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Quick Actions'), findsOneWidget);
  });
}
