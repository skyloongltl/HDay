import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/history_test_support.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/pump_app.dart';
import '../../../support/test_database.dart';

void main() {
  setUpAll(loadHistoryFonts);
  testWidgets('detail edit action keeps a compact surface and full tap target',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(
      () =>
          SqliteExerciseRepository(db).save(catalogExercise(id: 'bench-press')),
    );
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/exercise-detail/bench-press',
    );

    final action = find.byKey(const ValueKey('exercise-edit-action'));
    final surface = find.byKey(const ValueKey('exercise-edit-action-surface'));

    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(surface).height, 28);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'exercise detail and unit-specific logs fit $width scale $scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final db = (await tester.runAsync(openTestDatabase))!;
        addTearDown(db.close);
        await tester.runAsync(
          () => SqliteExerciseRepository(db)
              .save(catalogExercise(id: 'bench-press', name: '杠铃卧推')),
        );
        final router = await pumpFitnessApp(
          tester,
          database: db,
          initialLocation: '/exercise-detail/bench-press',
        );
        expect(find.text(AppStrings.noExerciseHistory), findsOneWidget);
        await captureHistory(tester, 'exercise_empty_${width.toInt()}_$scale');
        await tester.runAsync(() async {
          await savePerformanceSession(
            db,
            id: 'kg1',
            start: DateTime.utc(2026, 9, 15, 1),
            weight: 35,
          );
          await savePerformanceSession(
            db,
            id: 'kg2',
            start: DateTime.utc(2026, 9, 15, 2),
            weight: 40,
          );
          await savePerformanceSession(
            db,
            id: 'lb',
            start: DateTime.utc(2026, 9, 15, 3),
            unit: WeightUnit.lb,
            weight: 80,
            reps: 10,
          );
        });
        router.go('/exercises');
        await settleHistory(tester);
        router.go('/exercise-detail/bench-press');
        await settleHistory(tester);
        expect(find.textContaining('40 kg'), findsWidgets);
        expect(find.textContaining('80 lb'), findsWidgets);
        expect(find.byKey(const Key('history-unit-lb')), findsNothing);
        await captureHistory(
          tester,
          'exercise_best_trend_logs_${width.toInt()}_$scale',
        );
        await captureHistory(tester, 'exercise_units_${width.toInt()}_$scale');
        await tester
            .runAsync(() => SqliteExerciseRepository(db).delete('bench-press'));
        router.go('/exercises');
        await settleHistory(tester);
        router.go('/exercise-detail/bench-press');
        await settleHistory(tester);
        expect(find.text(AppStrings.exerciseDeleted), findsOneWidget);
        expect(find.byKey(const Key('exercise-personal-best')), findsOneWidget);
        expect(find.text(AppStrings.edit), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('missing exercise deep link renders a true empty history',
      (tester) async {
    await pumpFitnessApp(tester, initialLocation: '/exercise-detail/missing');
    expect(find.text(AppStrings.exerciseDeleted), findsOneWidget);
    expect(find.text(AppStrings.noExerciseHistory), findsOneWidget);
    expect(find.byKey(const Key('exercise-personal-best')), findsNothing);
  });
  testWidgets('exercise detail displays committed best trend and logs',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(() async {
      await SqliteExerciseRepository(db)
          .save(catalogExercise(id: 'bench-press'));
      await persistCompleted(SqliteWorkoutRepository(db));
    });
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/exercise-detail/bench-press',
    );
    expect(find.byKey(const Key('exercise-personal-best')), findsOneWidget);
    expect(find.byKey(const Key('exercise-trend')), findsOneWidget);
    expect(find.textContaining('22.5'), findsWidgets);
    expect(
      find.text(AppStrings.exerciseCategoryLabels['chest']!),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.exerciseEquipmentLabels['dumbbell']!),
      findsOneWidget,
    );
    expect(find.text(AppStrings.weightUnitLabels['kg']!), findsOneWidget);
  });
}
