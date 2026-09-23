import 'package:fitness_counter/app/router.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/history/data/sqlite_history_repository.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan.dart';
import 'package:fitness_counter/features/plans/domain/plan_revision.dart';
import 'package:fitness_counter/features/today/application/today_providers.dart';
import 'package:fitness_counter/features/workout/application/pre_workout_providers.dart';
import 'package:fitness_counter/features/workout/application/workout_providers.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_draft.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/integration_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'empty SQLite completes two same-day workouts through the real UI',
    (tester) async {
      final clock = IntegrationTestClock(DateTime.utc(2026, 9, 18, 2));
      final app = await launchIntegrationApp(
        tester,
        initialLocation: AppRoutes.exerciseCreate,
        clock: clock,
      );
      addTearDown(() => app.close(tester));

      final press = await createExerciseThroughUi(
        tester,
        app,
        name: 'Task 14 卧推',
        category: ExerciseCategory.chest,
        equipment: ExerciseEquipment.dumbbell,
        unit: WeightUnit.kg,
      );
      final row = await createExerciseThroughUi(
        tester,
        app,
        name: 'Task 14 划船',
        category: ExerciseCategory.back,
        equipment: ExerciseEquipment.cable,
        unit: WeightUnit.kg,
      );
      final squat = await createExerciseThroughUi(
        tester,
        app,
        name: 'Task 14 深蹲',
        category: ExerciseCategory.legs,
        equipment: ExerciseEquipment.barbell,
        unit: WeightUnit.kg,
      );

      final planA = await _createPlanThroughUi(
        tester,
        app,
        name: 'Task 14 计划 A',
        cycleLength: 2,
        mode: PlanMode.infinite,
        startDay: 17,
      );
      await _configurePlanDaysThroughUi(
        tester,
        app,
        plan: planA,
        trainingDay: 1,
        restDay: 2,
        exercises: [press],
      );
      final planB = await _createPlanThroughUi(
        tester,
        app,
        name: 'Task 14 计划 B',
        cycleLength: 2,
        mode: PlanMode.cycles,
        startDay: 17,
      );
      await _configurePlanDaysThroughUi(
        tester,
        app,
        plan: planB,
        trainingDay: 2,
        restDay: 1,
        exercises: [row],
      );

      app.router.go(AppRoutes.editPlan(planA.id));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('create-plan-screen')),
      );
      await tester.enterText(find.byKey(const Key('plan-cycle-length')), '3');
      await tester.tap(find.byKey(const Key('plan-effective-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-save')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const Key('plan-screen')),
      );
      final planRepository = SqlitePlanRepository(app.database);
      final revisions = await planRepository.revisions(planA.id);
      final effectiveRevision = revisions.last;
      final planBRevision = (await planRepository.revisions(planB.id)).last;
      expect(effectiveRevision.effectiveFrom, LocalDate(2026, 9, 18));
      expect(effectiveRevision.cycleAnchorDate, LocalDate(2026, 9, 18));
      expect(effectiveRevision.cycleDays, 3);
      expect(effectiveRevision.days.first.dayNumber, 1);

      app.container.invalidate(todayOverviewProvider);
      app.router.go(AppRoutes.home);
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('today-primary-action')),
      );
      final today = await app.container.read(todayOverviewProvider.future);
      expect(today.isAllRest, isFalse);
      expect(today.mergedExercises, hasLength(2));
      expect(
        today.mergedExercises.map((item) => item.source.plan.id).toSet(),
        {planA.id, planB.id},
      );

      var session = await startPlannedWorkoutThroughUi(
        tester,
        app,
        temporaryExerciseId: squat.id,
        sourceRevisionIds: {effectiveRevision.id, planBRevision.id},
      );
      expect(session.exercises, hasLength(2));
      expect(session.exercises.first.exerciseId, row.id);
      expect(session.exercises.last.exerciseId, press.id);
      expect(session.exercises.last.sets, hasLength(1));
      expect(session.exercises.last.sets.single.plannedWeight, 42.5);
      expect(session.exercises.last.sets.single.plannedReps, 8);
      expect(
        session.exercises.every((item) => item.temporary == false),
        isTrue,
      );
      expect(
        session.exercises.map((item) => item.sourcePlanId).toSet(),
        {planA.id, planB.id},
      );
      expect(
        session.exercises.map((item) => item.sourceRevisionId).toSet(),
        {effectiveRevision.id, planBRevision.id},
      );
      final unchangedTemplate =
          (await planRepository.revisions(planA.id)).last.days.first;
      expect(unchangedTemplate.exercises, hasLength(1));
      expect(
        unchangedTemplate.exercises.every((item) => item.sets.length == 1),
        isTrue,
      );

      session = await completeOneSetThroughUi(tester, app);
      expect(session.phase, WorkoutPhase.resting);
      clock.advance(const Duration(seconds: 35));
      await tester.tap(find.byKey(const ValueKey('start-next-set')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('end-workout')),
      );
      await tester.tap(find.byKey(const ValueKey('primary-set-action')));
      await settleIntegrationApp(tester);
      session = app.container.read(workoutControllerProvider).session!;
      expect(session.phase, WorkoutPhase.completedPaused);
      expect(
        session.exercises.last.sets.single.preSetRestSeconds,
        greaterThanOrEqualTo(35),
      );

      final frozen = session.timer.read(clock.nowUtc()).seconds;
      clock.advance(const Duration(minutes: 2));
      expect(session.timer.read(clock.nowUtc()).seconds, frozen);

      await tester.tap(find.byKey(const ValueKey('add-training')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('add-exercise')),
      );
      await tester.tap(find.byKey(const ValueKey('add-exercise')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(ValueKey('picker-exercise-${squat.id}')),
      );
      await tester.tap(find.byKey(ValueKey('picker-exercise-${squat.id}')));
      await settleIntegrationApp(tester);
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();

      session = app.container.read(workoutControllerProvider).session!;
      expect(session.phase, WorkoutPhase.completedPaused);
      final temporarySet = session.exercises.last.sets.single;
      await tester.ensureVisible(
        find.byKey(ValueKey('set-row-${temporarySet.id}')),
      );
      await tester.tap(find.byKey(ValueKey('set-row-${temporarySet.id}')));
      await settleIntegrationApp(tester);
      await tester.tap(find.byKey(const ValueKey('add-training')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('add-set')),
      );
      await tester.tap(find.byKey(const ValueKey('add-set')));
      await settleIntegrationApp(tester);
      expect(
        app.container
            .read(workoutControllerProvider)
            .session!
            .timer
            .read(clock.nowUtc())
            .seconds,
        frozen,
      );

      await tester.tap(find.byKey(const ValueKey('primary-set-action')));
      await settleIntegrationApp(tester);
      clock.advance(const Duration(seconds: 12));
      await tester.tap(find.byKey(const ValueKey('primary-set-action')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('end-rest-workout')),
      );
      session = app.container.read(workoutControllerProvider).session!;
      expect(session.timer.read(clock.nowUtc()).seconds, greaterThan(frozen));

      await tester.tap(find.byKey(const ValueKey('end-rest-workout')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('end-and-save')),
      );
      await tester.tap(find.byKey(const ValueKey('end-and-save')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('summary-screen')),
      );
      final first = await saveWorkoutThroughUi(
        tester,
        app,
        note: 'Task 14 第一场',
      );
      expect(first.phase, WorkoutPhase.saved);
      expect(first.exercises.last.sets.last.status, SetStatus.skipped);

      final secondStarted = await startFreeWorkoutViaUi(
        tester,
        app,
        exerciseIds: [press.id],
      );
      final second = await completeOneSetThroughUi(tester, app);
      expect(second.id, secondStarted.id);
      final secondSaved = await saveWorkoutThroughUi(
        tester,
        app,
        note: 'Task 14 第二场',
      );
      expect(secondSaved.id, isNot(first.id));

      final history = SqliteHistoryRepository(app.database);
      expect(
        await history.day(LocalDate(2026, 9, 18)),
        hasLength(2),
      );
      expect(
        (await history.stats(
          LocalDate(2026, 9, 18),
          weekStart: DateTime.monday,
        ))
            .total,
        1,
      );
      expect(
        await SqliteWorkoutRepository(app.database).findUnfinished(),
        isNull,
      );
    },
  );
}

Future<Exercise> createExerciseThroughUi(
  WidgetTester tester,
  IntegrationApp app, {
  required String name,
  required ExerciseCategory category,
  required ExerciseEquipment equipment,
  required WeightUnit unit,
}) =>
    createExerciseViaUi(
      tester,
      app,
      name: name,
      category: category,
      equipment: equipment,
      unit: unit,
    );

Future<WorkoutSession> startPlannedWorkoutThroughUi(
  WidgetTester tester,
  IntegrationApp app, {
  required String temporaryExerciseId,
  required Set<String> sourceRevisionIds,
}) async {
  app.router.go(AppRoutes.home);
  await settleIntegrationApp(
    tester,
    until: find.byKey(const ValueKey('today-primary-action')),
  );
  await tester.tap(find.byKey(const ValueKey('today-primary-action')));
  await settleIntegrationApp(
    tester,
    until: find.byKey(const ValueKey('pre-workout-screen')),
  );
  expect(app.router.state.uri.queryParameters['free'], 'false');
  await tester.ensureVisible(find.text(AppStrings.addTemporaryExercise));
  await tester.tap(find.text(AppStrings.addTemporaryExercise));
  await settleIntegrationApp(
    tester,
    until: find.byKey(ValueKey('picker-exercise-$temporaryExerciseId')),
  );
  await tester.tap(
    find.byKey(ValueKey('picker-exercise-$temporaryExerciseId')),
  );
  await settleIntegrationApp(tester);

  final date = app.clock!.today();
  final request = (date: date.iso8601, freeWorkout: false);
  var draft = app.container.read(preWorkoutControllerProvider(request))!;
  expect(draft.exercises, hasLength(3));
  expect(
    draft.exercises.take(2).every(
          (item) => sourceRevisionIds.contains(item.sourceRevisionId),
        ),
    isTrue,
  );
  final firstExercise = draft.exercises.first;
  await tester.ensureVisible(find.text(AppStrings.addSet).first);
  await tester.tap(find.text(AppStrings.addSet).first);
  await settleIntegrationApp(tester);
  draft = app.container.read(preWorkoutControllerProvider(request))!;
  final firstSet = draft.exercises.first.sets.first;
  await tester.enterText(
    find.byKey(ValueKey('set-weight-${firstSet.id}')),
    '42.5',
  );
  await tester.enterText(
    find.byKey(ValueKey('set-reps-${firstSet.id}')),
    '8',
  );
  await tester.tap(find.byTooltip(AppStrings.moveSetDown).first);
  await settleIntegrationApp(tester);
  await tester.tap(find.byTooltip(AppStrings.removeSetAction).first);
  await settleIntegrationApp(tester);
  expect(
    app.container
        .read(preWorkoutControllerProvider(request))!
        .exercises
        .first
        .sets,
    hasLength(1),
  );

  await tester.ensureVisible(find.byTooltip(AppStrings.moveExerciseUp).at(1));
  await tester.tap(find.byTooltip(AppStrings.moveExerciseUp).at(1));
  await settleIntegrationApp(tester);
  await tester
      .ensureVisible(find.byTooltip(AppStrings.removeExerciseAction).last);
  await tester.tap(find.byTooltip(AppStrings.removeExerciseAction).last);
  await settleIntegrationApp(tester);
  expect(
    app.container.read(preWorkoutControllerProvider(request))!.exercises,
    hasLength(2),
  );
  expect(sourceRevisionIds, contains(firstExercise.sourceRevisionId));

  await tester.ensureVisible(find.byKey(const ValueKey('start-workout')));
  await tester.tap(find.byKey(const ValueKey('start-workout')));
  await settleIntegrationApp(
    tester,
    until: find.byKey(const ValueKey('end-workout')),
  );
  return (await SqliteWorkoutRepository(app.database).findUnfinished())!;
}

Future<Plan> _createPlanThroughUi(
  WidgetTester tester,
  IntegrationApp app, {
  required String name,
  required int cycleLength,
  required PlanMode mode,
  int? startDay,
}) async {
  app.router.go(AppRoutes.createPlan);
  await settleIntegrationApp(
    tester,
    until: find.byKey(const ValueKey('create-plan-screen')),
  );
  await tester.enterText(find.byKey(const Key('plan-name')), name);
  await tester.enterText(
    find.byKey(const Key('plan-cycle-length')),
    '$cycleLength',
  );
  await tester.tap(find.byKey(ValueKey('plan-mode-${mode.name}')));
  await settleIntegrationApp(tester);
  if (mode == PlanMode.cycles) {
    await tester.enterText(find.byKey(const Key('plan-loop-count')), '2');
  }
  if (startDay != null) {
    await tester.tap(find.byKey(const Key('plan-effective-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$startDay').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('plan-primary-save')));
  await settleIntegrationApp(
    tester,
    until: find.byKey(const Key('plan-screen')),
  );
  return (await SqlitePlanRepository(app.database).list())
      .singleWhere((plan) => plan.name == name);
}

Future<void> _configurePlanDaysThroughUi(
  WidgetTester tester,
  IntegrationApp app, {
  required Plan plan,
  required int trainingDay,
  required int restDay,
  required List<Exercise> exercises,
}) async {
  app.router.go(AppRoutes.planEdit(plan.id));
  await settleIntegrationApp(
    tester,
    until: find.byKey(const ValueKey('plan-edit-screen')),
  );
  await tester.tap(find.byKey(ValueKey('day-tab-$trainingDay')));
  await tester.pumpAndSettle();
  for (final exercise in exercises) {
    await tester.tap(find.byKey(const Key('day-add-exercise')));
    await settleIntegrationApp(
      tester,
      until: find.byKey(ValueKey('picker-exercise-${exercise.id}')),
    );
    await tester.tap(find.byKey(ValueKey('picker-exercise-${exercise.id}')));
    await settleIntegrationApp(tester);
    await tester.tap(find.text(exercise.name).last);
    await settleIntegrationApp(
      tester,
      until: find.byKey(const Key('plan-batch-sets')),
    );
    await tester.tap(find.byKey(const Key('plan-batch-sets')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('set-count')), '1');
    await tester.enterText(find.byKey(const Key('set-weight')), '50');
    await tester.enterText(find.byKey(const Key('set-reps')), '8');
    await tester.tap(find.byKey(const Key('set-save')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text(exercise.name).last)).pop();
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(ValueKey('day-tab-$restDay')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('day-rest')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('plan-save')));
  await settleIntegrationApp(
    tester,
    until: find.byKey(const Key('plan-screen')),
  );
}

Future<WorkoutSession> completeOneSetThroughUi(
  WidgetTester tester,
  IntegrationApp app,
) =>
    completeCurrentSetViaUi(tester, app);

Future<WorkoutSession> saveWorkoutThroughUi(
  WidgetTester tester,
  IntegrationApp app, {
  required String note,
}) =>
    saveWorkoutViaUi(tester, app, note: note);
