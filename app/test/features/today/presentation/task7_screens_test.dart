import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/data/app_database.dart';
import 'package:fitness_counter/core/domain/clock.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan.dart';
import 'package:fitness_counter/features/plans/domain/plan_day.dart';
import 'package:fitness_counter/features/plans/domain/plan_revision.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/pump_app.dart';
import '../../../support/test_database.dart';

void main() {
  final date = LocalDate(2026, 9, 15);

  testWidgets('planned Home presents source day title summary and set metadata',
      (tester) async {
    final db = (await tester.runAsync(() => _plannedDatabase(date)))!;
    addTearDown(db.close);
    await _pumpPlannedApp(tester, db, date);

    expect(find.text('三日训练计划 · D1'), findsOneWidget);
    expect(find.text('D1'), findsOneWidget);
    expect(find.text('1 个动作 · 1 组'), findsOneWidget);
    expect(find.text('1 组 · 20 kg'), findsOneWidget);
  });

  testWidgets('merged Home labels each exercise with its actual source',
      (tester) async {
    final db = (await tester.runAsync(() => _mergedDatabase(date)))!;
    addTearDown(db.close);
    await _pumpPlannedApp(tester, db, date);

    expect(find.text('2 个计划合并'), findsOneWidget);
    expect(find.text('今日合并训练'), findsOneWidget);
    expect(find.text('计划：上肢计划 · 版本 upper-r · D1 上肢'), findsOneWidget);
    expect(find.text('计划：核心计划 · 版本 core-r · D1 核心'), findsOneWidget);
  });

  testWidgets('unfinished workout recovery is an actionable durable route',
      (tester) async {
    final activeDb = (await tester.runAsync(() => _activeDatabase(date)))!;
    addTearDown(activeDb.close);
    final router = await _pumpUntil(
      tester,
      activeDb,
      date,
      find.text(AppStrings.resumeWorkout),
    );
    await tester.tap(find.text(AppStrings.resumeWorkout));
    await _waitFor(tester, find.byKey(const ValueKey('end-workout')));
    expect(router.routeInformationProvider.value.uri.path, '/workout/w1');
  });

  testWidgets('formal start renders as a reachable durable action',
      (tester) async {
    final plannedDb = (await tester.runAsync(() => _plannedDatabase(date)))!;
    addTearDown(plannedDb.close);
    await _pumpPlannedApp(tester, plannedDb, date);
    await tester.tap(find.text(AppStrings.startTodayWorkout));
    await _waitFor(tester, find.text(AppStrings.startTimer));
    final start = find.byKey(const ValueKey('start-workout'));
    expect(start, findsOneWidget);
    expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
    expect(
      find.ancestor(
        of: find.text(AppStrings.startTimer),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home preparation has an explicit back action to Home',
      (tester) async {
    final plannedDb = (await tester.runAsync(() => _plannedDatabase(date)))!;
    addTearDown(plannedDb.close);
    await _pumpPlannedApp(tester, plannedDb, date);

    await tester.tap(find.text(AppStrings.startTodayWorkout));
    await _waitFor(tester, find.byKey(const ValueKey('pre-workout-back')));
    await _waitFor(tester, find.text(AppStrings.addTemporaryExercise));
    final back = find.byKey(const ValueKey('pre-workout-back'));
    expect(tester.getSize(back).shortestSide, greaterThanOrEqualTo(48));

    await tester.tap(back);
    await _waitFor(tester, find.byKey(const ValueKey('home-screen')));
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
  });

  test('every recovery phase uses centralized Chinese copy', () {
    for (final entry in AppStrings.workoutPhaseLabels.entries) {
      expect(AppStrings.workoutPhaseLabel(entry.key), entry.value);
      expect(entry.value, isNot(entry.key));
    }
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('full Task 7 screens fit $width at $scale text scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final db = (await tester.runAsync(() => _plannedDatabase(date)))!;
        addTearDown(db.close);
        await _pumpPlannedApp(tester, db, date);

        expect(tester.takeException(), isNull);
        await _expectMinimumButtonHeight<OutlinedButton>(tester, 48);
        await tester.tap(find.text(AppStrings.startTodayWorkout));
        await _waitFor(tester, find.text(AppStrings.addTemporaryExercise));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        await _expectMinimumButtonHeight<OutlinedButton>(tester, 48);
        await _expectMinimumButtonHeight<TextButton>(tester, 48);
        final start = find.byKey(const ValueKey('start-workout'));
        await tester.ensureVisible(start);
        expect(tester.getSize(start).height, 50);
        final bounds = tester.getRect(start);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(width));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(844));
      });
    }
  }
}

Future<AppDatabase> _plannedDatabase(LocalDate date) async {
  final db = await openTestDatabase();
  await SqliteExerciseRepository(db).save(catalogExercise());
  await SqlitePlanRepository(db)
      .save(catalogPlan(), catalogRevision(effectiveFrom: date));
  return db;
}

Future<AppDatabase> _activeDatabase(LocalDate date) async {
  final db = await openTestDatabase();
  await SqliteWorkoutRepository(db).create(newSession(date: date));
  return db;
}

Future<AppDatabase> _mergedDatabase(LocalDate date) async {
  final db = await openTestDatabase();
  final exercises = SqliteExerciseRepository(db);
  final plans = SqlitePlanRepository(db);
  await exercises.save(catalogExercise(id: 'upper-x', name: '卧推'));
  await exercises.save(catalogExercise(id: 'core-x', name: '卷腹'));
  await plans.save(
    _plan('upper', '上肢计划', priority: 2, order: 0),
    _revision('upper-r', 'upper', '上肢', 'upper-x', '卧推', date),
  );
  await plans.save(
    _plan('core', '核心计划', priority: 1, order: 1),
    _revision('core-r', 'core', '核心', 'core-x', '卷腹', date),
  );
  return db;
}

Plan _plan(
  String id,
  String name, {
  required int priority,
  required int order,
}) =>
    Plan(
      id: id,
      name: name,
      enabled: true,
      priority: priority,
      defaultOrder: order,
      createdAt: DateTime.utc(2026, 9),
      updatedAt: DateTime.utc(2026, 9),
    );

PlanRevision _revision(
  String id,
  String planId,
  String dayName,
  String exerciseId,
  String exerciseName,
  LocalDate date,
) =>
    PlanRevision(
      id: id,
      planId: planId,
      effectiveFrom: date,
      cycleAnchorDate: date,
      cycleDays: 1,
      mode: PlanMode.infinite,
      days: [
        PlanDay(
          id: '$id-day',
          dayNumber: 1,
          name: dayName,
          isRest: false,
          exercises: [
            PlanExercise(
              id: '$id-exercise',
              exerciseId: exerciseId,
              nameSnapshot: exerciseName,
              note: '',
              targetRestSeconds: 60,
              order: 0,
              sets: [
                PlanSet(
                  id: '$id-set',
                  order: 0,
                  plannedWeight: 20,
                  unit: WeightUnit.kg,
                  plannedReps: 8,
                ),
              ],
            ),
          ],
        ),
      ],
    );

Future<void> _pumpPlannedApp(
  WidgetTester tester,
  AppDatabase db,
  LocalDate date,
) async {
  await pumpFitnessApp(
    tester,
    database: db,
    overrides: [
      themeDefinitionsProvider.overrideWith(
        (ref) async => [breathRhythmDefinition],
      ),
      clockProvider.overrideWith((ref) => _FixedClock(date)),
    ],
  );
  await _waitFor(tester, find.text(AppStrings.startTodayWorkout));
}

Future<GoRouter> _pumpUntil(
  WidgetTester tester,
  AppDatabase db,
  LocalDate date,
  Finder finder,
) async {
  final router = await pumpFitnessApp(
    tester,
    database: db,
    overrides: [
      themeDefinitionsProvider.overrideWith(
        (ref) async => [breathRhythmDefinition],
      ),
      clockProvider.overrideWith((ref) => _FixedClock(date)),
    ],
  );
  await _waitFor(tester, finder);
  return router;
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(finder, findsWidgets);
}

Future<void> _expectMinimumButtonHeight<T extends Widget>(
  WidgetTester tester,
  double minimum,
) async {
  for (final element in find.byType(T).evaluate()) {
    await tester.ensureVisible(find.byWidget(element.widget));
    expect(
      tester.getSize(find.byWidget(element.widget)).height,
      greaterThanOrEqualTo(minimum),
    );
  }
}

final class _FixedClock implements Clock {
  const _FixedClock(this.date);
  final LocalDate date;
  @override
  Duration get monotonicElapsed => Duration.zero;
  @override
  DateTime nowUtc() => DateTime.utc(2026, 9, 15);
  @override
  LocalDate today() => date;
}
