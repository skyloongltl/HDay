import 'package:fitness_counter/app/router.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/application/workout_providers.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/active_timer.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/integration_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'production composition restores active resting completedPaused and finishing',
    (tester) async {
      final clock = IntegrationTestClock(DateTime.utc(2026, 9, 18, 2));
      var app = await launchIntegrationApp(
        tester,
        initialLocation: AppRoutes.exerciseCreate,
        clock: clock,
      );
      addTearDown(() => app.close(tester));
      final first = await createExerciseViaUi(
        tester,
        app,
        name: 'Task 14 恢复卧推',
        category: ExerciseCategory.chest,
        equipment: ExerciseEquipment.dumbbell,
      );
      final second = await createExerciseViaUi(
        tester,
        app,
        name: 'Task 14 恢复划船',
        category: ExerciseCategory.back,
        equipment: ExerciseEquipment.cable,
      );
      final started = await startFreeWorkoutViaUi(
        tester,
        app,
        exerciseIds: [first.id, second.id],
      );
      await tester.tap(find.byKey(const ValueKey('primary-set-action')));
      await settleIntegrationApp(tester);
      clock.advance(const Duration(seconds: 20));
      var session = app.container.read(workoutControllerProvider).session!;
      final firstSetId = session.activeSetId!;

      app = await restartIntegrationApp(
        tester,
        app,
        initialLocation: AppRoutes.workout(started.id),
      );
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('end-workout')),
      );
      session = app.container.read(workoutControllerProvider).session!;
      expect(session.phase, WorkoutPhase.active);
      expect(session.activeSetId, firstSetId);
      expect(
        session.timer.read(clock.nowUtc()).seconds,
        greaterThanOrEqualTo(20),
      );

      await tester.tap(find.byKey(const ValueKey('primary-set-action')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('start-next-set')),
      );
      clock.advance(const Duration(seconds: 40));
      final resting = app.container.read(workoutControllerProvider).session!;
      final restIdentity =
          '${resting.id}${resting.restStartedAt!.toIso8601String()}';
      final selectedNext = resting.selectedSetId;

      app = await restartIntegrationApp(
        tester,
        app,
        initialLocation: AppRoutes.rest(started.id),
      );
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('start-next-set')),
      );
      session = app.container.read(workoutControllerProvider).session!;
      expect(session.phase, WorkoutPhase.resting);
      expect(session.selectedSetId, selectedNext);
      expect(
        '${session.id}${session.restStartedAt!.toIso8601String()}',
        restIdentity,
      );
      expect(
        session.restTimer.read(clock.nowUtc()).seconds,
        greaterThanOrEqualTo(40),
      );
      expect(session.activeSetId, isNull);

      await tester.tap(find.byKey(const ValueKey('start-next-set')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('end-workout')),
      );
      clock.advance(const Duration(seconds: 10));
      await tester.tap(find.byKey(const ValueKey('primary-set-action')));
      await settleIntegrationApp(tester);
      session = app.container.read(workoutControllerProvider).session!;
      expect(session.phase, WorkoutPhase.completedPaused);
      final frozen = session.timer.read(clock.nowUtc()).seconds;

      await tester.tap(find.byKey(const ValueKey('add-training')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('add-set')),
      );
      await tester.tap(find.byKey(const ValueKey('add-set')));
      await settleIntegrationApp(tester);
      session = app.container.read(workoutControllerProvider).session!;
      final added = session.exercises.last.sets.last;
      expect(session.phase, WorkoutPhase.completedPaused);
      clock.advance(const Duration(minutes: 3));

      app = await restartIntegrationApp(
        tester,
        app,
        initialLocation: AppRoutes.workout(started.id),
      );
      await settleIntegrationApp(
        tester,
        until: find.byKey(ValueKey('set-row-${added.id}')),
      );
      session = app.container.read(workoutControllerProvider).session!;
      expect(session.phase, WorkoutPhase.completedPaused);
      expect(session.timer.read(clock.nowUtc()).seconds, frozen);
      await tester.tap(find.byKey(ValueKey('set-row-${added.id}')));
      await settleIntegrationApp(tester);
      await tester.tap(find.byKey(const ValueKey('primary-set-action')));
      await settleIntegrationApp(tester);
      clock.advance(const Duration(seconds: 7));
      session = app.container.read(workoutControllerProvider).session!;
      expect(session.phase, WorkoutPhase.active);
      expect(session.timer.read(clock.nowUtc()).seconds, frozen + 7);

      await tester.tap(find.byKey(const ValueKey('end-workout')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('end-and-save')),
      );
      await tester.tap(find.byKey(const ValueKey('end-and-save')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('summary-screen')),
      );
      final finishing = app.container.read(workoutControllerProvider).session!;
      expect(finishing.phase, WorkoutPhase.finishing);
      expect(finishing.finishCheckpoint!.phase, WorkoutPhase.active);
      final checkpointSeconds =
          finishing.finishCheckpoint!.timer.accumulatedActiveSeconds;
      clock.advance(const Duration(minutes: 4));

      app = await restartIntegrationApp(
        tester,
        app,
        initialLocation: AppRoutes.summary(started.id),
      );
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('continue-workout')),
      );
      session = app.container.read(workoutControllerProvider).session!;
      expect(session.phase, WorkoutPhase.finishing);
      expect(
        session.finishCheckpoint!.timer.accumulatedActiveSeconds,
        checkpointSeconds,
      );
      await tester.tap(find.byKey(const ValueKey('continue-workout')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('end-workout')),
      );
      session = app.container.read(workoutControllerProvider).session!;
      expect(session.phase, WorkoutPhase.active);
      expect(
        session.timer.accumulatedActiveSeconds,
        checkpointSeconds,
      );

      await tester.tap(find.byKey(const ValueKey('end-workout')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('end-and-save')),
      );
      await tester.tap(find.byKey(const ValueKey('end-and-save')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('summary-screen')),
      );
      await saveWorkoutViaUi(tester, app, note: '恢复流程完成');
      expect(
        await SqliteWorkoutRepository(app.database).findUnfinished(),
        isNull,
      );
    },
  );

  testWidgets('injected clock exposes rollback and over-24-hour anomalies',
      (tester) async {
    final start = DateTime.utc(2026, 9, 18, 2);
    final clock = IntegrationTestClock(start);
    final app = await launchIntegrationApp(
      tester,
      initialLocation: AppRoutes.exerciseCreate,
      clock: clock,
    );
    addTearDown(() => app.close(tester));
    final exercise = await createExerciseViaUi(
      tester,
      app,
      name: 'Task 14 时钟动作',
    );
    await startFreeWorkoutViaUi(
      tester,
      app,
      exerciseIds: [exercise.id],
    );
    await tester.tap(find.byKey(const ValueKey('primary-set-action')));
    await settleIntegrationApp(tester);
    var session = app.container.read(workoutControllerProvider).session!;
    final setId = session.activeSetId!;

    clock.setUtc(start.subtract(const Duration(seconds: 1)));
    await tester.tap(find.byKey(ValueKey('set-row-$setId')));
    await settleIntegrationApp(
      tester,
      until: find.byKey(const ValueKey('time-anomaly')),
    );
    session = app.container.read(workoutControllerProvider).session!;
    expect(session.phase, WorkoutPhase.timeAnomaly);
    expect(session.anomaly!.reason, TimerAnomalyReason.clockRollback);

    clock.setUtc(start.add(const Duration(minutes: 1)));
    await tester.tap(find.byKey(const ValueKey('confirm-time')));
    await settleIntegrationApp(
      tester,
      until: find.byKey(const ValueKey('end-workout')),
    );
    clock.advance(ActiveTimer.maxSegmentDuration + const Duration(seconds: 1));
    await tester.tap(find.byKey(ValueKey('set-row-$setId')));
    await settleIntegrationApp(
      tester,
      until: find.byKey(const ValueKey('time-anomaly')),
    );
    session = app.container.read(workoutControllerProvider).session!;
    expect(session.anomaly!.reason, TimerAnomalyReason.segmentTooLong);
  });
}
