import 'package:fitness_counter/app/router.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan.dart';
import 'package:fitness_counter/features/plans/domain/plan_revision.dart';
import 'package:fitness_counter/features/plans/domain/plan_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/integration_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'plan identity, modes, rest projection and effective revision survive restart',
    (tester) async {
      final clock = IntegrationTestClock(DateTime.utc(2026, 9, 18, 2));
      var app = await launchIntegrationApp(
        tester,
        initialLocation: AppRoutes.exerciseCreate,
        clock: clock,
      );
      addTearDown(() => app.close(tester));
      final exercise = await createExerciseViaUi(
        tester,
        app,
        name: 'Task 14 计划卧推',
        category: ExerciseCategory.chest,
        equipment: ExerciseEquipment.barbell,
      );

      final infinite = await _createPlanThroughUi(
        tester,
        app,
        name: 'Task 14 无限计划',
        cycleLength: 2,
        mode: PlanMode.infinite,
      );
      final cycles = await _createPlanThroughUi(
        tester,
        app,
        name: 'Task 14 次数计划',
        cycleLength: 3,
        mode: PlanMode.cycles,
      );
      expect(infinite.id, isNot(cycles.id));

      app.router.go(AppRoutes.planEdit(infinite.id));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('plan-edit-screen')),
      );
      await tester.tap(find.byKey(const Key('day-add-exercise')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(ValueKey('picker-exercise-${exercise.id}')),
      );
      await tester.tap(find.byKey(ValueKey('picker-exercise-${exercise.id}')));
      await settleIntegrationApp(tester);
      await tester.tap(find.text(exercise.name));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const Key('plan-batch-sets')),
      );
      await tester.tap(find.byKey(const Key('plan-batch-sets')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('set-count')), '2');
      await tester.enterText(find.byKey(const Key('set-weight')), '50');
      await tester.enterText(find.byKey(const Key('set-reps')), '8');
      await tester.tap(find.byKey(const Key('set-save')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text(exercise.name).last)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('day-rest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-save')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const Key('plan-screen')),
      );

      final repository = SqlitePlanRepository(app.database);
      final configured = (await repository.revisions(infinite.id)).last;
      expect(configured.days.first.exercises.single.sets, hasLength(2));
      expect(configured.days.last.isRest, isTrue);
      final oldProjection = PlanSchedule.dayFor(
        infinite,
        await repository.revisions(infinite.id),
        LocalDate(2026, 9, 18),
      );
      expect(oldProjection!.day.dayNumber, 1);

      app.router.go(AppRoutes.editPlan(infinite.id));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('create-plan-screen')),
      );
      await tester.enterText(find.byKey(const Key('plan-cycle-length')), '3');
      await tester.tap(find.byKey(const Key('plan-effective-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plan-save')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const Key('plan-screen')),
      );

      final revisions = await repository.revisions(infinite.id);
      expect(revisions.last.effectiveFrom, LocalDate(2026, 9, 20));
      expect(revisions.last.cycleAnchorDate, LocalDate(2026, 9, 20));
      expect(revisions.last.cycleDays, 3);
      expect(
        PlanSchedule.dayFor(
          infinite,
          revisions,
          LocalDate(2026, 9, 18),
        )!
            .revision
            .id,
        configured.id,
      );
      expect(
        PlanSchedule.dayFor(
          infinite,
          revisions,
          LocalDate(2026, 9, 20),
        )!
            .day
            .dayNumber,
        1,
      );

      final path = app.databasePath;
      app = await restartIntegrationApp(
        tester,
        app,
        initialLocation: AppRoutes.plan,
      );
      expect(app.databasePath, path);
      final reopened = SqlitePlanRepository(app.database);
      expect((await reopened.find(infinite.id))!.id, infinite.id);
      expect((await reopened.revisions(infinite.id)).last.cycleDays, 3);
      expect((await reopened.revisions(cycles.id)).last.mode, PlanMode.cycles);
    },
  );
}

Future<Plan> _createPlanThroughUi(
  WidgetTester tester,
  IntegrationApp app, {
  required String name,
  required int cycleLength,
  required PlanMode mode,
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
  if (mode == PlanMode.cycles) {
    await tester.enterText(find.byKey(const Key('plan-loop-count')), '2');
  }
  await tester.tap(find.byKey(const Key('plan-primary-save')));
  await settleIntegrationApp(
    tester,
    until: find.byKey(const Key('plan-screen')),
  );
  return (await SqlitePlanRepository(app.database).list())
      .singleWhere((plan) => plan.name == name);
}
