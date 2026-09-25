import 'pha_purchases.dart';

/// Back-compat alias used from app bootstrap.
class PurchasesConfig {
  static String get iosApiKey => PhaPurchases.iosApiKey;

  static Future<void> configure({String? appUserId}) =>
      PhaPurchases.configure(appUserId: appUserId);
}
