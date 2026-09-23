import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/domain/active_timer.dart';
import 'package:fitness_counter/features/workout/domain/workout_draft.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/workout_fixtures.dart';

void main() {
  final t = DateTime.utc(2026, 9, 15, 10);

  group('selection and active-set invariants', () {
    test('selecting a set does not start it', () {
      var session = WorkoutMachine.start(
        id: 'w1',
        draft: twoSetDraft(),
        nowUtc: t,
      );

      session = WorkoutMachine.transition(session, const SelectSet('s2'), t);

      expect(session.selectedSetId, 's2');
      expect(session.activeSetId, isNull);
      expect(_set(session, 's2').status, SetStatus.pending);
    });

    test('starting a second set while one is in progress is rejected', () {
      var session = WorkoutMachine.start(
        id: 'w1',
        draft: twoSetDraft(),
        nowUtc: t,
      );
      session = WorkoutMachine.transition(session, const StartSet('s1'), t);

      expect(
        () => WorkoutMachine.transition(session, const StartSet('s2'), t),
        throwsStateError,
      );
    });

    test('completing a set other than the active set is rejected', () {
      var session = WorkoutMachine.start(
        id: 'w1',
        draft: twoSetDraft(),
        nowUtc: t,
      );
      session = WorkoutMachine.transition(session, const StartSet('s1'), t);

      expect(
        () => WorkoutMachine.transition(
          session,
          const CompleteSet('s2', actualWeight: 20, actualReps: 8),
          t.add(const Duration(seconds: 10)),
        ),
        throwsStateError,
      );
    });
  });

  group('completion and rest', () {
    test('ordinary completion enters rest without automatically starting', () {
      var session = _startedTwoSetSession(t);

      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 30)),
      );
      final afterTarget = WorkoutMachine.transition(
        session,
        const SelectSet('s2'),
        t.add(const Duration(seconds: 120)),
      );

      expect(afterTarget.phase, WorkoutPhase.resting);
      expect(afterTarget.restTargetSeconds, 90);
      expect(afterTarget.activeSetId, isNull);
      expect(_set(afterTarget, 's2').status, SetStatus.pending);
    });

    test('a zero-second rest target still waits for an explicit start', () {
      final original = twoSetDraft().exercises.single;
      final draft = WorkoutDraft(
        workoutDate: twoSetDraft().workoutDate,
        exercises: [original.copyWith(targetRestSeconds: 0)],
      );
      var session = WorkoutMachine.start(id: 'w1', draft: draft, nowUtc: t);
      session = WorkoutMachine.transition(session, const StartSet('s1'), t);

      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 10)),
      );

      expect(session.phase, WorkoutPhase.resting);
      expect(session.restTargetSeconds, 0);
      expect(_set(session, 's2').status, SetStatus.pending);
    });

    test('rest duration belongs to the next set actually started', () {
      var session = _startedTwoSetSession(t);
      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 30)),
      );

      session = WorkoutMachine.transition(
        session,
        const StartSet('s2'),
        t.add(const Duration(seconds: 155)),
      );

      expect(_set(session, 's2').preSetRestSeconds, 125);
      expect(session.phase, WorkoutPhase.active);
    });

    test('skipping and reordering pending work do not close rest', () {
      final base = twoSetDraft().exercises.single;
      final extraExercise = WorkoutExercise(
        id: 'e2',
        exerciseId: 'row',
        nameSnapshot: 'Row',
        categorySnapshot: ExerciseCategory.back,
        equipmentSnapshot: ExerciseEquipment.cable,
        unitSnapshot: WeightUnit.kg,
        note: '',
        targetRestSeconds: 90,
        order: 1,
        temporary: true,
        sets: [temporarySet('s3')],
      );
      final draft = WorkoutDraft(
        workoutDate: twoSetDraft().workoutDate,
        exercises: [base, extraExercise],
      );
      var session = WorkoutMachine.start(id: 'w1', draft: draft, nowUtc: t);
      session = WorkoutMachine.transition(session, const StartSet('s1'), t);
      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 30)),
      );
      session = WorkoutMachine.transition(
        session,
        const SkipSet('s2'),
        t.add(const Duration(seconds: 60)),
      );
      session = WorkoutMachine.transition(
        session,
        const ReorderPendingExercises(['e2']),
        t.add(const Duration(seconds: 90)),
      );

      session = WorkoutMachine.transition(
        session,
        const StartSet('s3'),
        t.add(const Duration(seconds: 155)),
      );

      expect(_set(session, 's3').preSetRestSeconds, 125);
      expect(session.exercises.first.id, 'e1');
    });

    test('skipping the final pending set pauses the session', () {
      var session = _startedTwoSetSession(t);
      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 30)),
      );

      session = WorkoutMachine.transition(
        session,
        const SkipSet('s2'),
        t.add(const Duration(seconds: 40)),
      );

      expect(session.phase, WorkoutPhase.completedPaused);
      expect(session.timer.read(t.add(const Duration(minutes: 5))).seconds, 40);
    });

    test('skipping active sets settles their time and pauses only at the end',
        () {
      var session = _startedTwoSetSession(t);

      session = WorkoutMachine.transition(
        session,
        const SkipSet('s1'),
        t.add(const Duration(seconds: 15)),
      );

      expect(_set(session, 's1').status, SetStatus.skipped);
      expect(_set(session, 's1').setDurationSeconds, 15);
      expect(session.activeSetId, isNull);
      expect(session.setTimer.runningSegmentStartedAt, isNull);
      expect(session.phase, WorkoutPhase.active);
      expect(
        session.timer.read(t.add(const Duration(seconds: 20))).seconds,
        20,
      );

      session = WorkoutMachine.transition(
        session,
        const StartSet('s2'),
        t.add(const Duration(seconds: 20)),
      );
      session = WorkoutMachine.transition(
        session,
        const SkipSet('s2'),
        t.add(const Duration(seconds: 30)),
      );

      expect(_set(session, 's2').setDurationSeconds, 10);
      expect(session.activeSetId, isNull);
      expect(session.phase, WorkoutPhase.completedPaused);
      expect(session.timer.read(t.add(const Duration(minutes: 5))).seconds, 30);
    });

    test(
        'skipping the active exercise preserves completed sets and can continue',
        () {
      final extraExercise = WorkoutExercise(
        id: 'e2',
        exerciseId: 'row',
        nameSnapshot: 'Row',
        categorySnapshot: ExerciseCategory.back,
        equipmentSnapshot: ExerciseEquipment.cable,
        unitSnapshot: WeightUnit.kg,
        note: '',
        targetRestSeconds: 90,
        order: 1,
        temporary: true,
        sets: [temporarySet('s3')],
      );
      final base = twoSetDraft();
      final draft = WorkoutDraft(
        workoutDate: base.workoutDate,
        exercises: [...base.exercises, extraExercise],
      );
      var session = WorkoutMachine.start(id: 'w1', draft: draft, nowUtc: t);
      session = WorkoutMachine.transition(session, const StartSet('s1'), t);
      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 22.5, actualReps: 7),
        t.add(const Duration(seconds: 10)),
      );
      session = WorkoutMachine.transition(
        session,
        const StartSet('s2'),
        t.add(const Duration(seconds: 20)),
      );

      session = WorkoutMachine.transition(
        session,
        const SkipExercise('e1'),
        t.add(const Duration(seconds: 35)),
      );

      expect(_set(session, 's1').status, SetStatus.completed);
      expect(_set(session, 's1').actualWeight, 22.5);
      expect(_set(session, 's1').actualReps, 7);
      expect(_set(session, 's2').status, SetStatus.skipped);
      expect(_set(session, 's2').setDurationSeconds, 15);
      expect(_set(session, 's3').status, SetStatus.pending);
      expect(session.activeSetId, isNull);
      expect(session.phase, WorkoutPhase.active);

      session = WorkoutMachine.transition(
        session,
        const StartSet('s3'),
        t.add(const Duration(seconds: 40)),
      );
      expect(session.activeSetId, 's3');
      expect(
        session.timer.read(t.add(const Duration(seconds: 45))).seconds,
        45,
      );
    });
  });

  group('completed-paused timing', () {
    test('editing after last set remains paused until a new set starts', () {
      var session = WorkoutMachine.start(
        id: 'w1',
        draft: oneSetDraft(),
        nowUtc: t,
      );
      session = WorkoutMachine.transition(session, const StartSet('s1'), t);
      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 30)),
      );
      expect(session.phase, WorkoutPhase.completedPaused);
      session = WorkoutMachine.transition(
        session,
        AddSet('e1', temporarySet('s2')),
        t.add(const Duration(minutes: 5)),
      );
      expect(
        session.timer.read(t.add(const Duration(minutes: 6))).seconds,
        30,
      );
      session = WorkoutMachine.transition(
        session,
        const StartSet('s2'),
        t.add(const Duration(minutes: 7)),
      );
      expect(
        session.timer
            .read(t.add(const Duration(minutes: 7, seconds: 10)))
            .seconds,
        40,
      );
    });

    test('last completion does not create a redundant rest', () {
      var session = WorkoutMachine.start(
        id: 'w1',
        draft: oneSetDraft(),
        nowUtc: t,
      );
      session = WorkoutMachine.transition(session, const StartSet('s1'), t);

      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 30)),
      );

      expect(session.phase, WorkoutPhase.completedPaused);
      expect(session.restStartedAt, isNull);
      expect(session.restTargetSeconds, isNull);
    });
  });

  group('finish checkpoint', () {
    test('continuing restores an in-progress set and excludes summary time',
        () {
      var session = _startedTwoSetSession(t);
      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 30)),
      );
      session = WorkoutMachine.transition(
        session,
        const StartSet('s2'),
        t.add(const Duration(seconds: 40)),
      );
      session = WorkoutMachine.transition(
        session,
        const PrepareFinish(),
        t.add(const Duration(seconds: 50)),
      );
      expect(session.phase, WorkoutPhase.finishing);
      expect(_set(session, 's2').status, SetStatus.skipped);
      expect(session.timer.read(t.add(const Duration(minutes: 4))).seconds, 50);

      final rebuilt = _rebuild(session);
      session = WorkoutMachine.transition(
        rebuilt,
        const ContinueWorkout(),
        t.add(const Duration(minutes: 5)),
      );

      expect(session.phase, WorkoutPhase.active);
      expect(session.activeSetId, 's2');
      expect(_set(session, 's2').status, SetStatus.inProgress);
      expect(_set(session, 's2').startedAt, t.add(const Duration(seconds: 40)));
      expect(
        session.timer
            .read(t.add(const Duration(minutes: 5, seconds: 10)))
            .seconds,
        60,
      );
      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s2', actualWeight: 20, actualReps: 8),
        t.add(const Duration(minutes: 5, seconds: 10)),
      );
      expect(_set(session, 's2').setDurationSeconds, 20);
    });

    test('continuing restores rest and keeps it for the next actual set', () {
      var session = _startedTwoSetSession(t);
      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 30)),
      );
      session = WorkoutMachine.transition(
        session,
        const PrepareFinish(),
        t.add(const Duration(seconds: 50)),
      );

      session = WorkoutMachine.transition(
        _rebuild(session),
        const ContinueWorkout(),
        t.add(const Duration(minutes: 5)),
      );
      session = WorkoutMachine.transition(
        session,
        const StartSet('s2'),
        t.add(const Duration(minutes: 5, seconds: 10)),
      );

      expect(_set(session, 's2').preSetRestSeconds, 30);
      expect(
        session.timer.read(t.add(const Duration(minutes: 6))).seconds,
        110,
      );
    });

    test('prepare finish preserves completed values and skips unfinished work',
        () {
      var session = _startedTwoSetSession(t);
      session = WorkoutMachine.transition(
        session,
        const CompleteSet('s1', actualWeight: 22.5, actualReps: 7),
        t.add(const Duration(seconds: 30)),
      );

      session = WorkoutMachine.transition(
        session,
        const PrepareFinish(),
        t.add(const Duration(seconds: 40)),
      );

      expect(_set(session, 's1').status, SetStatus.completed);
      expect(_set(session, 's1').actualWeight, 22.5);
      expect(_set(session, 's1').actualReps, 7);
      expect(_set(session, 's2').status, SetStatus.skipped);
      expect(session.finishCheckpoint, isNotNull);
    });

    test('finishing requires a completed set and saving clears checkpoint', () {
      final empty = WorkoutMachine.start(
        id: 'empty',
        draft: oneSetDraft(),
        nowUtc: t,
      );
      expect(
        () => WorkoutMachine.transition(
          empty,
          const PrepareFinish(),
          t,
        ),
        throwsStateError,
      );

      var completed = WorkoutMachine.start(
        id: 'done',
        draft: oneSetDraft(),
        nowUtc: t,
      );
      completed = WorkoutMachine.transition(completed, const StartSet('s1'), t);
      completed = WorkoutMachine.transition(
        completed,
        const CompleteSet('s1', actualWeight: 20, actualReps: 8),
        t.add(const Duration(seconds: 10)),
      );
      completed = WorkoutMachine.transition(
        completed,
        const PrepareFinish(),
        t.add(const Duration(seconds: 20)),
      );

      completed = WorkoutMachine.transition(
        completed,
        const SaveWorkout(note: 'Good session'),
        t.add(const Duration(seconds: 25)),
      );

      expect(completed.phase, WorkoutPhase.saved);
      expect(completed.note, 'Good session');
      expect(completed.endedAt, t.add(const Duration(seconds: 25)));
      expect(completed.finishCheckpoint, isNull);
    });
  });

  group('time anomalies', () {
    test('rollback enters anomaly and confirmation discards invalid time', () {
      var session = WorkoutMachine.start(
        id: 'w1',
        draft: oneSetDraft(),
        nowUtc: t,
      );
      session = WorkoutMachine.transition(session, const StartSet('s1'), t);
      session = WorkoutMachine.transition(
        session,
        const SelectSet('s1'),
        t.subtract(const Duration(seconds: 1)),
      );

      expect(session.phase, WorkoutPhase.timeAnomaly);
      expect(session.anomaly?.reason, TimerAnomalyReason.clockRollback);
      expect(session.timer.accumulatedActiveSeconds, 0);

      session = WorkoutMachine.transition(
        session,
        ConfirmTime(nowUtc: t.add(const Duration(minutes: 1))),
        t.add(const Duration(minutes: 1)),
      );

      expect(session.phase, WorkoutPhase.active);
      expect(
        session.timer
            .read(t.add(const Duration(minutes: 1, seconds: 5)))
            .seconds,
        5,
      );
    });

    test('exactly 24 hours remains valid but 25 hours enters anomaly', () {
      var valid = WorkoutMachine.start(
        id: 'valid',
        draft: oneSetDraft(),
        nowUtc: t,
      );
      valid = WorkoutMachine.transition(
        valid,
        const SelectSet('s1'),
        t.add(const Duration(hours: 24)),
      );
      expect(valid.phase, WorkoutPhase.active);

      var invalid = WorkoutMachine.start(
        id: 'invalid',
        draft: oneSetDraft(),
        nowUtc: t,
      );
      invalid = WorkoutMachine.transition(
        invalid,
        const SelectSet('s1'),
        t.add(const Duration(hours: 25)),
      );
      expect(invalid.phase, WorkoutPhase.timeAnomaly);
      expect(invalid.anomaly?.reason, TimerAnomalyReason.segmentTooLong);
      expect(invalid.timer.accumulatedActiveSeconds, 0);
    });
  });

  test('draft and session own immutable snapshot lists', () {
    final sourceSets = [temporarySet('s1', order: 0)];
    final sourceExercises = [
      WorkoutExercise(
        id: 'e1',
        exerciseId: 'row',
        nameSnapshot: 'Original row',
        categorySnapshot: ExerciseCategory.back,
        equipmentSnapshot: ExerciseEquipment.cable,
        unitSnapshot: WeightUnit.kg,
        sourceRevisionId: 'revision-7',
        note: '',
        targetRestSeconds: 90,
        order: 0,
        temporary: false,
        sets: sourceSets,
      ),
    ];
    final draft = WorkoutDraft(
      workoutDate: twoSetDraft().workoutDate,
      exercises: sourceExercises,
    );

    sourceSets.add(temporarySet('s2'));
    sourceExercises.clear();
    final session = WorkoutMachine.start(id: 'w1', draft: draft, nowUtc: t);

    expect(session.exercises.single.nameSnapshot, 'Original row');
    expect(session.exercises.single.sourceRevisionId, 'revision-7');
    expect(session.exercises.single.sets.map((set) => set.id), ['s1']);
    expect(() => session.exercises.clear(), throwsUnsupportedError);
  });
}

WorkoutSession _startedTwoSetSession(DateTime t) {
  var session = WorkoutMachine.start(
    id: 'w1',
    draft: twoSetDraft(),
    nowUtc: t,
  );
  session = WorkoutMachine.transition(session, const StartSet('s1'), t);
  return session;
}

WorkoutSet _set(WorkoutSession session, String id) => session.exercises
    .expand((exercise) => exercise.sets)
    .singleWhere((set) => set.id == id);

WorkoutSession _rebuild(WorkoutSession session) => WorkoutSession(
      id: session.id,
      workoutDate: session.workoutDate,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      phase: session.phase,
      exercises: session.exercises,
      timer: session.timer,
      setTimer: session.setTimer,
      restTimer: session.restTimer,
      activeSetId: session.activeSetId,
      selectedSetId: session.selectedSetId,
      restStartedAt: session.restStartedAt,
      restTargetSeconds: session.restTargetSeconds,
      note: session.note,
      revision: session.revision,
      anomaly: session.anomaly,
      finishCheckpoint: session.finishCheckpoint,
    );
