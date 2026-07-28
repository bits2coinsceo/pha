import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'daily_metric_store.dart';

/// Local SQLite database — replaces Supabase Postgres for the Flutter port.
/// Stores all health data on-device.
class Db {
  Db._();
  static final Db instance = Db._();

  Database? _db;
  bool get isReady => _db != null;
  Database get raw {
    final db = _db;
    if (db == null) {
      throw StateError('Db.init() has not completed');
    }
    return db;
  }

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'pha.db');
    if (Platform.isIOS || Platform.isAndroid) {
      // Use native sqflite on mobile — do not override databaseFactory.
      _db = await sqflite.openDatabase(
        path,
        version: 12,
        onCreate: _create,
        onUpgrade: _upgrade,
      );
    } else {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 12, onCreate: _create, onUpgrade: _upgrade),
      );
    }
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createOnboardingDrafts(db);
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE profiles ADD COLUMN health_points INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE profiles ADD COLUMN hp_discount_used INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE onboarding_drafts ADD COLUMN health_points INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE profiles ADD COLUMN weight REAL');
    }
    if (oldVersion < 5) {
      await _createTreatmentSchedule(db);
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE profiles ADD COLUMN gender TEXT');
      await db.execute('ALTER TABLE onboarding_drafts ADD COLUMN gender TEXT');
    }
    if (oldVersion < 7) {
      await _createMealCalorieChecks(db);
    }
    if (oldVersion < 8) {
      await _createBadHabitChecks(db);
    }
    if (oldVersion < 9) {
      await _createPhysicalActivityPrograms(db);
    }
    if (oldVersion < 10) {
      await _createPhysicalActivityCheckins(db);
    }
    if (oldVersion < 11) {
      await _upgradeMealCalorieChecksV11(db);
    }
    if (oldVersion < 12) {
      await DailyMetricStore.collapseDuplicateDailyMetrics(db);
      await DailyMetricStore.collapseDuplicateHealthIndex(db);
    }
  }

  Future<void> _upgradeMealCalorieChecksV11(Database db) async {
    Future<void> add(String sql) async {
      try {
        await db.execute(sql);
      } catch (_) {
        // Column may already exist on partial upgrades.
      }
    }

    await add('ALTER TABLE meal_calorie_checks ADD COLUMN meal_name TEXT');
    await add('ALTER TABLE meal_calorie_checks ADD COLUMN portion TEXT');
    await add('ALTER TABLE meal_calorie_checks ADD COLUMN protein_g REAL');
    await add('ALTER TABLE meal_calorie_checks ADD COLUMN carbs_g REAL');
    await add('ALTER TABLE meal_calorie_checks ADD COLUMN fat_g REAL');
    await add(
      'ALTER TABLE meal_calorie_checks ADD COLUMN confirmed INTEGER NOT NULL DEFAULT 1',
    );
  }

  Future<void> _createPhysicalActivityCheckins(Database db) async {
    await db.execute('''
      CREATE TABLE physical_activity_checkins (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        program_label TEXT NOT NULL,
        status TEXT NOT NULL,
        checkin_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createPhysicalActivityPrograms(Database db) async {
    await db.execute('''
      CREATE TABLE physical_activity_programs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        program_label TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createBadHabitChecks(Database db) async {
    await db.execute('''
      CREATE TABLE bad_habit_checks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        smokes INTEGER NOT NULL,
        smoking_level TEXT,
        drinks_alcohol INTEGER NOT NULL,
        alcohol_level TEXT,
        social_media_level TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMealCalorieChecks(Database db) async {
    await db.execute('''
      CREATE TABLE meal_calorie_checks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        analysis TEXT NOT NULL,
        calories INTEGER,
        category TEXT NOT NULL,
        category_label TEXT,
        meal_name TEXT,
        portion TEXT,
        protein_g REAL,
        carbs_g REAL,
        fat_g REAL,
        confirmed INTEGER NOT NULL DEFAULT 1,
        checked_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTreatmentSchedule(Database db) async {
    await db.execute('''
      CREATE TABLE treatment_schedule (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        doses_per_day INTEGER NOT NULL,
        dose_times TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createOnboardingDrafts(Database db) async {
    await db.execute('''
      CREATE TABLE onboarding_drafts (
        id TEXT PRIMARY KEY,
        unit_system TEXT NOT NULL DEFAULT 'metric',
        age INTEGER,
        height INTEGER,
        weight REAL,
        gender TEXT,
        metrics_json TEXT,
        step INTEGER NOT NULL DEFAULT 1,
        completed INTEGER NOT NULL DEFAULT 0,
        health_points INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        display_name TEXT,
        age INTEGER,
        height REAL,
        weight REAL,
        gender TEXT,
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        is_plus INTEGER NOT NULL DEFAULT 0,
        unit_system TEXT NOT NULL DEFAULT 'metric',
        subscription_plan TEXT,
        subscription_expires_at TEXT,
        health_points INTEGER NOT NULL DEFAULT 0,
        hp_discount_used INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE health_metrics (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        metric_type TEXT NOT NULL,
        value REAL NOT NULL,
        recorded_at TEXT NOT NULL,
        notes TEXT,
        source TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE health_index (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        score INTEGER NOT NULL,
        status TEXT NOT NULL,
        calculated_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ai_consultations (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        message TEXT NOT NULL,
        response TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE analysis_uploads (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_type TEXT NOT NULL,
        analysis TEXT,
        uploaded_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stress_tests (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        score INTEGER NOT NULL,
        result TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE psychotest_results (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        block1_score INTEGER NOT NULL,
        block2_score INTEGER NOT NULL,
        block3_score INTEGER NOT NULL,
        total_score INTEGER NOT NULL,
        level TEXT NOT NULL,
        answers TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE health_connect_syncs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        synced_at TEXT NOT NULL,
        steps INTEGER NOT NULL,
        distance_meters REAL NOT NULL,
        calories_calculated REAL NOT NULL,
        raw_payload TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE health_analysis (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        overall_status TEXT NOT NULL,
        overall_score INTEGER NOT NULL,
        summary TEXT NOT NULL,
        findings TEXT NOT NULL,
        recommendations TEXT NOT NULL,
        analyzed_at TEXT NOT NULL
      )
    ''');
    await _createTreatmentSchedule(db);
    await _createOnboardingDrafts(db);
    await _createMealCalorieChecks(db);
    await _createBadHabitChecks(db);
    await _createPhysicalActivityPrograms(db);
    await _createPhysicalActivityCheckins(db);
  }
}
