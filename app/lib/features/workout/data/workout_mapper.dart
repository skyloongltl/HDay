import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/data/sql_values.dart';
import '../../exercises/domain/exercise.dart';
import '../domain/active_timer.dart';
import '../domain/workout_draft.dart';
import '../domain/workout_session.dart';

/// SQLite/JSON rows stop at this data boundary. Every returned domain list is
/// copied by its constructor; checkpoint snapshots have their own full tree.
abstract final class WorkoutMapper {
  static Map<String, Object?> sessionRow(WorkoutSession session) => {
        'id': session.id,
        'workout_date': session.workoutDate.iso8601,
        'started_at': utcValue(session.startedAt),
        'ended_at': utcValue(session.endedAt),
        'phase': session.phase.name,
        ..._timerRow('timer', session.timer),
        ..._timerRow('set_timer', session.setTimer),
        ..._timerRow('rest_timer', session.restTimer),
        'active_set_id': session.activeSetId,
        'selected_set_id': session.selectedSetId,
        'rest_started_at': utcValue(session.restStartedAt),
        'rest_target_seconds': session.restTargetSeconds,
        'note': session.note,
        'revision': session.revision,
        'anomaly_reason': session.anomaly?.reason.name,
        'anomaly_detected_at': utcValue(session.anomaly?.detectedAt),
        'anomaly_previous_phase': session.anomaly?.previousPhase.name,
        'finish_checkpoint': session.finishCheckpoint == null
            ? null
            : jsonEncode(_checkpointRow(session.finishCheckpoint!)),
      };

  static Future<WorkoutSession?> find(
    DatabaseExecutor executor,
    String id,
  ) async {
    final rows = await executor
        .query('workout_sessions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : read(executor, rows.single);
  }

  static Future<WorkoutSession> read(
    DatabaseExecutor executor,
    Map<String, Object?> row,
  ) async {
    final sessionId = row['id'] as String;
    final exerciseRows = await executor.query(
      'workout_exercises',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sort_order',
    );
    final exercises = <WorkoutExercise>[];
    for (final exerciseRow in exerciseRows) {
      final sets = await executor.query(
        'workout_sets',
        where: 'session_id = ? AND exercise_id = ?',
        whereArgs: [sessionId, exerciseRow['id']],
        orderBy: 'sort_order',
      );
      exercises.add(_readExercise(exerciseRow, sets.map(_readSet).toList()));
    }
    return WorkoutSession(
      id: sessionId,
      workoutDate: readDate(row['workout_date']),
      startedAt: readUtc(row['started_at'])!,
      endedAt: readUtc(row['ended_at']),
      phase: WorkoutPhase.values.byName(row['phase'] as String),
      exercises: exercises,
      timer: _readTimer(row, 'timer'),
      setTimer: _readTimer(row, 'set_timer'),
      restTimer: _readTimer(row, 'rest_timer'),
      activeSetId: row['active_set_id'] as String?,
      selectedSetId: row['selected_set_id'] as String?,
      restStartedAt: readUtc(row['rest_started_at']),
      restTargetSeconds: row['rest_target_seconds'] as int?,
      note: row['note'] as String,
      revision: row['revision'] as int,
      anomaly: row['anomaly_reason'] == null
          ? null
          : WorkoutTimeAnomaly(
              reason: TimerAnomalyReason.values
                  .byName(row['anomaly_reason'] as String),
              detectedAt: readUtc(row['anomaly_detected_at'])!,
              previousPhase: WorkoutPhase.values
                  .byName(row['anomaly_previous_phase'] as String),
            ),
      finishCheckpoint: row['finish_checkpoint'] == null
          ? null
          : _readCheckpoint(
              _object(jsonDecode(row['finish_checkpoint'] as String)),
            ),
    );
  }

  /// Always persist list position, since reducer reordering may leave the old
  /// order fields intact. The same normalization applies to checkpoint trees.
  static Future<void> writeChildren(
    DatabaseExecutor executor,
    WorkoutSession session,
  ) async {
    await executor.delete(
      'workout_exercises',
      where: 'session_id = ?',
      whereArgs: [session.id],
    );
    for (final (position, exercise) in session.exercises.indexed) {
      await executor.insert(
        'workout_exercises',
        {'session_id': session.id, ..._exerciseRow(exercise, position)},
      );
      for (final (position, set) in exercise.sets.indexed) {
        await executor.insert('workout_sets', {
          'session_id': session.id,
          'exercise_id': exercise.id,
          ..._setRow(set, position),
        });
      }
    }
    final references = {
      for (final exercise in [
        ...session.exercises,
        ...?session.finishCheckpoint?.exercises,
      ])
        if (exercise.sourceRevisionId != null) exercise.sourceRevisionId!,
    };
    for (final revisionId in references) {
      await executor.insert(
        'workout_revision_references',
        {'session_id': session.id, 'revision_id': revisionId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Map<String, Object?> _exerciseRow(
    WorkoutExercise exercise,
    int position,
  ) =>
      {
        'id': exercise.id,
        'exercise_id': exercise.exerciseId,
        'name_snapshot': exercise.nameSnapshot,
        'category_snapshot': exercise.categorySnapshot.code,
        'equipment_snapshot': exercise.equipmentSnapshot.code,
        'unit_snapshot': exercise.unitSnapshot.code,
        'source_plan_id': exercise.sourcePlanId,
        'source_plan_name': exercise.sourcePlanName,
        'source_revision_id': exercise.sourceRevisionId,
        'source_day_number': exercise.sourceDayNumber,
        'source_day_name': exercise.sourceDayName,
        'note': exercise.note,
        'target_rest_seconds': exercise.targetRestSeconds,
        'sort_order': position,
        'temporary': exercise.temporary ? 1 : 0,
      };

  static Map<String, Object?> _setRow(WorkoutSet set, int position) => {
        'id': set.id,
        'sort_order': position,
        'planned_weight': set.plannedWeight,
        'planned_reps': set.plannedReps,
        'unit': set.unit.code,
        'actual_weight': set.actualWeight,
        'actual_reps': set.actualReps,
        'status': set.status.name,
        'started_at': utcValue(set.startedAt),
        'completed_at': utcValue(set.completedAt),
        'skipped_at': utcValue(set.skippedAt),
        'set_duration_seconds': set.setDurationSeconds,
        'pre_set_rest_seconds': set.preSetRestSeconds,
        'temporary': set.temporary ? 1 : 0,
      };

  static WorkoutExercise _readExercise(
    Map<String, Object?> row,
    List<WorkoutSet> sets,
  ) =>
      WorkoutExercise(
        id: row['id'] as String,
        exerciseId: row['exercise_id'] as String,
        nameSnapshot: row['name_snapshot'] as String,
        categorySnapshot:
            ExerciseCategory.fromCode(row['category_snapshot'] as String),
        equipmentSnapshot:
            ExerciseEquipment.fromCode(row['equipment_snapshot'] as String),
        unitSnapshot: WeightUnit.fromCode(row['unit_snapshot'] as String),
        sourcePlanId: row['source_plan_id'] as String?,
        sourcePlanName: row['source_plan_name'] as String?,
        sourceRevisionId: row['source_revision_id'] as String?,
        sourceDayNumber: row['source_day_number'] as int?,
        sourceDayName: row['source_day_name'] as String?,
        note: row['note'] as String,
        targetRestSeconds: row['target_rest_seconds'] as int,
        order: row['sort_order'] as int,
        temporary: row['temporary'] == 1,
        sets: sets,
      );

  static WorkoutSet _readSet(Map<String, Object?> row) => WorkoutSet(
        id: row['id'] as String,
        order: row['sort_order'] as int,
        plannedWeight: (row['planned_weight'] as num).toDouble(),
        plannedReps: row['planned_reps'] as int,
        unit: WeightUnit.fromCode(row['unit'] as String),
        actualWeight: (row['actual_weight'] as num?)?.toDouble(),
        actualReps: row['actual_reps'] as int?,
        status: SetStatus.values.byName(row['status'] as String),
        startedAt: readUtc(row['started_at']),
        completedAt: readUtc(row['completed_at']),
        skippedAt: readUtc(row['skipped_at']),
        setDurationSeconds: row['set_duration_seconds'] as int,
        preSetRestSeconds: row['pre_set_rest_seconds'] as int,
        temporary: row['temporary'] == 1,
      );

  static Map<String, Object?> _timerRow(String prefix, ActiveTimer timer) => {
        '${prefix}_seconds': timer.accumulatedActiveSeconds,
        '${prefix}_started_at': utcValue(timer.runningSegmentStartedAt),
      };

  static ActiveTimer _readTimer(Map<String, Object?> row, String prefix) =>
      ActiveTimer(
        accumulatedActiveSeconds: row['${prefix}_seconds'] as int,
        runningSegmentStartedAt: readUtc(row['${prefix}_started_at']),
      );

  static Map<String, Object?> _checkpointRow(
    WorkoutFinishCheckpoint checkpoint,
  ) =>
      {
        'phase': checkpoint.phase.name,
        ..._timerRow('timer', checkpoint.timer),
        ..._timerRow('set_timer', checkpoint.setTimer),
        ..._timerRow('rest_timer', checkpoint.restTimer),
        'active_set_id': checkpoint.activeSetId,
        'selected_set_id': checkpoint.selectedSetId,
        'rest_started_at': utcValue(checkpoint.restStartedAt),
        'rest_target_seconds': checkpoint.restTargetSeconds,
        'exercises': [
          for (final (position, exercise) in checkpoint.exercises.indexed)
            {
              ..._exerciseRow(exercise, position),
              'sets': [
                for (final (position, set) in exercise.sets.indexed)
                  _setRow(set, position),
              ],
            },
        ],
      };

  static WorkoutFinishCheckpoint _readCheckpoint(Map<String, Object?> row) =>
      WorkoutFinishCheckpoint(
        phase: WorkoutPhase.values.byName(row['phase'] as String),
        exercises: [
          for (final value in row['exercises'] as List<Object?>)
            _readExercise(_object(value), [
              for (final set in _object(value)['sets'] as List<Object?>)
                _readSet(_object(set)),
            ]),
        ],
        timer: _readTimer(row, 'timer'),
        setTimer: _readTimer(row, 'set_timer'),
        restTimer: _readTimer(row, 'rest_timer'),
        activeSetId: row['active_set_id'] as String?,
        selectedSetId: row['selected_set_id'] as String?,
        restStartedAt: readUtc(row['rest_started_at']),
        restTargetSeconds: row['rest_target_seconds'] as int?,
      );

  static Map<String, Object?> _object(Object? value) =>
      (value as Map).cast<String, Object?>();
}
