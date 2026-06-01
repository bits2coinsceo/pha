import 'db.dart';

/// Age, height, and weight stored on the user profile (survives app restarts).
class ProfileBasicsService {
  static Future<void> save({
    required String userId,
    String? unitSystem,
    int? age,
    int? heightCm,
    double? weightKg,
  }) async {
    if (age == null && heightCm == null && weightKg == null && unitSystem == null) return;
    await Db.instance.raw.update(
      'profiles',
      {
        if (unitSystem != null) 'unit_system': unitSystem,
        if (age != null) 'age': age,
        if (heightCm != null) 'height': heightCm,
        if (weightKg != null) 'weight': weightKg,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Copies weight from the latest metric row if the profile column is empty.
  static Future<void> backfillWeightFromMetrics(String userId) async {
    final db = Db.instance.raw;
    final profile = await db.query(
      'profiles',
      columns: ['weight'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (profile.isEmpty || profile.first['weight'] != null) return;

    final wRows = await db.query(
      'health_metrics',
      columns: ['value'],
      where: 'user_id = ? AND metric_type = ?',
      whereArgs: [userId, 'weight'],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    if (wRows.isEmpty) return;

    await db.update(
      'profiles',
      {'weight': (wRows.first['value'] as num).toDouble()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
