import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';
import 'models.dart';
import 'onboarding_hp.dart';
import 'onboarding_prefs.dart';
import 'patient_sync.dart';
import 'telemetry_sync.dart';

const _uuid = Uuid();
String _hash(String password) => sha256.convert(utf8.encode('pha-salt::$password')).toString();

/// Free-tier features are available for this many days after account creation.
const freeTrialDays = 7;

/// Local replacement for Supabase Auth + the AuthContext from the web app.
class AuthProvider extends ChangeNotifier {
  AppUser? user;
  bool loading = true;
  bool isPlus = false;
  DateTime? accountCreatedAt;
  String unitSystem = 'metric'; // 'metric' | 'imperial'
  int healthPoints = 0;
  bool hpDiscountUsed = false;

  bool get hpDiscountEligible =>
      healthPoints >= maxOnboardingHp && !hpDiscountUsed;

  /// True when the 7-day free trial has ended and the user is not on Plus+.
  bool get isTrialExpired {
    if (isPlus || accountCreatedAt == null) return false;
    final trialEnd = accountCreatedAt!.add(const Duration(days: freeTrialDays));
    return DateTime.now().toUtc().isAfter(trialEnd);
  }

  /// Free-tier quick actions (uploads, AI chat, wellness, meals) while trial active.
  bool get hasFreeAccess => isPlus || !isTrialExpired;

  /// Days left in the free trial, or null for Plus+ / unknown.
  int? get trialDaysRemaining {
    if (isPlus || accountCreatedAt == null) return null;
    final trialEnd = accountCreatedAt!.add(const Duration(days: freeTrialDays));
    final days = trialEnd.difference(DateTime.now().toUtc()).inDays;
    return days < 0 ? 0 : days + 1;
  }

  /// Same hash stored in `profiles.password_hash` — used as the server sync token.
  static String passwordHash(String password) => _hash(password);

  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('session_user_id');
      if (id != null && Db.instance.isReady) {
        final rows =
            await Db.instance.raw.query('profiles', where: 'id = ?', whereArgs: [id]);
        if (rows.isNotEmpty) {
          final r = rows.first;
          user = AppUser(id: r['id'] as String, email: r['email'] as String);
          await _loadPlanStatus(id);
          // Defer network sync — must not block first frame / cold start.
          unawaited(_syncWithServer(id, user!.email));
        }
      }
    } catch (e, st) {
      debugPrint('AuthProvider.bootstrap failed: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPlanStatus(String userId) async {
    final rows = await Db.instance.raw.query('profiles', where: 'id = ?', whereArgs: [userId]);
    if (rows.isNotEmpty) {
      isPlus = (rows.first['is_plus'] as int) == 1;
      unitSystem = (rows.first['unit_system'] as String?) ?? 'metric';
      healthPoints = (rows.first['health_points'] as int?) ?? 0;
      hpDiscountUsed = ((rows.first['hp_discount_used'] as int?) ?? 0) == 1;
      accountCreatedAt =
          DateTime.tryParse(rows.first['created_at'] as String? ?? '');
    }
  }

  Future<void> refreshPlanStatus() async {
    if (user != null) {
      await _loadPlanStatus(user!.id);
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String displayName) async {
    email = email.trim().toLowerCase();
    if (await PatientSync.existsOnServer(email)) {
      throw Exception('This email is already registered. Please sign in instead.');
    }
    final existing = await Db.instance.raw.query('profiles', where: 'email = ?', whereArgs: [email]);
    if (existing.isNotEmpty) {
      throw Exception('This email is already registered. Please sign in instead.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    final token = _hash(password);
    await Db.instance.raw.insert('profiles', {
      'id': id,
      'email': email,
      'password_hash': token,
      'display_name': displayName,
      'onboarding_completed': 0,
      'is_plus': 0,
      'unit_system': 'metric',
      'created_at': now,
      'updated_at': now,
    });
    await _setSession(id, email);
    await OnboardingPrefs.applyToUser(id);
    await TelemetrySyncService.markNeedsPromptAfterSignUp(id);
    await _loadPlanStatus(id);
    await _syncWithServer(id, email);
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    email = email.trim().toLowerCase();
    final token = _hash(password);
    final rows = await Db.instance.raw.query('profiles', where: 'email = ?', whereArgs: [email]);
    if (rows.isNotEmpty) {
      if (rows.first['password_hash'] != token) {
        throw Exception('Invalid email or password. Please check and try again.');
      }
      final id = rows.first['id'] as String;
      await _setSession(id, email);
      await _syncWithServer(id, email);
      await _loadPlanStatus(id);
      notifyListeners();
      return;
    }

    final restoredId = await PatientSync.restoreFromServer(
      email: email,
      syncToken: token,
    );
    if (restoredId == null) {
      throw Exception('Invalid email or password. Please check and try again.');
    }
    await _setSession(restoredId, email);
    await _loadPlanStatus(restoredId);
    notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
    user = null;
    isPlus = false;
    accountCreatedAt = null;
    unitSystem = 'metric';
    healthPoints = 0;
    hpDiscountUsed = false;
    notifyListeners();
  }

  Future<void> upgradeToPlus(String plan) async {
    if (user == null) return;
    final now = DateTime.now();
    final expires = switch (plan) {
      'monthly' => DateTime(now.year, now.month + 1, now.day),
      'semiannual' => DateTime(now.year, now.month + 6, now.day),
      'annual' => DateTime(now.year + 1, now.month, now.day),
      _ => DateTime(now.year, now.month + 1, now.day),
    };
    final applyDiscount =
        hpDiscountEligible && planEligibleForHpDiscount(plan);
    await Db.instance.raw.update(
      'profiles',
      {
        'is_plus': 1,
        'subscription_plan': plan,
        'subscription_expires_at': expires.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
        if (applyDiscount) 'hp_discount_used': 1,
        if (applyDiscount) 'health_points': 0,
      },
      where: 'id = ?',
      whereArgs: [user!.id],
    );
    isPlus = true;
    if (applyDiscount) {
      hpDiscountUsed = true;
      healthPoints = 0;
    }
    notifyListeners();
    await _syncWithServer(user!.id, user!.email);
  }

  Future<void> _setSession(String id, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_user_id', id);
    user = AppUser(id: id, email: email);
  }

  /// Uploads/pulls patient history from the server (e.g. on app resume).
  Future<void> syncPatientHistory() async {
    if (user == null) return;
    await _syncWithServer(user!.id, user!.email);
  }

  /// Pulls newer server history, then uploads the latest local snapshot.
  Future<void> _syncWithServer(String userId, String email) async {
    final rows = await Db.instance.raw.query(
      'profiles',
      columns: ['password_hash'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final syncToken = rows.first['password_hash'] as String;
    try {
      await PatientSync.pullAndMerge(
        email: email,
        syncToken: syncToken,
        userId: userId,
      );
      await PatientSync.push(
        email: email,
        syncToken: syncToken,
        userId: userId,
      );
    } catch (_) {
      // Offline or server unavailable — local data still works.
    }
  }
}
