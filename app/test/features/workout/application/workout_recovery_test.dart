import 'dart:io';

import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/application/workout_controller.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/active_timer.dart';
import 'package:fitness_counter/features/workout/domain/workout_draft.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as paths;

import '../../../support/fake_clock.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  test('restart restores rest duration onto the next started set', () async {
    final directory = await Directory.systemTemp.createTemp('task8-recovery-');
    addTearDown(() => directory.delete(recursive: true));
    final path = paths.join(directory.path, 'workout.sqlite');
    var db = await openTestDatabase(path: path);
    var repository = SqliteWorkoutRepository(db);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final first = WorkoutController(repository: repository, clock: clock);
    await first.start(twoSetDraft());
    await first.dispatch(const StartSet('s1'));
    clock.advance(const Duration(seconds: 30));
    await first.dispatch(
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    );
    clock.advance(const Duration(seconds: 125));
    first.dispose();
    await db.close();

    db = await openTestDatabase(path: path);
    addTearDown(db.close);
    repository = SqliteWorkoutRepository(db);
    final restored = WorkoutController(repository: repository, clock: clock);
    addTearDown(restored.dispose);
    await restored.restore();
    await restored.dispatch(const StartSet('s2'));

    expect(
      restored.state.session!.exercises.first.sets.last.preSetRestSeconds,
      125,
    );
  });

  test('completedPaused stays frozen until a newly added set starts', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final first = WorkoutController(
      repository: SqliteWorkoutRepository(db),
      clock: clock,
    );
    await first.start(oneSetDraft());
    await first.dispatch(const StartSet('s1'));
    clock.advance(const Duration(seconds: 30));
    await first.dispatch(
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    );
    first.dispose();
    clock.advance(const Duration(minutes: 5));

    final restored = WorkoutController(
      repository: SqliteWorkoutRepository(db),
      clock: clock,
    );
    addTearDown(restored.dispose);
    await restored.restore();
    await restored.dispatch(AddSet('e1', temporarySet('s2')));
    clock.advance(const Duration(minutes: 2));
    expect(restored.state.session!.timer.read(clock.nowUtc()).seconds, 30);

    await restored.dispatch(const StartSet('s2'));
    clock.advance(const Duration(seconds: 10));
    expect(restored.state.session!.timer.read(clock.nowUtc()).seconds, 40);
  });

  test('finishing checkpoint survives restart and excludes summary time',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final first = WorkoutController(
      repository: SqliteWorkoutRepository(db),
      clock: clock,
    );
    await first.start(twoSetDraft());
    await first.dispatch(const StartSet('s1'));
    clock.advance(const Duration(seconds: 30));
    await first.dispatch(
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    );
    clock.advance(const Duration(seconds: 125));
    await first.dispatch(const PrepareFinish());
    first.dispose();
    clock.advance(const Duration(minutes: 10));

    final restored = WorkoutController(
      repository: SqliteWorkoutRepository(db),
      clock: clock,
    );
    addTearDown(restored.dispose);
    await restored.restore();
    expect(restored.state.session!.phase, WorkoutPhase.finishing);
    expect(
      restored.state.session!.finishCheckpoint!.phase,
      WorkoutPhase.resting,
    );
    expect(
      restored
          .state.session!.finishCheckpoint!.restTimer.accumulatedActiveSeconds,
      125,
    );

    await restored.dispatch(const ContinueWorkout());
    clock.advance(const Duration(seconds: 5));
    await restored.dispatch(const StartSet('s2'));
    expect(
      restored.state.session!.exercises.first.sets.last.preSetRestSeconds,
      130,
    );
    expect(restored.state.session!.timer.accumulatedActiveSeconds, 155);
    expect(restored.state.session!.timer.read(clock.nowUtc()).seconds, 160);
  });

  test('rollback anomaly survives restore and confirmation drops bad interval',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final start = DateTime.utc(2026, 9, 15, 10);
    final clock = FakeClock(start);
    final first = WorkoutController(
      repository: SqliteWorkoutRepository(db),
      clock: clock,
    );
    await first.start(twoSetDraft());
    await first.dispatch(const StartSet('s1'));
    clock.setUtc(start.subtract(const Duration(seconds: 1)));
    await first.dispatch(const SelectSet('s2'));
    expect(first.state.session!.phase, WorkoutPhase.timeAnomaly);
    first.dispose();

    final restored = WorkoutController(
      repository: SqliteWorkoutRepository(db),
      clock: clock,
    );
    addTearDown(restored.dispose);
    await restored.restore();
    expect(
      restored.state.session!.anomaly!.reason,
      TimerAnomalyReason.clockRollback,
    );
    expect(restored.state.session!.timer.accumulatedActiveSeconds, 0);

    clock.setUtc(start.add(const Duration(minutes: 1)));
    await restored.dispatch(ConfirmTime(nowUtc: clock.nowUtc()));
    expect(restored.state.session!.phase, WorkoutPhase.active);
    expect(
      restored.state.session!.timer.runningSegmentStartedAt,
      clock.nowUtc(),
    );
  });

  test('a running segment over 24 hours persists an explicit anomaly',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final controller = WorkoutController(
      repository: SqliteWorkoutRepository(db),
      clock: clock,
    );
    addTearDown(controller.dispose);
    await controller.start(twoSetDraft());
    clock.advance(const Duration(hours: 24, seconds: 1));

    await controller.dispatch(const SelectSet('s2'));

    expect(controller.state.session!.phase, WorkoutPhase.timeAnomaly);
    expect(
      controller.state.session!.anomaly!.reason,
      TimerAnomalyReason.segmentTooLong,
    );
    expect(
      (await SqliteWorkoutRepository(db).findUnfinished())!.phase,
      WorkoutPhase.timeAnomaly,
    );
  });

  test('every editable event restores its complete committed snapshot',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repository = SqliteWorkoutRepository(db);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    var controller = WorkoutController(repository: repository, clock: clock);
    await controller.start(twoSetDraft());

    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const SelectSet('s2'),
    );
    expect(controller.state.session!.selectedSetId, 's2');
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const StartSet('s2'),
    );
    expect(controller.state.session!.activeSetId, 's2');
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const UpdateActual('s2', weight: 22, reps: 7),
    );
    expect(controller.state.session!.exercises.single.sets.last.actualReps, 7);
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const SkipSet('s2'),
    );
    expect(
      controller.state.session!.exercises.single.sets.last.status,
      SetStatus.skipped,
    );
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      AddSet('e1', temporarySet('s3', order: 2)),
    );
    expect(
      controller.state.session!.exercises.single.sets.last.temporary,
      isTrue,
    );
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      AddExercise(_temporaryExercise()),
    );
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const ReorderPendingExercises(['e2', 'e1']),
    );
    expect(
      controller.state.session!.exercises.map((item) => item.id),
      ['e2', 'e1'],
    );
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const DeletePendingSet('s3'),
    );
    expect(
      controller.state.session!.exercises
          .expand((item) => item.sets)
          .map((item) => item.id),
      isNot(contains('s3')),
    );
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const SkipExercise('e2'),
    );
    expect(
      controller.state.session!.exercises.first.sets.single.status,
      SetStatus.skipped,
    );
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const StartSet('s1'),
    );
    clock.advance(const Duration(seconds: 12));
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    );
    expect(controller.state.session!.phase, WorkoutPhase.completedPaused);
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      AddSet('e1', temporarySet('s5', order: 2)),
    );
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const PrepareFinish(),
    );
    expect(controller.state.session!.finishCheckpoint, isNotNull);
    controller = await _dispatchAndRestore(
      controller,
      repository,
      clock,
      const ContinueWorkout(),
    );
    expect(controller.state.session!.phase, WorkoutPhase.completedPaused);
    expect(controller.state.session!.revision, 14);
    controller.dispose();
  });
}

Future<WorkoutController> _dispatchAndRestore(
  WorkoutController current,
  SqliteWorkoutRepository repository,
  FakeClock clock,
  WorkoutEvent event,
) async {
  await current.dispatch(event);
  current.dispose();
  final restored = WorkoutController(repository: repository, clock: clock);
  await restored.restore();
  return restored;
}

WorkoutExercise _temporaryExercise() => WorkoutExercise(
      id: 'e2',
      exerciseId: 'row',
      nameSnapshot: '划船',
      categorySnapshot: ExerciseCategory.back,
      equipmentSnapshot: ExerciseEquipment.cable,
      unitSnapshot: WeightUnit.kg,
      note: '',
      targetRestSeconds: 60,
      order: 1,
      temporary: true,
      sets: [temporarySet('s4', order: 0)],
    );
