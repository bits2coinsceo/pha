import 'dart:convert';

/// Lightweight data models mapped from SQLite rows.

class AppUser {
  final String id;
  final String email;
  const AppUser({required this.id, required this.email});
}

class HealthMetric {
  final String id;
  final String metricType;
  final double value;
  final DateTime recordedAt;
  final String? notes;

  HealthMetric({
    required this.id,
    required this.metricType,
    required this.value,
    required this.recordedAt,
    this.notes,
  });

  factory HealthMetric.fromRow(Map<String, dynamic> r) => HealthMetric(
        id: r['id'] as String,
        metricType: r['metric_type'] as String,
        value: (r['value'] as num).toDouble(),
        recordedAt: DateTime.parse(r['recorded_at'] as String),
        notes: r['notes'] as String?,
      );
}

class HealthIndexEntry {
  final String id;
  final int score;
  final String status;
  final DateTime calculatedAt;

  HealthIndexEntry({
    required this.id,
    required this.score,
    required this.status,
    required this.calculatedAt,
  });

  factory HealthIndexEntry.fromRow(Map<String, dynamic> r) => HealthIndexEntry(
        id: r['id'] as String,
        score: (r['score'] as num).toInt(),
        status: r['status'] as String,
        calculatedAt: DateTime.parse(r['calculated_at'] as String),
      );
}

class StressTest {
  final String id;
  final int score;
  final String result;
  final DateTime createdAt;

  StressTest({
    required this.id,
    required this.score,
    required this.result,
    required this.createdAt,
  });

  factory StressTest.fromRow(Map<String, dynamic> r) => StressTest(
        id: r['id'] as String,
        score: (r['score'] as num).toInt(),
        result: r['result'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

class Finding {
  final String category;
  final String status; // good | warning | critical | info
  final String message;
  final String? value;

  Finding({required this.category, required this.status, required this.message, this.value});

  Map<String, dynamic> toJson() =>
      {'category': category, 'status': status, 'message': message, if (value != null) 'value': value};

  factory Finding.fromJson(Map<String, dynamic> j) => Finding(
        category: j['category'] as String,
        status: j['status'] as String,
        message: j['message'] as String,
        value: j['value'] as String?,
      );
}

class Recommendation {
  final String priority; // high | medium | low
  final String text;

  Recommendation({required this.priority, required this.text});

  Map<String, dynamic> toJson() => {'priority': priority, 'text': text};

  factory Recommendation.fromJson(Map<String, dynamic> j) =>
      Recommendation(priority: j['priority'] as String, text: j['text'] as String);
}

class HealthAnalysis {
  final String id;
  final String overallStatus;
  final int overallScore;
  final String summary;
  final List<Finding> findings;
  final List<Recommendation> recommendations;
  final DateTime analyzedAt;

  HealthAnalysis({
    required this.id,
    required this.overallStatus,
    required this.overallScore,
    required this.summary,
    required this.findings,
    required this.recommendations,
    required this.analyzedAt,
  });

  factory HealthAnalysis.fromRow(Map<String, dynamic> r) => HealthAnalysis(
        id: r['id'] as String,
        overallStatus: r['overall_status'] as String,
        overallScore: (r['overall_score'] as num).toInt(),
        summary: r['summary'] as String,
        findings: (jsonDecode(r['findings'] as String) as List)
            .map((e) => Finding.fromJson(e as Map<String, dynamic>))
            .toList(),
        recommendations: (jsonDecode(r['recommendations'] as String) as List)
            .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
            .toList(),
        analyzedAt: DateTime.parse(r['analyzed_at'] as String),
      );
}

class LastSync {
  final DateTime syncedAt;
  final int steps;
  final double distanceMeters;
  final double caloriesCalculated;

  LastSync({
    required this.syncedAt,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesCalculated,
  });

  factory LastSync.fromRow(Map<String, dynamic> r) => LastSync(
        syncedAt: DateTime.parse(r['synced_at'] as String),
        steps: (r['steps'] as num).toInt(),
        distanceMeters: (r['distance_meters'] as num).toDouble(),
        caloriesCalculated: (r['calories_calculated'] as num).toDouble(),
      );
}
