import 'package:fitness_counter/app/app.dart';
import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/app/router.dart';
import 'package:fitness_counter/core/data/app_database.dart';
import 'package:fitness_counter/core/domain/clock.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/application/workout_providers.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

final class IntegrationTestClock implements Clock {
  IntegrationTestClock(DateTime now) : _nowUtc = now.toUtc();

  DateTime _nowUtc;
  Duration _monotonicElapsed = Duration.zero;

  @override
  DateTime nowUtc() => _nowUtc;

  @override
  Duration get monotonicElapsed => _monotonicElapsed;

  @override
  LocalDate today() => LocalDate.fromDateTime(_nowUtc.toLocal());

  void advance(Duration duration) {
    _nowUtc = _nowUtc.add(duration);
    _monotonicElapsed += duration;
  }

  void setUtc(DateTime value) {
    _nowUtc = value.toUtc();
  }
}

final class IntegrationApp {
  IntegrationApp({
    required this.databasePath,
    required this.database,
    required this.container,
    required this.router,
    this.clock,
  });

  final String databasePath;
  final AppDatabase database;
  final ProviderContainer container;
  final GoRouter router;
  final IntegrationTestClock? clock;
  bool _closed = false;

  Future<void> close(WidgetTester tester) async {
    if (_closed) return;
    _closed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    router.dispose();
    await database.close();
  }
}

Future<IntegrationApp> launchIntegrationApp(
  WidgetTester tester, {
  String initialLocation = AppRoutes.home,
  String? databasePath,
  IntegrationTestClock? clock,
}) async {
  final path = databasePath ??
      paths.join(
        await getDatabasesPath(),
        'fitness_counter_task14_${DateTime.now().microsecondsSinceEpoch}.db',
      );
  final database = await AppDatabase.open(path: path);
  final router = createRouter()..go(initialLocation);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((_) async => database),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
  );
  await container.read(appDatabaseProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: FitnessCounterApp(router: router),
    ),
  );
  await settleIntegrationApp(tester);
  return IntegrationApp(
    databasePath: path,
    database: database,
    container: container,
    router: router,
    clock: clock,
  );
}

Future<IntegrationApp> restartIntegrationApp(
  WidgetTester tester,
  IntegrationApp previous, {
  required String initialLocation,
}) async {
  final path = previous.databasePath;
  final clock = previous.clock;
  await previous.close(tester);
  return launchIntegrationApp(
    tester,
    initialLocation: initialLocation,
    databasePath: path,
    clock: clock,
  );
}

Future<void> settleIntegrationApp(
  WidgetTester tester, {
  Finder? until,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final deadline = DateTime.now().add(timeout);
  do {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (until != null && until.evaluate().isNotEmpty) return;
  } while (DateTime.now().isBefore(deadline) &&
      (until != null ||
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty));
  if (until != null) expect(until, findsAtLeastNWidgets(1));
  await tester.pump();
}

Future<Exercise> createExerciseViaUi(
  WidgetTester tester,
  IntegrationApp app, {
  required String name,
  ExerciseCategory category = ExerciseCategory.chest,
  ExerciseEquipment equipment = ExerciseEquipment.dumbbell,
  WeightUnit unit = WeightUnit.kg,
  String note = '',
}) async {
  app.router.go(AppRoutes.exerciseCreate);
  await settleIntegrationApp(
    tester,
    until: find.byKey(const ValueKey('exercise-name')),
  );
  await tester.enterText(
    find.byKey(const ValueKey('exercise-name')),
    name,
  );
  await tester.tap(find.byKey(ValueKey('category-${category.code}')));
  await tester.tap(find.byKey(ValueKey('equipment-${equipment.code}')));
  await tester.tap(find.byKey(ValueKey('unit-${unit.code}')));
  if (note.isNotEmpty) {
    await tester.enterText(
      find.byKey(const ValueKey('exercise-notes')),
      note,
    );
  }
  await tester.ensureVisible(
    find.byKey(const ValueKey('exercise-primary-save')),
  );
  await tester.tap(find.byKey(const ValueKey('exercise-primary-save')));
  await settleIntegrationApp(
    tester,
    until: find.byKey(const ValueKey('exercises-screen')),
  );
  return (await SqliteExerciseRepository(app.database).search())
      .singleWhere((exercise) => exercise.name == name);
}

Future<WorkoutSession> startFreeWorkoutViaUi(
  WidgetTester tester,
  IntegrationApp app, {
  required List<String> exerciseIds,
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
  for (final exerciseId in exerciseIds) {
    await tester.ensureVisible(find.text(AppStrings.addExercise));
    await tester.tap(find.text(AppStrings.addExercise));
    await settleIntegrationApp(
      tester,
      until: find.byKey(ValueKey('picker-exercise-$exerciseId')),
    );
    await tester.tap(find.byKey(ValueKey('picker-exercise-$exerciseId')));
    await settleIntegrationApp(tester);
  }
  await tester.tap(find.byKey(const ValueKey('start-workout')));
  await settleIntegrationApp(
    tester,
    until: find.byKey(const ValueKey('end-workout')),
  );
  return (await SqliteWorkoutRepository(app.database).findUnfinished())!;
}

Future<WorkoutSession> completeCurrentSetViaUi(
  WidgetTester tester,
  IntegrationApp app, {
  Duration activeFor = const Duration(seconds: 15),
}) async {
  await tester.tap(find.byKey(const ValueKey('primary-set-action')));
  await settleIntegrationApp(tester);
  app.clock?.advance(activeFor);
  await tester.tap(find.byKey(const ValueKey('primary-set-action')));
  await settleIntegrationApp(tester);
  return app.container.read(workoutControllerProvider).session!;
}

Future<WorkoutSession> saveWorkoutViaUi(
  WidgetTester tester,
  IntegrationApp app, {
  required String note,
}) async {
  final current = app.container.read(workoutControllerProvider).session!;
  if (current.phase != WorkoutPhase.finishing) {
    await tester.tap(find.byKey(const ValueKey('finish-workout')));
    await settleIntegrationApp(
      tester,
      until: find.byKey(const ValueKey('summary-screen')),
    );
  }
  await tester.ensureVisible(find.byKey(const ValueKey('summary-note')));
  await tester.enterText(find.byKey(const ValueKey('summary-note')), note);
  await tester.ensureVisible(find.byKey(const ValueKey('save-summary')));
  final id = current.id;
  await tester.tap(find.byKey(const ValueKey('save-summary')));
  await settleIntegrationApp(
    tester,
    until: find.byKey(const ValueKey('history-day-detail')),
  );
  return (await SqliteWorkoutRepository(app.database).find(id))!;
}
