import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Sync token and device id live in the Keychain, not in SQLite.
class SessionSecret {
  SessionSecret._();

  static const _storage = FlutterSecureStorage();
  static const _deviceKey = 'pha_device_id';

  static Future<void> saveToken({
    required String email,
    required String token,
  }) async {
    final key = email.trim().toLowerCase();
    await _storage.write(key: 'pha_token_$key', value: token);
    await _storage.write(key: 'pha_session_email', value: key);
  }

  static Future<({String email, String token})?> current() async {
    final email = await _storage.read(key: 'pha_session_email');
    if (email == null || email.isEmpty) return null;
    final token = await _storage.read(key: 'pha_token_$email');
    if (token == null || token.isEmpty) return null;
    return (email: email, token: token);
  }

  /// Stable id for this install. Keychain keeps it across reinstalls on iOS.
  static Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceKey);
    if (existing != null && existing.length >= 16) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: _deviceKey, value: id);
    return id;
  }

  static Future<void> savePasswordCheck(String email, String password) async {
    final key = email.trim().toLowerCase();
    final salt = const Uuid().v4();
    final digest = sha256.convert(utf8.encode('$salt::$password')).toString();
    await _storage.write(key: 'pha_pw_salt_$key', value: salt);
    await _storage.write(key: 'pha_pw_$key', value: digest);
  }

  static Future<bool> passwordMatches(String email, String password) async {
    final key = email.trim().toLowerCase();
    final salt = await _storage.read(key: 'pha_pw_salt_$key');
    final stored = await _storage.read(key: 'pha_pw_$key');
    if (salt == null || stored == null) return false;
    final digest = sha256.convert(utf8.encode('$salt::$password')).toString();
    return digest == stored;
  }
}
