import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'db.dart';
import 'models.dart';
import 'onboarding_hp.dart';
import 'onboarding_prefs.dart';
import 'patient_sync.dart';
import 'pha_purchases.dart';
import 'promo_codes.dart';
import 'telemetry_sync.dart';
import 'trial_notifications.dart';

const _uuid = Uuid();
String _hash(String password) => sha256.convert(utf8.encode('pha-salt::$password')).toString();

/// Typed auth failures so the UI can show localized messages.
class AuthException implements Exception {
  final String code;
  AuthException(this.code);

  static const emailAlreadyRegistered = 'email_already_registered';
  static const invalidCredentials = 'invalid_credentials';
  /// Email/password OK locally but no server backup yet (other device cannot restore).
  static const accountNotOnServer = 'account_not_on_server';
  static const networkError = 'network_error';
  static const serverSyncFailed = 'server_sync_failed';

  @override
  String toString() => code;
}

/// Promo-code redemption failures for Upgrade UI.
class PromoException implements Exception {
  final String code;
  PromoException(this.code);

  static const invalid = 'invalid';
  static const alreadyUsed = 'already_used';

  @override
  String toString() => code;
}

/// Free-tier features are available for this many days after account creation.
const freeTrialDays = 7;

/// Local replacement for Supabase Auth + the AuthContext from the web app.
class AuthProvider extends ChangeNotifier {
  AppUser? user;
  bool loading = true;
  bool isPlus = false;
  DateTime? accountCreatedAt;
  DateTime? subscriptionExpiresAt;
  String unitSystem = 'metric'; // 'metric' | 'imperial'
  int healthPoints = 0;
  bool hpDiscountUsed = false;
  List<String> _promoCodesUsed = const [];

  bool get hpDiscountEligible => !hpDiscountUsed;

  /// UTC end of the 7-day free trial, or null when Plus / unknown start.
  DateTime? get trialEndsAt {
    if (isPlus || accountCreatedAt == null) return null;
    return accountCreatedAt!.toUtc().add(const Duration(days: freeTrialDays));
  }

  /// True when the 7-day free trial has ended and the user is not on Plus+.
  bool get isTrialExpired {
    final end = trialEndsAt;
    if (end == null) return false;
    return DateTime.now().toUtc().isAfter(end);
  }

  /// Free-tier quick actions (uploads, AI chat, wellness, meals, log metric)
  /// while the trial is active; Plus+ unlocks the rest.
  bool get hasFreeAccess => isPlus || !isTrialExpired;

  /// Days left in the free trial, or null for Plus+ / unknown.
  int? get trialDaysRemaining {
    final end = trialEndsAt;
    if (end == null) return null;
    final days = end.difference(DateTime.now().toUtc()).inDays;
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
      final r = rows.first;
      unitSystem = (r['unit_system'] as String?) ?? 'metric';
      healthPoints = (r['health_points'] as int?) ?? 0;
      hpDiscountUsed = ((r['hp_discount_used'] as int?) ?? 0) == 1;
      accountCreatedAt = DateTime.tryParse(r['created_at'] as String? ?? '');
      final expiresRaw = r['subscription_expires_at'] as String?;
      subscriptionExpiresAt =
          expiresRaw == null || expiresRaw.isEmpty ? null : DateTime.tryParse(expiresRaw);
      _promoCodesUsed = _parsePromoCodesUsed(r['promo_codes_used']);

      var plus = (r['is_plus'] as int) == 1;
      if (plus &&
          subscriptionExpiresAt != null &&
          DateTime.now().toUtc().isAfter(subscriptionExpiresAt!.toUtc())) {
        plus = false;
        subscriptionExpiresAt = null;
        await Db.instance.raw.update(
          'profiles',
          {
            'is_plus': 0,
            'subscription_expires_at': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
      isPlus = plus;
    }
  }

  List<String> _parsePromoCodesUsed(Object? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw is String ? raw : raw.toString());
      if (decoded is! List) return const [];
      return decoded.map((e) => e.toString()).toList(growable: false);
    } catch (_) {
      return const [];
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
    final existing = await Db.instance.raw.query(
      'profiles',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (existing.isNotEmpty) {
      throw AuthException(AuthException.emailAlreadyRegistered);
    }
    // Server history is keyed by email — block re-registration of an existing account.
    try {
      if (await ApiClient.patientExists(email)) {
        throw AuthException(AuthException.emailAlreadyRegistered);
      }
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(AuthException.networkError);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    final token = _hash(password);
    final nameAsEntered = displayName.trim();
    await Db.instance.raw.insert('profiles', {
      'id': id,
      'email': email,
      'password_hash': token,
      'display_name': nameAsEntered,
      'onboarding_completed': 0,
      'is_plus': 0,
      'unit_system': 'metric',
      'created_at': now,
      'updated_at': now,
    });

    // Registration must land on the server so other devices can restore by email.
    try {
      await PatientSync.push(email: email, syncToken: token, userId: id);
    } catch (_) {
      await Db.instance.raw.delete('profiles', where: 'id = ?', whereArgs: [id]);
      throw AuthException(AuthException.serverSyncFailed);
    }

    await _setSession(id, email);
    await TelemetrySyncService.markNeedsPromptAfterSignUp(id);
    await _loadPlanStatus(id);
    unawaited(PhaPurchases.configure(appUserId: id));
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    email = email.trim().toLowerCase();
    final token = _hash(password);

    // Cross-device: prefer restoring the email-keyed server backup first.
    try {
      final remote = await ApiClient.getPatientHistory(
        email: email,
        syncToken: token,
      );
      if (remote != null) {
        final userId = await PatientSync.applyRemoteSnapshot(
          email: email,
          syncToken: token,
          remote: remote,
        );
        await _setSession(userId, email);
        await _loadPlanStatus(userId);
        await _markPreOnboardingDoneIfProfileComplete(userId);
        unawaited(PhaPurchases.configure(appUserId: userId));
        // Keep server backup fresh after restore.
        unawaited(_syncWithServer(userId, email));
        notifyListeners();
        return;
      }
      // 404 — no history on server for this email.
    } on ApiException catch (e) {
      if (e.status == 403) {
        throw AuthException(AuthException.invalidCredentials);
      }
      // Network / other — fall through to local profile if present.
    } catch (_) {
      // Offline — fall through to local.
    }

    final rows =
        await Db.instance.raw.query('profiles', where: 'email = ?', whereArgs: [email]);
    if (rows.isNotEmpty) {
      if (rows.first['password_hash'] != token) {
        throw AuthException(AuthException.invalidCredentials);
      }
      final id = rows.first['id'] as String;
      await _setSession(id, email);
      await _syncWithServer(id, email);
      await _loadPlanStatus(id);
      await _markPreOnboardingDoneIfProfileComplete(id);
      unawaited(PhaPurchases.configure(appUserId: id));
      notifyListeners();
      return;
    }

    // No server backup and no local profile.
    try {
      final exists = await ApiClient.patientExists(email);
      if (exists) {
        // Meta exists but history missing or token mismatch already handled → wrong password
        throw AuthException(AuthException.invalidCredentials);
      }
      throw AuthException(AuthException.accountNotOnServer);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(AuthException.networkError);
    }
  }

  Future<void> _markPreOnboardingDoneIfProfileComplete(String userId) async {
    final rows = await Db.instance.raw.query(
      'profiles',
      columns: ['onboarding_completed', 'age', 'height', 'weight'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final completed = (rows.first['onboarding_completed'] as int?) == 1;
    final hasBasics = rows.first['age'] != null &&
        rows.first['height'] != null &&
        rows.first['weight'] != null;
    if (completed && hasBasics) {
      await OnboardingPrefs.markDevicePreOnboardingDone();
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
    user = null;
    isPlus = false;
    accountCreatedAt = null;
    subscriptionExpiresAt = null;
    unitSystem = 'metric';
    healthPoints = 0;
    hpDiscountUsed = false;
    _promoCodesUsed = const [];
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
      },
      where: 'id = ?',
      whereArgs: [user!.id],
    );
    isPlus = true;
    subscriptionExpiresAt = expires.toUtc();
    if (applyDiscount) {
      hpDiscountUsed = true;
    }
    notifyListeners();
    unawaited(TrialNotificationService.cancelAll());
    await _syncWithServer(user!.id, user!.email);
  }

  /// Redeems a built-in test promo code and unlocks Plus+ locally.
  Future<void> redeemPromoCode(String raw) async {
    if (user == null) return;
    final match = PhaPromoCodes.match(raw);
    if (match == null) {
      throw PromoException(PromoException.invalid);
    }
    if (match.oncePerProfile && _promoCodesUsed.contains(match.id)) {
      throw PromoException(PromoException.alreadyUsed);
    }

    final now = DateTime.now().toUtc();
    final expires = match.duration == null ? null : now.add(match.duration!);
    final used = [..._promoCodesUsed];
    if (!used.contains(match.id)) {
      used.add(match.id);
    }

    await Db.instance.raw.update(
      'profiles',
      {
        'is_plus': 1,
        'subscription_plan': 'promo_${match.id}',
        'subscription_expires_at': expires?.toIso8601String(),
        'promo_codes_used': jsonEncode(used),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [user!.id],
    );
    isPlus = true;
    subscriptionExpiresAt = expires;
    _promoCodesUsed = List.unmodifiable(used);
    notifyListeners();
    unawaited(TrialNotificationService.cancelAll());
    await _syncWithServer(user!.id, user!.email);
  }

  Future<void> _setSession(String id, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_user_id', id);
    user = AppUser(id: id, email: email);
  }

  /// Uploads local history to the server (phone is source of truth).
  /// Pull/replace only happens via [PatientSync.restoreFromServer] on new devices.
  Future<void> syncPatientHistory() async {
    if (user == null) return;
    await _syncWithServer(user!.id, user!.email);
  }

  /// Backs up the phone snapshot to the email-keyed server history.
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
