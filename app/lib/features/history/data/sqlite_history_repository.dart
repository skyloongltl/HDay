import 'package:sqflite/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/sql_values.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/local_date.dart';
import '../../exercises/domain/exercise.dart';
import '../../plans/data/sqlite_plan_schedule.dart';
import '../../workout/data/workout_mapper.dart';
import '../../workout/domain/workout_session.dart';
import '../domain/history_models.dart';
import '../domain/history_repository.dart';

final class SqliteHistoryRepository implements HistoryRepository {
  const SqliteHistoryRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<CalendarDaySummary>> month(LocalDate monthStart) =>
      _db.transaction((tx) async {
        final first = LocalDate(monthStart.year, monthStart.month, 1);
        final next =
            LocalDate.fromDateTime(DateTime.utc(first.year, first.month + 1));
        final sessions = await tx.query(
          'workout_sessions',
          columns: ['workout_date', 'phase'],
          where: 'workout_date >= ? AND workout_date < ?',
          whereArgs: [first.iso8601, next.iso8601],
        );
        final schedule = await SqlitePlanSchedule.read(tx);
        return List.unmodifiable(
          List.generate(calendarDayDifference(first, next), (offset) {
            final date = first.addDays(offset);
            final days = schedule.on(date);
            final phases = sessions
                .where((row) => row['workout_date'] == date.iso8601)
                .map((row) => row['phase']);
            return CalendarDaySummary(
              date: date,
              hasSavedWorkout: phases.contains('saved'),
              hasUnfinishedWorkout: phases.any((phase) => phase != 'saved'),
              hasPlan: days.isNotEmpty,
              isAllRest: days.isNotEmpty && days.every((day) => day.day.isRest),
            );
          }),
        );
      });

  @override
  Future<List<WorkoutSession>> day(LocalDate date) =>
      _db.transaction((tx) => readDay(tx, date));

  @override
  Future<List<WorkoutSession>> recent({int limit = 20}) =>
      _db.transaction((tx) async {
        final rows = await tx.query(
          'workout_sessions',
          where: "phase = 'saved'",
          orderBy: 'workout_date DESC, started_at DESC, id',
          limit: limit,
        );
        return List.unmodifiable(
          [for (final row in rows) await WorkoutMapper.read(tx, row)],
        );
      });

  static Future<List<WorkoutSession>> readDay(
    DatabaseExecutor executor,
    LocalDate date,
  ) async {
    final rows = await executor.query(
      'workout_sessions',
      where: 'workout_date = ?',
      whereArgs: [date.iso8601],
      orderBy: 'started_at, id',
    );
    return List.unmodifiable(
      [for (final row in rows) await WorkoutMapper.read(executor, row)],
    );
  }

  @override
  Future<FitnessDayStats> stats(LocalDate today, {required int weekStart}) =>
      databaseGuard(() => readStats(_db.database, today, weekStart: weekStart));

  static Future<FitnessDayStats> readStats(
    DatabaseExecutor executor,
    LocalDate today, {
    required int weekStart,
  }) async {
    if (weekStart < DateTime.monday || weekStart > DateTime.sunday) {
      throw const AppFailure(
        FailureCode.validation,
        detail: 'weekStart must use weekday codes 1..7.',
      );
    }
    final weekday = DateTime.utc(today.year, today.month, today.day).weekday;
    final week = today.addDays(-((weekday - weekStart) % 7));
    final month = LocalDate(today.year, today.month, 1);
    final row = (await executor.rawQuery(
      '''SELECT
      COUNT(DISTINCT workout_date) AS total,
      COUNT(DISTINCT CASE WHEN workout_date >= ? AND workout_date <= ? THEN workout_date END) AS week,
      COUNT(DISTINCT CASE WHEN workout_date >= ? AND workout_date <= ? THEN workout_date END) AS month,
      MAX(ended_at) AS last_workout_at
      FROM workout_sessions WHERE phase = 'saved'
    ''',
      [week.iso8601, today.iso8601, month.iso8601, today.iso8601],
    ))
        .single;
    return FitnessDayStats(
      total: row['total'] as int,
      week: row['week'] as int,
      month: row['month'] as int,
      lastWorkoutAt: readUtc(row['last_workout_at']),
    );
  }

  @override
  Future<List<ExerciseRecord>> exerciseRecords(String exerciseId) =>
      databaseGuard(() async {
        final rows = await _db.database.rawQuery(
          '''
      SELECT ws.id AS session_id, s.id AS set_id, e.exercise_id, ws.workout_date,
        s.completed_at, s.unit, s.actual_weight, COALESCE(s.actual_reps, s.planned_reps) AS reps
      FROM workout_sets s
      JOIN workout_exercises e ON e.session_id = s.session_id AND e.id = s.exercise_id
      JOIN workout_sessions ws ON ws.id = s.session_id
      WHERE ws.phase = 'saved' AND s.status = 'completed' AND e.exercise_id = ?
      ORDER BY ws.workout_date DESC, s.completed_at DESC, ws.id, e.sort_order, s.sort_order
    ''',
          [exerciseId],
        );
        return List.unmodifiable([
          for (final row in rows)
            ExerciseRecord(
              sessionId: row['session_id'] as String,
              setId: row['set_id'] as String,
              exerciseId: row['exercise_id'] as String,
              date: readDate(row['workout_date']),
              completedAt: readUtc(row['completed_at'])!,
              unit: WeightUnit.fromCode(row['unit'] as String),
              weight: (row['actual_weight'] as num?)?.toDouble(),
              reps: row['reps'] as int,
            ),
        ]);
      });

  @override
  Future<void> correctSet(
    String sessionId,
    String setId, {
    required double? weight,
    required int reps,
  }) =>
      _db.transaction((tx) async {
        if ((weight != null && (!weight.isFinite || weight < 0)) || reps < 0) {
          throw const AppFailure(FailureCode.validation);
        }
        await _requireSaved(tx, sessionId);
        final changed = await tx.update(
          'workout_sets',
          {'actual_weight': weight, 'actual_reps': reps},
          where: 'session_id = ? AND id = ?',
          whereArgs: [sessionId, setId],
        );
        if (changed != 1) throw const AppFailure(FailureCode.notFound);
        await tx.rawUpdate(
          'UPDATE workout_sessions SET revision = revision + 1 WHERE id = ?',
          [sessionId],
        );
      });

  @override
  Future<void> updateNote(String sessionId, String note) =>
      _db.transaction((tx) async {
        await _requireSaved(tx, sessionId);
        await tx.rawUpdate(
          'UPDATE workout_sessions SET note = ?, revision = revision + 1 WHERE id = ?',
          [note.trim(), sessionId],
        );
      });

  @override
  Future<void> deleteSession(String id) => _db.transaction((tx) async {
        await _requireSaved(tx, id);
        await tx.delete('workout_sessions', where: 'id = ?', whereArgs: [id]);
      });

  static Future<void> _requireSaved(
    DatabaseExecutor executor,
    String id,
  ) async {
    final rows = await executor.query(
      'workout_sessions',
      columns: ['phase'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw const AppFailure(FailureCode.notFound);
    if (rows.single['phase'] != 'saved') {
      throw const AppFailure(FailureCode.conflict);
    }
  }
}
