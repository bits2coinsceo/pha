import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Local SQLite database — replaces Supabase Postgres for the Flutter port.
/// Stores all health data on-device.
class Db {
  Db._();
  static final Db instance = Db._();

  Database? _db;
  Database get raw => _db!;

  Future<void> init() async {
    if (_db != null) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'pha.db');
    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 4, onCreate: _create, onUpgrade: _upgrade),
    );
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
  }

  Future<void> _createOnboardingDrafts(Database db) async {
    await db.execute('''
      CREATE TABLE onboarding_drafts (
        id TEXT PRIMARY KEY,
        unit_system TEXT NOT NULL DEFAULT 'metric',
        age INTEGER,
        height INTEGER,
        weight REAL,
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
    await _createOnboardingDrafts(db);
  }
}
