import 'package:uuid/uuid.dart';

import 'api.dart';
import 'db.dart';
import 'health_index.dart';
import 'image_compress.dart';
import 'medical_guidelines.dart';
import 'services.dart';

const _uuid = Uuid();

enum MealCalorieCategory {
  excellent,
  satisfactory,
  attention,
}

class MealCalorieResult {
  final String analysis;
  final String mealName;
  final String portion;
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final MealCalorieCategory category;
  final String categoryLabel;

  const MealCalorieResult({
    required this.analysis,
    required this.mealName,
    required this.portion,
    required this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.category,
    required this.categoryLabel,
  });
}

/// One confirmed meal the patient logged as eaten.
class MealLogEntry {
  final String id;
  final String mealName;
  final String portion;
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String category;
  final String categoryLabel;
  final String? filePath;
  final DateTime checkedAt;

  const MealLogEntry({
    required this.id,
    required this.mealName,
    required this.portion,
    required this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.category,
    required this.categoryLabel,
    this.filePath,
    required this.checkedAt,
  });

  factory MealLogEntry.fromRow(Map<String, dynamic> row) {
    return MealLogEntry(
      id: row['id'] as String,
      mealName: (row['meal_name'] as String?)?.trim().isNotEmpty == true
          ? row['meal_name'] as String
          : _fallbackName(row['analysis'] as String? ?? ''),
      portion: (row['portion'] as String?)?.trim().isNotEmpty == true
          ? row['portion'] as String
          : 'one serving',
      calories: (row['calories'] as num?)?.toInt(),
      proteinG: (row['protein_g'] as num?)?.toDouble(),
      carbsG: (row['carbs_g'] as num?)?.toDouble(),
      fatG: (row['fat_g'] as num?)?.toDouble(),
      category: row['category'] as String? ?? 'satisfactory',
      categoryLabel: row['category_label'] as String? ?? 'Satisfactory',
      filePath: row['file_path'] as String?,
      checkedAt: DateTime.parse(row['checked_at'] as String).toLocal(),
    );
  }

  static String _fallbackName(String analysis) {
    final m = RegExp(
      r'\*\*Meal:\*\*\s*(.+)',
      caseSensitive: false,
    ).firstMatch(analysis);
    if (m != null) {
      final line = m.group(1)!.split('\n').first.trim();
      if (line.isNotEmpty) return line;
    }
    return 'Meal';
  }
}

class DailyMealSummary {
  final List<MealLogEntry> meals;
  final int totalCalories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int targetCalories;
  final String qualityLabel;
  final String qualityHint;

  const DailyMealSummary({
    required this.meals,
    required this.totalCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.targetCalories,
    required this.qualityLabel,
    required this.qualityHint,
  });

  /// Positive = under target (deficit), negative = over (surplus).
  int get calorieBalance => targetCalories - totalCalories;

  bool get hasMeals => meals.isNotEmpty;
}

class MealCalorieService {
  static const freeDailyLimit = 2;

  static Future<int> countLast24Hours(String userId) async {
    if (!Db.instance.isReady) return 0;
    final since =
        DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
    final rows = await Db.instance.raw.rawQuery(
      'SELECT COUNT(*) c FROM meal_calorie_checks '
      'WHERE user_id = ? AND checked_at >= ? AND confirmed = 1',
      [userId, since],
    );
    return (rows.first['c'] as num).toInt();
  }

  static Future<MealCalorieResult> analyzePhoto({
    required String userId,
    required String filePath,
  }) async {
    final patientContext =
        await AiConsultationService.buildFullPatientContext(userId);
    final prompt = _mealAnalysisPrompt(patientContext);
    final uploadPath = await compressImageForUpload(
      filePath,
      quality: 60,
      maxWidth: 800,
      maxHeight: 800,
    );
    final analysis = await ApiClient.analyze(
      userId: userId,
      filePath: uploadPath,
      textLogs: prompt,
      complexity: 'complex',
    );
    return _parseAnalysis(analysis);
  }

  /// Confirms the patient ate this meal — persists for daily totals & index.
  static Future<void> confirmEaten({
    required String userId,
    required String filePath,
    required MealCalorieResult result,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await Db.instance.raw.insert('meal_calorie_checks', {
      'id': _uuid.v4(),
      'user_id': userId,
      'file_path': filePath,
      'analysis': result.analysis,
      'calories': result.calories,
      'category': result.category.name,
      'category_label': result.categoryLabel,
      'meal_name': result.mealName,
      'portion': result.portion,
      'protein_g': result.proteinG,
      'carbs_g': result.carbsG,
      'fat_g': result.fatG,
      'confirmed': 1,
      'checked_at': now,
      'created_at': now,
    });
    await HealthIndexService.recalculate(userId);
  }

  /// @deprecated use [confirmEaten]
  static Future<void> save({
    required String userId,
    required String filePath,
    required MealCalorieResult result,
  }) =>
      confirmEaten(userId: userId, filePath: filePath, result: result);

  static Future<List<MealLogEntry>> mealsForDay(
    String userId,
    DateTime day,
  ) async {
    if (!Db.instance.isReady) return [];
    final localStart = DateTime(day.year, day.month, day.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final rows = await Db.instance.raw.query(
      'meal_calorie_checks',
      where: 'user_id = ? AND confirmed = 1',
      whereArgs: [userId],
      orderBy: 'checked_at ASC',
    );
    return rows
        .map(MealLogEntry.fromRow)
        .where((m) =>
            !m.checkedAt.isBefore(localStart) && m.checkedAt.isBefore(localEnd))
        .toList();
  }

  static Future<DailyMealSummary> summaryForDay(
    String userId,
    DateTime day,
  ) async {
    final meals = await mealsForDay(userId, day);
    var total = 0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    for (final m in meals) {
      total += m.calories ?? 0;
      protein += m.proteinG ?? 0;
      carbs += m.carbsG ?? 0;
      fat += m.fatG ?? 0;
    }
    final target = await estimatedDailyTarget(userId);
    final quality = _dayQuality(meals, total, target);
    return DailyMealSummary(
      meals: meals,
      totalCalories: total,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      targetCalories: target,
      qualityLabel: quality.$1,
      qualityHint: quality.$2,
    );
  }

  static Future<int> estimatedDailyTarget(String userId) async {
    if (!Db.instance.isReady) return 2000;
    final rows = await Db.instance.raw.query(
      'profiles',
      columns: ['age', 'weight', 'height', 'gender'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return 2000;
    return MedicalGuidelines.estimatedDailyCalorieTarget(
      age: (rows.first['age'] as num?)?.toInt(),
      weightKg: (rows.first['weight'] as num?)?.toDouble(),
      heightCm: (rows.first['height'] as num?)?.toDouble(),
      gender: rows.first['gender'] as String?,
    );
  }

  static (String, String) _dayQuality(
    List<MealLogEntry> meals,
    int total,
    int target,
  ) {
    if (meals.isEmpty) {
      return ('No meals logged', 'Confirm meals after analysis to track intake.');
    }
    final attention = meals.where((m) => m.category == 'attention').length;
    final excellent = meals.where((m) => m.category == 'excellent').length;
    final balance = target - total;
    if (attention >= 2 || total > target + 400) {
      return (
        'Heavy day',
        balance < 0
            ? 'About ${-balance} kcal over your ~$target kcal target.'
            : 'Several high-calorie choices today — ease up next meals.',
      );
    }
    if (excellent >= meals.length ~/ 2 && balance >= 0) {
      return (
        'Good choices',
        balance > 120
            ? 'Solid day — ~$balance kcal under your ~$target kcal target.'
            : 'On track with your ~$target kcal target.',
      );
    }
    if (balance < -200) {
      return (
        'Over target',
        'About ${-balance} kcal over ~$target kcal — prefer lighter options next.',
      );
    }
    if (balance > 400 && meals.length <= 2) {
      return (
        'Under target',
        '~$balance kcal under goal — make sure meals are logged if you ate more.',
      );
    }
    return (
      'Balanced',
      'Intake ~$total kcal vs ~$target kcal target today.',
    );
  }

  static String _mealAnalysisPrompt(String patientContext) {
    return '''
You are a nutrition assistant in the PHA health app. Analyze the meal in this photo for ONE realistic serving/portion on the plate.

Patient health profile and history:
$patientContext

Calorie-Based Dish Categorization (per serving):
1. Excellent — ≤${MedicalGuidelines.mealExcellentMaxKcal} kcal — Low-calorie. Great for weight loss and daily meals.
2. Satisfactory — ${MedicalGuidelines.mealExcellentMaxKcal + 1}–${MedicalGuidelines.mealSatisfactoryMaxKcal} kcal — Moderate. Acceptable in balanced amounts.
3. Attention — >${MedicalGuidelines.mealSatisfactoryMaxKcal} kcal — High-calorie. Use sparingly; not for regular consumption if watching weight.

Keep the response short and exact (under 160 words). No greetings or filler.
Do not use emoji in the response.

Respond using EXACTLY this structure (one line each):
**Name:** [short dish title, e.g. Chicken with Baked Potato and Broccoli]
**Portion:** [e.g. one plate | 1 serving]
**Calories:** [number] kcal
**Protein:** [number] g
**Carbs:** [number] g
**Fat:** [number] g
**Category:** [Excellent | Satisfactory | Attention]
**For you:** [1–2 short sentences — is this a good choice for THIS patient]
''';
  }

  static MealCalorieResult _parseAnalysis(String analysis) {
    final calories = _extractCalories(analysis);
    final category = _extractCategory(analysis, calories);
    final label = switch (category) {
      MealCalorieCategory.excellent => 'Excellent',
      MealCalorieCategory.satisfactory => 'Satisfactory',
      MealCalorieCategory.attention => 'Attention',
    };
    return MealCalorieResult(
      analysis: analysis,
      mealName: _extractField(analysis, 'Name') ??
          _extractField(analysis, 'Meal') ??
          'Meal',
      portion: _extractField(analysis, 'Portion') ?? 'one serving',
      calories: calories,
      proteinG: _extractGrams(analysis, 'Protein'),
      carbsG: _extractGrams(analysis, 'Carbs') ??
          _extractGrams(analysis, 'Carbohydrates'),
      fatG: _extractGrams(analysis, 'Fat'),
      category: category,
      categoryLabel: label,
    );
  }

  static String? _extractField(String text, String label) {
    final m = RegExp(
      '\\*\\*$label:\\*\\*\\s*(.+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;
    final line = m.group(1)!.split('\n').first.trim();
    return line.isEmpty ? null : line.replaceAll(RegExp(r'^~'), '').trim();
  }

  static int? _extractCalories(String text) {
    final fromField = _extractField(text, 'Calories');
    if (fromField != null) {
      final n = RegExp(r'(\d{2,4})').firstMatch(fromField);
      if (n != null) return int.tryParse(n.group(1)!);
    }
    final match =
        RegExp(r'(\d{2,4})\s*kcal', caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static double? _extractGrams(String text, String label) {
    final field = _extractField(text, label);
    if (field == null) return null;
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(field);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }

  static MealCalorieCategory _extractCategory(String text, int? calories) {
    final field = _extractField(text, 'Category')?.toLowerCase() ?? '';
    final lower = field.isNotEmpty ? field : text.toLowerCase();
    if (lower.contains('excellent')) return MealCalorieCategory.excellent;
    if (lower.contains('attention')) return MealCalorieCategory.attention;
    if (lower.contains('satisfactory')) return MealCalorieCategory.satisfactory;
    if (calories != null) {
      if (calories <= MedicalGuidelines.mealExcellentMaxKcal) {
        return MealCalorieCategory.excellent;
      }
      if (calories <= MedicalGuidelines.mealSatisfactoryMaxKcal) {
        return MealCalorieCategory.satisfactory;
      }
      return MealCalorieCategory.attention;
    }
    return MealCalorieCategory.satisfactory;
  }
}
