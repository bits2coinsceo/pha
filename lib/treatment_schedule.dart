import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';

const _uuid = Uuid();

class TreatmentScheduleItem {
  final String id;
  final String userId;
  final String name;
  final int dosesPerDay;
  final List<TimeOfDay> doseTimes;
  final DateTime createdAt;

  const TreatmentScheduleItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosesPerDay,
    required this.doseTimes,
    required this.createdAt,
  });

  factory TreatmentScheduleItem.fromRow(Map<String, dynamic> row) {
    final raw = row['dose_times'] as String? ?? '[]';
    final decoded = (jsonDecode(raw) as List).cast<String>();
    return TreatmentScheduleItem(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: row['name'] as String,
      dosesPerDay: row['doses_per_day'] as int,
      doseTimes: decoded.map(_parseTime).toList(),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String formatDoseTime(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

List<String> _encodeTimes(List<TimeOfDay> times) =>
    times.map(formatDoseTime).toList();

class TreatmentScheduleService {
  static Future<List<TreatmentScheduleItem>> list(String userId) async {
    final rows = await Db.instance.raw.query(
      'treatment_schedule',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(TreatmentScheduleItem.fromRow).toList();
  }

  static Future<void> save({
    required String userId,
    required String name,
    required int dosesPerDay,
    required List<TimeOfDay> doseTimes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await Db.instance.raw.insert('treatment_schedule', {
      'id': _uuid.v4(),
      'user_id': userId,
      'name': name.trim(),
      'doses_per_day': dosesPerDay,
      'dose_times': jsonEncode(_encodeTimes(doseTimes.take(dosesPerDay).toList())),
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<void> delete(String id) async {
    await Db.instance.raw.delete('treatment_schedule', where: 'id = ?', whereArgs: [id]);
  }
}
