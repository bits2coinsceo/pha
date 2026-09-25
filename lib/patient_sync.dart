import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'api.dart';
import 'db.dart';

/// Exports local health history and syncs it with the server (keyed by email).
///
/// Phone SQLite is the working copy (including uploaded files). The server keeps
/// an email-keyed encrypted snapshot for restore: vitals, activity, Ai Doc chats,
/// and Health Insights (`health_analysis`) deviations — not file binaries.
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

  /// Tables that may store on-device paths; binaries stay on the phone.
  static const _localFilePathTables = {
    'analysis_uploads',
    'meal_calorie_checks',
  };

  /// Pulls server history and replaces local rows when the server copy is newer.
  /// Used for account restore / new-device sign-in — not routine resume backup.
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
      return applyRemoteSnapshot(
        email: email,
        syncToken: syncToken,
        remote: remote,
      );
    } on ApiException {
      rethrow;
    }
  }

  /// Creates/replaces the local profile and history from a server snapshot.
  static Future<String> applyRemoteSnapshot({
    required String email,
    required String syncToken,
    required Map<String, dynamic> remote,
  }) async {
    final userId = remote['user_id'] as String;
    await _createProfile(email, syncToken, remote);
    await _import(remote, userId);
    return userId;
  }

  /// Uploads the full local history for this patient (phone → server backup).
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
    // Keep local freshness aligned so a later pull cannot overwrite newer phone data.
    await Db.instance.raw.update(
      'profiles',
      {'updated_at': payload['updated_at']},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Convenience for write-sites that only know [userId].
  static Future<void> pushForUser(String userId) async {
    final rows = await Db.instance.raw.query(
      'profiles',
      columns: ['email', 'password_hash'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final email = rows.first['email'] as String?;
    final token = rows.first['password_hash'] as String?;
    if (email == null || email.isEmpty || token == null || token.isEmpty) return;
    await push(email: email, syncToken: token, userId: userId);
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

    final updatedAt = DateTime.now().toUtc().toIso8601String();
    profile['updated_at'] = updatedAt;

    final tables = <String, List<Map<String, dynamic>>>{};
    for (final table in _tables) {
      final rows = await db.query(
        table,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      tables[table] = rows.map((r) {
        final row = Map<String, dynamic>.from(r);
        if (_localFilePathTables.contains(table) && row.containsKey('file_path')) {
          // Keep display name only — original files remain on-device.
          row['file_path'] = _fileNameOnly(row['file_path'] as String?);
        }
        return row;
      }).toList();
    }

    return {
      'version': 1,
      'user_id': userId,
      'email': email.trim().toLowerCase(),
      'updated_at': updatedAt,
      'profile': profile,
      for (final entry in tables.entries) entry.key: entry.value,
    };
  }

  static String _fileNameOnly(String? path) {
    if (path == null || path.isEmpty) return '';
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? '' : parts.last;
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
