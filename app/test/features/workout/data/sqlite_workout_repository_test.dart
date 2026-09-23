import 'dart:io';

import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/active_timer.dart';
import 'package:fitness_counter/features/workout/domain/workout_draft.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/test_database.dart';

void main() {
  final conflict = throwsA(
    isA<AppFailure>().having((e) => e.code, 'code', FailureCode.conflict),
  );

  for (final phase in [
    WorkoutPhase.active,
    WorkoutPhase.resting,
    WorkoutPhase.completedPaused,
    WorkoutPhase.finishing,
    WorkoutPhase.timeAnomaly,
  ]) {
    test('$phase is exclusive across repository instances', () async {
      final db = await openTestDatabase();
      addTearDown(db.close);
      final repo = SqliteWorkoutRepository(db);
      await repo.create(newSession().copyWith(phase: phase));
      await expectLater(
        SqliteWorkoutRepository(db).create(newSession(id: 'w2')),
        conflict,
      );
      expect((await repo.findUnfinished())!.id, 'w1');
      expect(await repo.find('w2'), isNull);
      await repo.discard('w1');
      expect(await db.database.query('workout_sets'), isEmpty);
      await repo.create(newSession(id: 'w2'));
    });
  }

  test('CAS prevents stale overwrites and create/save tree failures roll back',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqliteWorkoutRepository(db);
    await db.database.execute(
      "CREATE TRIGGER fail_workout_set BEFORE INSERT ON workout_sets WHEN NEW.id = 's2' BEGIN SELECT RAISE(ABORT, 'disk write failed'); END",
    );
    await expectLater(
      repo.create(newSession()),
      throwsA(
        isA<AppFailure>()
            .having((e) => e.code, 'code', FailureCode.persistence),
      ),
    );
    expect(await db.database.query('workout_sessions'), isEmpty);
    expect(await db.database.query('workout_exercises'), isEmpty);
    await db.database.execute('DROP TRIGGER fail_workout_set');
    await repo.create(newSession());
    await repo.save(newSession().copyWith(note: 'saved'), expectedRevision: 0);
    expect((await repo.find('w1'))!.revision, 1);
    await expectLater(
      repo.save(newSession().copyWith(note: 'stale'), expectedRevision: 0),
      conflict,
    );
    await db.database.execute(
      "CREATE TRIGGER fail_workout_set BEFORE INSERT ON workout_sets WHEN NEW.id = 's2' BEGIN SELECT RAISE(ABORT, 'disk write failed'); END",
    );
    final persisted = (await repo.find('w1'))!;
    await expectLater(
      repo.save(persisted.copyWith(note: 'lost'), expectedRevision: 1),
      throwsA(isA<AppFailure>()),
    );
    final after = (await repo.find('w1'))!;
    expect(after.note, 'saved');
    expect(after.revision, 1);
    expect(after.exercises.single.sets.map((s) => s.id), ['s1', 's2']);
  });

  test(
      'finalization validates completed set, is idempotent, and cannot reopen saved history',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqliteWorkoutRepository(db);
    await repo.create(newSession().copyWith(phase: WorkoutPhase.finishing));
    await expectLater(
      repo.saveCompleted('w1', note: '', expectedRevision: 0),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', FailureCode.validation),
      ),
    );
    await repo.discard('w1');
    await persistCompleted(repo);
    final before = (await repo.find('w1'))!;
    expect(before.phase, WorkoutPhase.saved);
    expect(before.revision, 2);
    expect(before.endedAt!.isUtc, isTrue);
    expect(before.finishCheckpoint, isNull);
    expect(before.exercises.single.sets.last.status, SetStatus.skipped);
    await repo.saveCompleted('w1', note: 'first note', expectedRevision: 1);
    final after = (await repo.find('w1'))!;
    expect(after.endedAt, before.endedAt);
    expect(after.revision, 2);
    expect(await repo.findUnfinished(), isNull);
    expect(await db.database.query('workout_sessions'), hasLength(1));
    await expectLater(
      repo.save(
        before.copyWith(phase: WorkoutPhase.active),
        expectedRevision: 2,
      ),
      conflict,
    );
    await expectLater(
      repo.saveCompleted('w1', note: 'stale note', expectedRevision: 1),
      conflict,
    );
    await expectLater(repo.discard('w1'), conflict);
  });

  test('finalization SQL failure leaves complete unfinished draft intact',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqliteWorkoutRepository(db);
    var session = newSession();
    await repo.create(session);
    session =
        WorkoutMachine.transition(session, const StartSet('s1'), trainingTime);
    session = WorkoutMachine.transition(
      session,
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
      trainingTime.add(const Duration(seconds: 20)),
    );
    session = WorkoutMachine.transition(
      session,
      const PrepareFinish(),
      trainingTime.add(const Duration(seconds: 25)),
    );
    await repo.save(session, expectedRevision: 0);
    await db.database.execute(
      "CREATE TRIGGER fail_finalize BEFORE UPDATE OF phase ON workout_sessions WHEN NEW.phase = 'saved' BEGIN SELECT RAISE(ABORT, 'disk write failed'); END",
    );
    await expectLater(
      repo.saveCompleted(
        'w1',
        note: 'retain edit in controller',
        expectedRevision: 1,
      ),
      throwsA(isA<AppFailure>()),
    );
    final after = (await repo.findUnfinished())!;
    expect(after.phase, WorkoutPhase.finishing);
    expect(after.revision, 1);
    expect(after.finishCheckpoint, isNotNull);
    expect(after.exercises.single.sets.first.actualReps, 8);
    expect(after.note, '');
  });

  test('source rename/delete never modifies plan or workout snapshots',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final exercises = SqliteExerciseRepository(db);
    final plans = SqlitePlanRepository(db);
    final workouts = SqliteWorkoutRepository(db);
    await exercises
        .save(catalogExercise(id: 'bench-press', name: 'Bench Press'));
    await plans.save(
      catalogPlan(id: 'plan-1'),
      catalogRevision(
        id: 'revision-1',
        planId: 'plan-1',
        effectiveFrom: LocalDate(2026, 9, 1),
      ),
    );
    await persistCompleted(workouts);
    await exercises.save(catalogExercise(id: 'bench-press', name: 'Renamed'));
    await exercises.delete('bench-press');
    expect(
      (await plans.revisions('plan-1'))
          .single
          .days
          .first
          .exercises
          .single
          .nameSnapshot,
      '哑铃卧推',
    );
    await plans.delete('plan-1');
    final snapshot = (await workouts.find('w1'))!.exercises.single;
    expect(snapshot.nameSnapshot, 'Bench Press');
    expect(snapshot.sourcePlanName, 'Strength');
    expect(snapshot.sourceRevisionId, 'revision-1');
    expect(snapshot.sourceDayName, 'Push');
    expect(snapshot.sets.first.plannedWeight, 20);
    expect(snapshot.sets.first.actualWeight, 22.5);
  });

  test(
      'file close/reopen preserves every snapshot field, timers, anomaly, checkpoint and list reorder',
      () async {
    final dir = await Directory.systemTemp.createTemp('fitness-roundtrip-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/roundtrip.db';
    var db = await openTestDatabase(path: path);
    final set = WorkoutSet(
      id: 'complete',
      order: 99,
      plannedWeight: 31.5,
      plannedReps: 11,
      unit: WeightUnit.lb,
      actualWeight: 32.5,
      actualReps: 9,
      status: SetStatus.completed,
      startedAt: trainingTime,
      completedAt: trainingTime.add(const Duration(seconds: 17)),
      skippedAt: null,
      setDurationSeconds: 17,
      preSetRestSeconds: 83,
      temporary: true,
    );
    final pending = WorkoutSet(
      id: 'pending',
      order: 0,
      plannedWeight: 0,
      plannedReps: 8,
      unit: WeightUnit.bodyweight,
      temporary: false,
    );
    final exercise = WorkoutExercise(
      id: 'snapshot',
      exerciseId: 'source',
      nameSnapshot: 'Snapshot name',
      categorySnapshot: ExerciseCategory.fullBody,
      equipmentSnapshot: ExerciseEquipment.resistanceBand,
      unitSnapshot: WeightUnit.none,
      sourcePlanId: 'plan',
      sourcePlanName: 'Plan name',
      sourceRevisionId: 'rev',
      sourceDayNumber: 4,
      sourceDayName: 'Day name',
      note: 'Exercise note',
      targetRestSeconds: 123,
      order: 4,
      temporary: true,
      sets: [set, pending],
    );
    final other = WorkoutExercise(
      id: 'other',
      exerciseId: 'free',
      nameSnapshot: 'Free',
      categorySnapshot: ExerciseCategory.core,
      equipmentSnapshot: ExerciseEquipment.bodyweight,
      unitSnapshot: WeightUnit.bodyweight,
      note: '',
      targetRestSeconds: 30,
      order: 0,
      temporary: false,
      sets: [
        WorkoutSet(
          id: 'skipped',
          order: 0,
          plannedWeight: 0,
          plannedReps: 1,
          unit: WeightUnit.none,
          status: SetStatus.skipped,
          skippedAt: trainingTime,
          temporary: false,
        ),
      ],
    );
    var original = newSession(date: LocalDate(2026, 9, 16))
        .copyWith(exercises: [other, exercise]);
    await SqliteWorkoutRepository(db).create(original);
    // Persist the list contract, including stale explicit order fields.
    original = original.copyWith(
      exercises: [
        exercise.copyWith(sets: [pending, set]),
        other,
      ],
      phase: WorkoutPhase.timeAnomaly,
      note: 'Workout note',
      activeSetId: 'pending',
      selectedSetId: 'complete',
      restStartedAt: trainingTime,
      restTargetSeconds: 137,
      timer: ActiveTimer(
        accumulatedActiveSeconds: 501,
        runningSegmentStartedAt: trainingTime,
      ),
      setTimer: ActiveTimer(
        accumulatedActiveSeconds: 19,
        runningSegmentStartedAt: trainingTime,
      ),
      restTimer: ActiveTimer(
        accumulatedActiveSeconds: 88,
        runningSegmentStartedAt: trainingTime,
      ),
      anomaly: WorkoutTimeAnomaly(
        reason: TimerAnomalyReason.clockRollback,
        detectedAt: trainingTime,
        previousPhase: WorkoutPhase.resting,
      ),
      finishCheckpoint: WorkoutFinishCheckpoint(
        phase: WorkoutPhase.resting,
        exercises: [other, exercise],
        timer: ActiveTimer(
          accumulatedActiveSeconds: 411,
          runningSegmentStartedAt: trainingTime,
        ),
        setTimer: ActiveTimer(accumulatedActiveSeconds: 12),
        restTimer: ActiveTimer(accumulatedActiveSeconds: 70),
        activeSetId: 'complete',
        selectedSetId: 'pending',
        restStartedAt: trainingTime,
        restTargetSeconds: 111,
      ),
    );
    await SqliteWorkoutRepository(db).save(original, expectedRevision: 0);
    await db.close();
    db = await openTestDatabase(path: path);
    addTearDown(db.close);
    final actual = (await SqliteWorkoutRepository(db).findUnfinished())!;
    expect(actual.id, 'w1');
    expect(actual.workoutDate, LocalDate(2026, 9, 16));
    expect(actual.startedAt, trainingTime);
    expect(actual.endedAt, isNull);
    expect(actual.phase, WorkoutPhase.timeAnomaly);
    expect(actual.note, 'Workout note');
    expect(actual.revision, 1);
    expect(actual.activeSetId, 'pending');
    expect(actual.selectedSetId, 'complete');
    expect(actual.restStartedAt, trainingTime);
    expect(actual.restTargetSeconds, 137);
    expect(actual.timer.accumulatedActiveSeconds, 501);
    expect(actual.setTimer.accumulatedActiveSeconds, 19);
    expect(actual.restTimer.accumulatedActiveSeconds, 88);
    for (final timer in [actual.timer, actual.setTimer, actual.restTimer]) {
      expect(timer.runningSegmentStartedAt, trainingTime);
      expect(timer.runningSegmentStartedAt!.isUtc, isTrue);
    }
    expect(actual.anomaly!.reason, TimerAnomalyReason.clockRollback);
    expect(actual.anomaly!.detectedAt, trainingTime);
    expect(actual.anomaly!.previousPhase, WorkoutPhase.resting);
    expect(actual.exercises.map((e) => e.id), ['snapshot', 'other']);
    expect(
      actual.exercises.first.sets.map((s) => s.id),
      ['pending', 'complete'],
    );
    final e = actual.exercises.first;
    expect(e.order, 0);
    expect(e.exerciseId, 'source');
    expect(e.nameSnapshot, 'Snapshot name');
    expect(e.categorySnapshot, ExerciseCategory.fullBody);
    expect(e.equipmentSnapshot, ExerciseEquipment.resistanceBand);
    expect(e.unitSnapshot, WeightUnit.none);
    expect(e.sourcePlanId, 'plan');
    expect(e.sourcePlanName, 'Plan name');
    expect(e.sourceRevisionId, 'rev');
    expect(e.sourceDayNumber, 4);
    expect(e.sourceDayName, 'Day name');
    expect(e.note, 'Exercise note');
    expect(e.targetRestSeconds, 123);
    expect(e.temporary, isTrue);
    final s = e.sets.last;
    expect(s.order, 1);
    expect(s.plannedWeight, 31.5);
    expect(s.plannedReps, 11);
    expect(s.unit, WeightUnit.lb);
    expect(s.actualWeight, 32.5);
    expect(s.actualReps, 9);
    expect(s.status, SetStatus.completed);
    expect(s.startedAt, trainingTime);
    expect(s.completedAt, trainingTime.add(const Duration(seconds: 17)));
    expect(s.skippedAt, isNull);
    expect(s.setDurationSeconds, 17);
    expect(s.preSetRestSeconds, 83);
    expect(s.temporary, isTrue);
    expect(e.sets.first.actualWeight, isNull);
    expect(e.sets.first.actualReps, isNull);
    expect(e.sets.first.status, SetStatus.pending);
    expect(e.sets.first.startedAt, isNull);
    expect(e.sets.first.completedAt, isNull);
    expect(e.sets.first.temporary, isFalse);
    expect(actual.exercises.last.sourcePlanId, isNull);
    expect(actual.exercises.last.sets.single.skippedAt, trainingTime);
    final checkpoint = actual.finishCheckpoint!;
    expect(checkpoint.phase, WorkoutPhase.resting);
    expect(checkpoint.exercises.map((e) => e.id), ['other', 'snapshot']);
    expect(
      checkpoint.exercises.last.sets.map((s) => s.id),
      ['complete', 'pending'],
    );
    expect(checkpoint.exercises.last.sets.first.actualWeight, 32.5);
    expect(checkpoint.timer.accumulatedActiveSeconds, 411);
    expect(checkpoint.timer.runningSegmentStartedAt, trainingTime);
    expect(checkpoint.setTimer.accumulatedActiveSeconds, 12);
    expect(checkpoint.setTimer.runningSegmentStartedAt, isNull);
    expect(checkpoint.restTimer.accumulatedActiveSeconds, 70);
    expect(checkpoint.restTimer.runningSegmentStartedAt, isNull);
    expect(checkpoint.activeSetId, 'complete');
    expect(checkpoint.selectedSetId, 'pending');
    expect(checkpoint.restStartedAt, trainingTime);
    expect(checkpoint.restTargetSeconds, 111);
  });

  test('reducer exercise reorder survives a real file reopen', () async {
    final dir = await Directory.systemTemp.createTemp('fitness-reorder-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/reorder.db';
    var db = await openTestDatabase(path: path);
    var session = newSession();
    final second = WorkoutExercise(
      id: 'e2',
      exerciseId: 'second',
      nameSnapshot: 'Second',
      categorySnapshot: ExerciseCategory.core,
      equipmentSnapshot: ExerciseEquipment.bodyweight,
      unitSnapshot: WeightUnit.bodyweight,
      note: '',
      targetRestSeconds: 30,
      order: 1,
      temporary: true,
      sets: [
        WorkoutSet(
          id: 's3',
          order: 0,
          plannedWeight: 0,
          plannedReps: 10,
          unit: WeightUnit.bodyweight,
          temporary: true,
        ),
      ],
    );
    session = session.copyWith(exercises: [...session.exercises, second]);
    await SqliteWorkoutRepository(db).create(session);
    session = WorkoutMachine.transition(
      session,
      const ReorderPendingExercises(['e2', 'e1']),
      trainingTime,
    );
    expect(session.exercises.map((e) => e.id), ['e2', 'e1']);
    await SqliteWorkoutRepository(db).save(session, expectedRevision: 0);
    await db.close();
    db = await openTestDatabase(path: path);
    addTearDown(db.close);
    expect(
      (await SqliteWorkoutRepository(db).find('w1'))!
          .exercises
          .map((e) => e.id),
      ['e2', 'e1'],
    );
  });
}
