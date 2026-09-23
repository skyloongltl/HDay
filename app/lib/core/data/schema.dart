import 'package:sqflite/sqflite.dart';

import '../domain/app_failure.dart';

abstract final class Schema {
  static const version = 1;
  static const databaseName = 'fitness_counter_v2.db';

  static Future<void> create(Database db, int version) async {
    if (version != Schema.version) {
      throw const AppFailure(
        FailureCode.persistence,
        detail: 'Unsupported schema version.',
      );
    }
    for (final statement in _statements) {
      await db.execute(statement);
    }
  }

  /// Future migrations are registered by their destination version. There is
  /// deliberately no legacy database import or destructive fallback.
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    const migrations = <int, Future<void> Function(Database)>{};
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      final migrate = migrations[version];
      if (migrate == null) {
        throw const AppFailure(
          FailureCode.persistence,
          detail: 'Unsupported database upgrade.',
        );
      }
      await migrate(db);
    }
  }

  static Future<void> downgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    throw const AppFailure(
      FailureCode.persistence,
      detail: 'Database downgrade is not supported.',
    );
  }

  static const _statements = [
    '''CREATE TABLE exercises (
      id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE BINARY,
      category TEXT NOT NULL, equipment TEXT NOT NULL, default_unit TEXT NOT NULL,
      note TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
    )''',
    'CREATE INDEX exercise_filters ON exercises(category, equipment)',
    '''CREATE TABLE plans (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, enabled INTEGER NOT NULL,
      priority INTEGER NOT NULL, default_order INTEGER NOT NULL,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
    )''',
    '''CREATE TABLE plan_revisions (
      id TEXT PRIMARY KEY, plan_id TEXT NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
      effective_from TEXT NOT NULL, cycle_anchor_date TEXT NOT NULL,
      cycle_days INTEGER NOT NULL CHECK(cycle_days BETWEEN 1 AND 365),
      mode TEXT NOT NULL, cycle_count INTEGER, end_date TEXT,
      UNIQUE(plan_id, effective_from)
    )''',
    '''CREATE TABLE plan_days (
      revision_id TEXT NOT NULL REFERENCES plan_revisions(id) ON DELETE CASCADE,
      id TEXT NOT NULL, day_number INTEGER NOT NULL, name TEXT NOT NULL,
      is_rest INTEGER NOT NULL, PRIMARY KEY(revision_id, id),
      UNIQUE(revision_id, day_number)
    )''',
    '''CREATE TABLE plan_exercises (
      revision_id TEXT NOT NULL, day_id TEXT NOT NULL, id TEXT NOT NULL,
      exercise_id TEXT NOT NULL, name_snapshot TEXT NOT NULL, note TEXT NOT NULL,
      target_rest_seconds INTEGER NOT NULL, sort_order INTEGER NOT NULL,
      PRIMARY KEY(revision_id, day_id, id),
      FOREIGN KEY(revision_id, day_id) REFERENCES plan_days(revision_id, id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE plan_sets (
      revision_id TEXT NOT NULL, day_id TEXT NOT NULL, exercise_id TEXT NOT NULL,
      id TEXT NOT NULL, sort_order INTEGER NOT NULL, planned_weight REAL NOT NULL,
      unit TEXT NOT NULL, planned_reps INTEGER NOT NULL,
      PRIMARY KEY(revision_id, day_id, exercise_id, id),
      FOREIGN KEY(revision_id, day_id, exercise_id)
        REFERENCES plan_exercises(revision_id, day_id, id) ON DELETE CASCADE
    )''',
    '''CREATE TABLE workout_sessions (
      id TEXT PRIMARY KEY, workout_date TEXT NOT NULL, started_at INTEGER NOT NULL,
      ended_at INTEGER, phase TEXT NOT NULL CHECK(phase IN
        ('active','resting','completedPaused','finishing','saved','timeAnomaly')),
      timer_seconds INTEGER NOT NULL, timer_started_at INTEGER,
      set_timer_seconds INTEGER NOT NULL, set_timer_started_at INTEGER,
      rest_timer_seconds INTEGER NOT NULL, rest_timer_started_at INTEGER,
      active_set_id TEXT, selected_set_id TEXT, rest_started_at INTEGER,
      rest_target_seconds INTEGER, note TEXT NOT NULL, revision INTEGER NOT NULL,
      anomaly_reason TEXT, anomaly_detected_at INTEGER, anomaly_previous_phase TEXT,
      finish_checkpoint TEXT
    )''',
    '''CREATE UNIQUE INDEX one_unfinished_workout ON workout_sessions((1))
      WHERE phase IN ('active','resting','completedPaused','finishing','timeAnomaly')''',
    'CREATE INDEX workouts_by_date ON workout_sessions(workout_date, started_at)',
    '''CREATE TABLE workout_exercises (
      session_id TEXT NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
      id TEXT NOT NULL, exercise_id TEXT NOT NULL, name_snapshot TEXT NOT NULL,
      category_snapshot TEXT NOT NULL, equipment_snapshot TEXT NOT NULL,
      unit_snapshot TEXT NOT NULL, source_plan_id TEXT, source_plan_name TEXT,
      source_revision_id TEXT, source_day_number INTEGER, source_day_name TEXT,
      note TEXT NOT NULL, target_rest_seconds INTEGER NOT NULL,
      sort_order INTEGER NOT NULL, temporary INTEGER NOT NULL,
      PRIMARY KEY(session_id, id)
    )''',
    'CREATE INDEX workout_exercise_source ON workout_exercises(exercise_id)',
    '''CREATE TABLE workout_sets (
      session_id TEXT NOT NULL, exercise_id TEXT NOT NULL, id TEXT NOT NULL,
      sort_order INTEGER NOT NULL, planned_weight REAL NOT NULL, planned_reps INTEGER NOT NULL,
      unit TEXT NOT NULL, actual_weight REAL, actual_reps INTEGER,
      status TEXT NOT NULL, started_at INTEGER, completed_at INTEGER, skipped_at INTEGER,
      set_duration_seconds INTEGER NOT NULL, pre_set_rest_seconds INTEGER NOT NULL,
      temporary INTEGER NOT NULL, PRIMARY KEY(session_id, id),
      FOREIGN KEY(session_id, exercise_id) REFERENCES workout_exercises(session_id, id) ON DELETE CASCADE
    )''',
    // References survive temporary exercise removal and never depend on sources
    // still existing. Discarding/deleting the entire session removes its ledger.
    '''CREATE TABLE workout_revision_references (
      session_id TEXT NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
      revision_id TEXT NOT NULL, PRIMARY KEY(session_id, revision_id)
    )''',
    'CREATE INDEX used_plan_revision ON workout_revision_references(revision_id)',
    '''CREATE TABLE app_settings (
      id INTEGER PRIMARY KEY CHECK(id = 1), default_unit TEXT NOT NULL,
      default_rest_seconds INTEGER NOT NULL, rest_reminder INTEGER NOT NULL,
      vibration INTEGER NOT NULL, screen_awake INTEGER NOT NULL,
      week_start TEXT NOT NULL, theme_id TEXT NOT NULL
    )''',
  ];
}
