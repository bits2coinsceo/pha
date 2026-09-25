import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'db.dart';

/// Local QA account with free-tier access only (no PHA Plus+).
///
/// Log in: [email] / [password]
///
/// Seeded only when missing. Does not bump [updated_at] on every launch so a
/// server backup for the same email can still restore on Sign In.
class TestProfile {
  TestProfile._();

  static const email = 'test@test.com';
  static const password = '123qweasd!';
  static const id = 'a1111111-1111-4111-8111-111111111111';
  static const displayName = 'Test User';

  static String _hash(String password) =>
      sha256.convert(utf8.encode('pha-salt::$password')).toString();

  /// Ensures the test account exists locally with basic (non-Plus) permissions.
  static Future<void> ensureSeeded() async {
    if (!Db.instance.isReady) return;
    final db = Db.instance.raw;
    final now = DateTime.now().toUtc().toIso8601String();
    final hash = _hash(password);

    final existing = await db.query(
      'profiles',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert('profiles', {
        'id': id,
        'email': email,
        'password_hash': hash,
        'display_name': displayName,
        'age': 30,
        'height': 175,
        'weight': 70,
        'gender': 'male',
        'onboarding_completed': 1,
        'is_plus': 0,
        'unit_system': 'metric',
        'subscription_plan': null,
        'subscription_expires_at': null,
        'health_points': 0,
        'hp_discount_used': 0,
        'promo_codes_used': '[]',
        'created_at': now,
        'updated_at': now,
      });
      return;
    }

    // Keep credentials and free-tier flags stable — do not touch updated_at
    // (Sign In prefers a newer server snapshot for cross-device restore).
    await db.update(
      'profiles',
      {
        'password_hash': hash,
        'is_plus': 0,
        'subscription_plan': null,
        'subscription_expires_at': null,
      },
      where: 'email = ?',
      whereArgs: [email],
    );
  }
}
