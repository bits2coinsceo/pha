import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';
import 'models.dart';
import 'onboarding_prefs.dart';

const _uuid = Uuid();
String _hash(String password) => sha256.convert(utf8.encode('pha-salt::$password')).toString();

/// Local replacement for Supabase Auth + the AuthContext from the web app.
class AuthProvider extends ChangeNotifier {
  AppUser? user;
  bool loading = true;
  bool isPlus = false;
  String unitSystem = 'metric'; // 'metric' | 'imperial'

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('session_user_id');
    if (id != null) {
      final rows = await Db.instance.raw.query('profiles', where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        final r = rows.first;
        user = AppUser(id: r['id'] as String, email: r['email'] as String);
        await _loadPlanStatus(id);
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _loadPlanStatus(String userId) async {
    final rows = await Db.instance.raw.query('profiles', where: 'id = ?', whereArgs: [userId]);
    if (rows.isNotEmpty) {
      isPlus = (rows.first['is_plus'] as int) == 1;
      unitSystem = (rows.first['unit_system'] as String?) ?? 'metric';
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
    final existing = await Db.instance.raw.query('profiles', where: 'email = ?', whereArgs: [email]);
    if (existing.isNotEmpty) {
      throw Exception('This email is already registered. Please sign in instead.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    await Db.instance.raw.insert('profiles', {
      'id': id,
      'email': email,
      'password_hash': _hash(password),
      'display_name': displayName,
      'onboarding_completed': 0,
      'is_plus': 0,
      'unit_system': 'metric',
      'created_at': now,
      'updated_at': now,
    });
    await _setSession(id, email);
    await OnboardingPrefs.applyToUser(id);
    await _loadPlanStatus(id);
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    email = email.trim().toLowerCase();
    final rows = await Db.instance.raw.query('profiles', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty || rows.first['password_hash'] != _hash(password)) {
      throw Exception('Invalid email or password. Please check and try again.');
    }
    final r = rows.first;
    await _setSession(r['id'] as String, email);
    await _loadPlanStatus(r['id'] as String);
    notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
    user = null;
    isPlus = false;
    unitSystem = 'metric';
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
    await Db.instance.raw.update(
      'profiles',
      {
        'is_plus': 1,
        'subscription_plan': plan,
        'subscription_expires_at': expires.toUtc().toIso8601String(),
        'updated_at': now.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [user!.id],
    );
    isPlus = true;
    notifyListeners();
  }

  Future<void> _setSession(String id, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_user_id', id);
    user = AppUser(id: id, email: email);
  }
}
