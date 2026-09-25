import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'core/app_logger.dart';

/// Typed purchase / billing failures with a stable [code] for UI copy.
class PhaPurchaseException implements Exception {
  final String code;
  final String message;
  PhaPurchaseException(this.code, this.message);

  static const invalidCredentials = 'invalid_credentials';
  static const network = 'network';
  static const storeProblem = 'store_problem';
  static const noOfferings = 'no_offerings';
  static const noPackage = 'no_package';
  static const unknown = 'unknown';

  @override
  String toString() => message;
}

/// RevenueCat billing for PHA Plus+.
///
/// Unlocking Plus must only happen after a successful store purchase (or an
/// already-active entitlement). Never call [AuthProvider.upgradeToPlus] from
/// the UI without going through this layer.
class PhaPurchases {
  PhaPurchases._();

  /// Fallback Apple public SDK key (Project Settings → API keys in RevenueCat).
  /// Prefer [REVENUECAT_IOS_API_KEY] via `--dart-define-from-file=dart_define.json`.
  static const _iosApiKeyFallback = 'appl_dirSNqLAhennaNLalCvquluuJUd';
  static const _iosApiKeyEnv =
      String.fromEnvironment('REVENUECAT_IOS_API_KEY', defaultValue: '');

  /// Preferred entitlement id in the RevenueCat dashboard.
  /// Also accepts `plus` / `pha plus` as fallbacks.
  static const primaryEntitlementId = 'pha_plus';

  /// App Store Connect product IDs (must match ASC + RevenueCat exactly).
  static const productIdMonthly = 'com.pha.monthly';
  static const productIdSixMonths = 'com.pha.6months';
  static const productIdAnnual = 'com.pha.annual';

  /// Maps in-app plan keys → App Store Connect product identifiers.
  static const Map<String, String> planProductIds = {
    'monthly': productIdMonthly,
    'semiannual': productIdSixMonths,
    'annual': productIdAnnual,
  };

  static String _iosApiKey = _iosApiKeyEnv;
  static bool _keyLoaded = false;
  static bool _configured = false;
  static Future<void>? _configureInFlight;

  /// Back-compat for [PurchasesConfig.iosApiKey].
  static String get iosApiKey =>
      _iosApiKey.isNotEmpty ? _iosApiKey : _iosApiKeyFallback;

  /// Load SDK key from bundled dart_define.json when compile-time define is empty.
  static Future<void> ensureKeyLoaded() async {
    if (_keyLoaded) return;
    _keyLoaded = true;
    if (_iosApiKey.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString('dart_define.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final key = (json['REVENUECAT_IOS_API_KEY'] as String?)?.trim() ?? '';
      if (key.isNotEmpty) _iosApiKey = key;
    } catch (_) {
      // Asset absent — use fallback constant.
    }
  }

  static Future<void> configure({String? appUserId}) async {
    if (kIsWeb) return;
    // purchases_flutter officially supports iOS / Android; macOS is best-effort.
    if (!(Platform.isIOS || Platform.isMacOS)) return;

    await ensureKeyLoaded();

    // Single-flight: never start a second configure while one is running
    // (startup timeout used to leave the SDK half-initialized).
    final existing = _configureInFlight;
    if (existing != null) {
      await existing;
      if (appUserId != null && appUserId.isNotEmpty) {
        await _logInQuietly(appUserId);
      }
      return;
    }

    _configureInFlight = _configureBody(appUserId);
    try {
      await _configureInFlight;
    } finally {
      _configureInFlight = null;
    }
  }

  static Future<void> _configureBody(String? appUserId) async {
    final already = await Purchases.isConfigured;
    if (already || _configured) {
      _configured = true;
      if (appUserId != null && appUserId.isNotEmpty) {
        await _logInQuietly(appUserId);
      }
      return;
    }

    final key = iosApiKey.trim();
    if (key.isEmpty || !key.startsWith('appl_')) {
      throw PhaPurchaseException(
        PhaPurchaseException.invalidCredentials,
        'RevenueCat iOS API key is missing or invalid (must start with appl_).',
      );
    }

    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    }

    final config = PurchasesConfiguration(key);
    if (appUserId != null && appUserId.isNotEmpty) {
      config.appUserID = appUserId;
    }
    await Purchases.configure(config);
    _configured = true;
    AppLogger.i(
      'RevenueCat configured (key …${key.substring(key.length - 6)})',
      category: LogCategory.bootstrap,
    );
  }

  static Future<void> _logInQuietly(String appUserId) async {
    try {
      await Purchases.logIn(appUserId);
    } catch (e, st) {
      AppLogger.w(
        'RevenueCat logIn failed (non-fatal)',
        error: e,
        stackTrace: st,
        category: LogCategory.bootstrap,
      );
    }
  }

  /// Purchases the package for [plan] (`monthly` | `semiannual` | `annual`).
  ///
  /// Returns `true` when Plus entitlement is active after the purchase.
  /// Returns `false` when the user cancelled the store sheet.
  /// Throws [PhaPurchaseException] on other failures.
  static Future<bool> purchasePlan(String plan) async {
    await configure();
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      if (offering == null || offering.availablePackages.isEmpty) {
        throw PhaPurchaseException(
          PhaPurchaseException.noOfferings,
          'No RevenueCat offerings available. Check products in App Store Connect and RevenueCat.',
        );
      }

      final package = _packageForPlan(offering, plan);
      if (package == null) {
        final expectedId = planProductIds[plan] ?? plan;
        throw PhaPurchaseException(
          PhaPurchaseException.noPackage,
          'No store package for plan "$plan" (expected product $expectedId). '
          'Available: ${offering.availablePackages.map((p) => p.storeProduct.identifier).join(", ")}',
        );
      }

      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _hasPlus(result.customerInfo);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      AppLogger.w(
        'RevenueCat purchase failed: $code',
        error: e,
        category: LogCategory.bootstrap,
      );
      // Allow a clean re-configure on the next attempt if credentials were bad.
      if (code == PurchasesErrorCode.invalidCredentialsError) {
        _configured = false;
      }
      throw _mapPlatformException(e, code);
    } on PhaPurchaseException {
      rethrow;
    } catch (e) {
      throw PhaPurchaseException(
        PhaPurchaseException.unknown,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  static PhaPurchaseException _mapPlatformException(
    PlatformException e,
    PurchasesErrorCode code,
  ) {
    switch (code) {
      case PurchasesErrorCode.invalidCredentialsError:
        return PhaPurchaseException(
          PhaPurchaseException.invalidCredentials,
          'Billing credentials are invalid. Check the RevenueCat Apple public '
          'SDK key (appl_…) and App Store Connect credentials in the '
          'RevenueCat project.',
        );
      case PurchasesErrorCode.networkError:
        return PhaPurchaseException(
          PhaPurchaseException.network,
          'Network error while contacting the App Store. Try again.',
        );
      case PurchasesErrorCode.storeProblemError:
      case PurchasesErrorCode.purchaseNotAllowedError:
        return PhaPurchaseException(
          PhaPurchaseException.storeProblem,
          'The App Store could not complete the purchase. Try again later.',
        );
      default:
        final details = e.message ?? e.details?.toString() ?? e.code;
        return PhaPurchaseException(
          PhaPurchaseException.unknown,
          details,
        );
    }
  }

  /// True when the customer already has an active Plus entitlement.
  static Future<bool> hasActivePlus() async {
    try {
      await configure();
      final info = await Purchases.getCustomerInfo();
      return _hasPlus(info);
    } catch (_) {
      return false;
    }
  }

  static Package? _packageForPlan(Offering offering, String plan) {
    final productId = planProductIds[plan];
    if (productId != null) {
      for (final package in offering.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          return package;
        }
      }
    }

    // Fallbacks if packages are typed in RevenueCat but product id lookup missed.
    switch (plan) {
      case 'monthly':
        return offering.monthly ??
            offering.getPackage(r'$rc_monthly') ??
            offering.getPackage('monthly');
      case 'semiannual':
        return offering.sixMonth ??
            offering.getPackage(r'$rc_six_month') ??
            offering.getPackage('semiannual') ??
            offering.getPackage('six_month') ??
            offering.getPackage('6months');
      case 'annual':
        return offering.annual ??
            offering.getPackage(r'$rc_annual') ??
            offering.getPackage('annual');
      default:
        return offering.getPackage(plan);
    }
  }

  static bool _hasPlus(CustomerInfo info) {
    final active = info.entitlements.active;
    if (active.isEmpty) return false;
    if (active.containsKey(primaryEntitlementId)) return true;
    if (active.containsKey('plus')) return true;
    if (active.containsKey('pha plus')) return true;
    // If only one entitlement exists and it's active, treat as Plus.
    return active.length == 1;
  }
}
