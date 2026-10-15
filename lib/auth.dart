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
import 'session_secret.dart';
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

/// Full Plus+ access for this long after first app install.
const freeTrialDuration = Duration(hours: 24);

/// Kept for call sites that still speak in whole days (≈1 during the 24h trial).
const freeTrialDays = 1;

const _installTrialStartedKey = 'pha_install_trial_started_at';

/// Local replacement for Supabase Auth + the AuthContext from the web app.
class AuthProvider extends ChangeNotifier {
  AppUser? user;
  bool loading = true;
  bool isPlus = false;
  DateTime? accountCreatedAt;
  DateTime? subscriptionExpiresAt;
  /// First launch / install timestamp that starts the 24h full-access trial.
  DateTime? installTrialStartedAt;
  String unitSystem = 'metric'; // 'metric' | 'imperial'
  int healthPoints = 0;
  bool hpDiscountUsed = false;
  List<String> _promoCodesUsed = const [];

  bool get hpDiscountEligible => !hpDiscountUsed;

  /// UTC end of the 24h install trial, or null when Plus / unknown start.
  DateTime? get trialEndsAt {
    if (isPlus) return null;
    final start = installTrialStartedAt ?? accountCreatedAt?.toUtc();
    if (start == null) return null;
    return start.toUtc().add(freeTrialDuration);
  }

  /// True while the 24h install trial is still running (and user is not Plus+).
  bool get isTrialActive {
    final end = trialEndsAt;
    if (end == null) return false;
    return DateTime.now().toUtc().isBefore(end);
  }

  /// True when the 24h free trial has ended and the user is not on Plus+.
  bool get isTrialExpired {
    final end = trialEndsAt;
    if (end == null) return false;
    return !DateTime.now().toUtc().isBefore(end);
  }

  /// Paid Plus+ **or** active 24h install trial — unlocks every feature.
  bool get hasPlusAccess => isPlus || isTrialActive;

  /// Same as [hasPlusAccess]: during the trial nothing is paywalled.
  bool get hasFreeAccess => hasPlusAccess;

  /// Remaining trial time, or null for Plus+ / unknown / already ended.
  Duration? get trialRemaining {
    final end = trialEndsAt;
    if (end == null || isTrialExpired) return null;
    final left = end.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  /// `HH:MM:SS` countdown, or null when not in an active trial.
  String? get trialCountdownLabel {
    final left = trialRemaining;
    if (left == null) return null;
    final h = left.inHours;
    final m = left.inMinutes.remainder(60);
    final s = left.inSeconds.remainder(60);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  /// Whole hours left (rounded up), or null for Plus+ / unknown.
  int? get trialDaysRemaining {
    final left = trialRemaining;
    if (left == null) return null;
    if (left.inSeconds <= 0) return 0;
    return (left.inSeconds / 3600).ceil().clamp(1, 24);
  }

  Future<void> _storeSession({
    required String userId,
    required String email,
    required String token,
    required String password,
  }) async {
    await SessionSecret.saveToken(email: email, token: token);
    await SessionSecret.savePasswordCheck(email, password);
    await Db.instance.raw.update(
      'profiles',
      {'password_hash': token},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _ensureInstallTrialStart(prefs);
      final id = prefs.getString('session_user_id');
      if (id != null && Db.instance.isReady) {
        final rows =
            await Db.instance.raw.query('profiles', where: 'id = ?', whereArgs: [id]);
        if (rows.isNotEmpty) {
          final r = rows.first;
          user = AppUser(id: r['id'] as String, email: r['email'] as String);
          final storedToken = r['password_hash'] as String?;
          if (storedToken != null && storedToken.isNotEmpty) {
            await SessionSecret.saveToken(email: user!.email, token: storedToken);
          }
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

  /// Starts the 24h full-access clock on first launch; persists across sessions.
  Future<void> _ensureInstallTrialStart(SharedPreferences prefs) async {
    final raw = prefs.getString(_installTrialStartedKey);
    if (raw != null && raw.isNotEmpty) {
      installTrialStartedAt = DateTime.tryParse(raw)?.toUtc();
      if (installTrialStartedAt != null) return;
    }
    installTrialStartedAt = DateTime.now().toUtc();
    await prefs.setString(
      _installTrialStartedKey,
      installTrialStartedAt!.toIso8601String(),
    );
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

  Future<void> signUp(
    String email,
    String password,
    String displayName, {
    required String registrationTicket,
  }) async {
    email = email.trim().toLowerCase();
    final existing = await Db.instance.raw.query(
      'profiles',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (existing.isNotEmpty) {
      throw AuthException(AuthException.emailAlreadyRegistered);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    final ({String syncToken, String userId}) session;
    try {
      session = await ApiClient.registerAccount(
        email: email,
        password: password,
        userId: id,
        registrationTicket: registrationTicket,
      );
    } on ApiException {
      throw AuthException(AuthException.serverSyncFailed);
    } catch (_) {
      throw AuthException(AuthException.networkError);
    }
    final token = session.syncToken;
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
    await SessionSecret.saveToken(email: email, token: token);
    await SessionSecret.savePasswordCheck(email, password);

    // Registration must land on the server so other devices can restore by email.
    try {
      await PatientSync.push(email: email, syncToken: token, userId: id);
    } catch (_) {
      await Db.instance.raw.delete('profiles', where: 'id = ?', whereArgs: [id]);
      throw AuthException(AuthException.serverSyncFailed);
    }

    await _setSession(id, email);
    // Combined Health sheet + fast sync immediately — do not wait for onboarding.
    await TelemetrySyncService.promptAndSyncAfterAuth(id);
    await _loadPlanStatus(id);
    unawaited(PhaPurchases.configure(appUserId: id));
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    email = email.trim().toLowerCase();

    var sawNetworkFailure = false;
    try {
      final session = await ApiClient.openSession(email: email, password: password);
      final remote = await ApiClient.getPatientHistory(
        email: email,
        syncToken: session.syncToken,
      );
      if (remote != null) {
        final userId = await PatientSync.applyRemoteSnapshot(
          email: email,
          syncToken: session.syncToken,
          remote: remote,
        );
        await _storeSession(
          userId: userId,
          email: email,
          token: session.syncToken,
          password: password,
        );
        await _setSession(userId, email);
        await TelemetrySyncService.promptAndSyncAfterAuth(userId);
        await _loadPlanStatus(userId);
        await _markPreOnboardingDoneIfProfileComplete(userId);
        unawaited(PhaPurchases.configure(appUserId: userId));
        unawaited(_syncWithServer(userId, email));
        notifyListeners();
        return;
      }
      final userId = session.userId.isNotEmpty ? session.userId : _uuid.v4();
      await _ensureLocalProfile(userId, email, session.syncToken);
      await _storeSession(
        userId: userId,
        email: email,
        token: session.syncToken,
        password: password,
      );
      await _setSession(userId, email);
      await _loadPlanStatus(userId);
      unawaited(PhaPurchases.configure(appUserId: userId));
      notifyListeners();
      return;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        throw AuthException(AuthException.invalidCredentials);
      }
      if (e.status == 429) {
        throw AuthException(AuthException.networkError);
      }
    } catch (_) {
      sawNetworkFailure = true;
    }

    if (await SessionSecret.passwordMatches(email, password)) {
      final rows = await Db.instance.raw.query(
        'profiles',
        where: 'email = ?',
        whereArgs: [email],
      );
      if (rows.isNotEmpty) {
        final id = rows.first['id'] as String;
        final token = rows.first['password_hash'] as String? ?? '';
        if (token.isNotEmpty) {
          await SessionSecret.saveToken(email: email, token: token);
        }
        await _setSession(id, email);
        await _loadPlanStatus(id);
        notifyListeners();
        return;
      }
    }

    final legacy = _hash(password);
    final rows =
        await Db.instance.raw.query('profiles', where: 'email = ?', whereArgs: [email]);
    if (rows.isNotEmpty && rows.first['password_hash'] == legacy) {
      final id = rows.first['id'] as String;
      await SessionSecret.saveToken(email: email, token: legacy);
      await _setSession(id, email);
      await TelemetrySyncService.promptAndSyncAfterAuth(id);
      unawaited(_syncWithServer(id, email));
      await _loadPlanStatus(id);
      notifyListeners();
      return;
    }

    if (sawNetworkFailure) {
      throw AuthException(AuthException.networkError);
    }
    throw AuthException(AuthException.invalidCredentials);
  }

  Future<void> _ensureLocalProfile(String userId, String email, String token) async {
    final rows = await Db.instance.raw.query(
      'profiles',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    if (rows.isEmpty) {
      await Db.instance.raw.insert('profiles', {
        'id': userId,
        'email': email,
        'password_hash': token,
        'onboarding_completed': 0,
        'is_plus': 0,
        'unit_system': 'metric',
        'created_at': now,
        'updated_at': now,
      });
      return;
    }
    await Db.instance.raw.update(
      'profiles',
      {'password_hash': token},
      where: 'email = ?',
      whereArgs: [email],
    );
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

  /// Redeems a server-side promo. Each code works once per profile and device.
  Future<void> redeemPromoCode(String raw) async {
    if (user == null) return;
    final code = raw.trim();
    if (code.isEmpty) {
      throw PromoException(PromoException.invalid);
    }
    final ({String plan, String expiresAt, String codeId}) grant;
    try {
      grant = await ApiClient.redeemPromo(
        code: code,
        deviceId: await SessionSecret.deviceId(),
      );
    } on ApiException catch (e) {
      if (e.status == 409) throw PromoException(PromoException.alreadyUsed);
      throw PromoException(PromoException.invalid);
    }
    final expires = DateTime.tryParse(grant.expiresAt);
    final used = [..._promoCodesUsed];
    if (grant.codeId.isNotEmpty && !used.contains(grant.codeId)) {
      used.add(grant.codeId);
    }
    await Db.instance.raw.update(
      'profiles',
      {
        'is_plus': 1,
        'subscription_plan': grant.plan,
        'subscription_expires_at': expires?.toUtc().toIso8601String(),
        'promo_codes_used': jsonEncode(used),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [user!.id],
    );
    isPlus = true;
    subscriptionExpiresAt = expires?.toUtc();
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
