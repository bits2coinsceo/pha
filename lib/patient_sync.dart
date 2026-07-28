import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'api.dart';
import 'db.dart';

/// Exports local health history and syncs it with the server (keyed by email).
class PatientSync {
  static const _tables = [
    'health_metrics',
    'health_index',
    'ai_consultations',
    'analysis_uploads',
    'stress_tests',
    'psychotest_results',
    'health_connect_syncs',
    'health_analysis',
    'treatment_schedule',
    'meal_calorie_checks',
    'bad_habit_checks',
    'physical_activity_programs',
    'physical_activity_checkins',
  ];

  /// Pulls server history and merges if the server copy is newer.
  static Future<void> pullAndMerge({
    required String email,
    required String syncToken,
    required String userId,
  }) async {
    final remote = await ApiClient.getPatientHistory(
      email: email,
      syncToken: syncToken,
    );
    if (remote == null) return;

    final remoteUpdated = DateTime.tryParse(remote['updated_at'] as String? ?? '');
    final localUpdated = await _localUpdatedAt(userId);
    if (remoteUpdated != null &&
        localUpdated != null &&
        !remoteUpdated.isAfter(localUpdated)) {
      return;
    }
    await _import(remote, userId);
  }

  /// Restores a full account from the server onto a new device.
  static Future<String?> restoreFromServer({
    required String email,
    required String syncToken,
  }) async {
    try {
      final remote = await ApiClient.getPatientHistory(
        email: email,
        syncToken: syncToken,
      );
      if (remote == null) return null;

      final userId = remote['user_id'] as String;
      await _createProfile(email, syncToken, remote);
      await _import(remote, userId);
      return userId;
    } on ApiException {
      return null;
    }
  }

  /// Uploads the full local history for this patient.
  static Future<void> push({
    required String email,
    required String syncToken,
    required String userId,
  }) async {
    final payload = await _export(userId, email);
    await ApiClient.putPatientHistory(
      email: email,
      syncToken: syncToken,
      payload: payload,
    );
  }

  static Future<bool> existsOnServer(String email) async {
    try {
      return await ApiClient.patientExists(email);
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> _export(String userId, String email) async {
    final db = Db.instance.raw;
    final profiles =
        await db.query('profiles', where: 'id = ?', whereArgs: [userId]);
    if (profiles.isEmpty) throw Exception('Profile not found');
    final profile = Map<String, dynamic>.from(profiles.first);
    profile.remove('password_hash');

    final tables = <String, List<Map<String, dynamic>>>{};
    for (final table in _tables) {
      final rows = await db.query(
        table,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      tables[table] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    }

    return {
      'version': 1,
      'user_id': userId,
      'email': email.trim().toLowerCase(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'profile': profile,
      for (final entry in tables.entries) entry.key: entry.value,
    };
  }

  static Future<void> _createProfile(
    String email,
    String syncToken,
    Map<String, dynamic> remote,
  ) async {
    final db = Db.instance.raw;
    final profile = Map<String, dynamic>.from(remote['profile'] as Map);
    final userId = remote['user_id'] as String;
    profile['id'] = userId;
    profile['email'] = email.trim().toLowerCase();
    profile['password_hash'] = syncToken;

    await db.insert(
      'profiles',
      profile,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _import(Map<String, dynamic> remote, String userId) async {
    final db = Db.instance.raw;
    final profile = Map<String, dynamic>.from(remote['profile'] as Map);
    profile['id'] = userId;
    profile.remove('password_hash');

    await db.update('profiles', profile, where: 'id = ?', whereArgs: [userId]);

    for (final table in _tables) {
      await db.delete(table, where: 'user_id = ?', whereArgs: [userId]);
      final rows = remote[table] as List<dynamic>? ?? [];
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw as Map);
        row['user_id'] = userId;
        await db.insert(
          table,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  static Future<DateTime?> _localUpdatedAt(String userId) async {
    final rows = await Db.instance.raw.query(
      'profiles',
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['updated_at'] as String? ?? '');
  }
}
