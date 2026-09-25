/// Built-in promo codes that unlock PHA Plus+ without a store purchase.
class PhaPromoCodes {
  PhaPromoCodes._();

  /// Full Plus+ for testing (no expiry).
  static const fullAccessTest = 'deblockpha+1986!';

  /// Full Plus+ for 7 days — once per profile.
  static const sevenDayTest = '7daysallfeatures!';

  static const sevenDayId = '7daysallfeatures';
  static const fullAccessId = 'deblockpha_full';

  static String normalize(String raw) => raw.trim();

  static ({String id, Duration? duration, bool oncePerProfile})? match(
    String raw,
  ) {
    final code = normalize(raw);
    if (code == fullAccessTest) {
      return (id: fullAccessId, duration: null, oncePerProfile: false);
    }
    if (code == sevenDayTest) {
      return (
        id: sevenDayId,
        duration: const Duration(days: 7),
        oncePerProfile: true,
      );
    }
    return null;
  }
}
