import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/history/data/sqlite_history_repository.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/today/application/today_providers.dart';
import 'package:fitness_counter/features/workout/application/workout_controller.dart';
import 'package:fitness_counter/features/workout/application/workout_providers.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/fake_clock.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/pump_app.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  test('start creates one durable session and concurrent calls share it',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repository = SqliteWorkoutRepository(db);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 23, 59));
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);

    final ids = await Future.wait([
      controller.start(twoSetDraft()),
      controller.start(twoSetDraft()),
    ]);

    expect(ids.toSet(), hasLength(1));
    expect(ids.first, isNotEmpty);
    final stored = await repository.findUnfinished();
    expect(stored!.id, ids.first);
    expect(stored.startedAt, DateTime.utc(2026, 9, 15, 23, 59));
    expect(stored.workoutDate, twoSetDraft().workoutDate);
    expect(stored.phase, WorkoutPhase.active);
    expect(stored.revision, 0);
  });

  test('concurrent controllers still create only one unfinished session',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repository = SqliteWorkoutRepository(db);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final first = WorkoutController(
      repository: repository,
      clock: clock,
      sessionIdFactory: () => 'first',
    );
    final second = WorkoutController(
      repository: repository,
      clock: clock,
      sessionIdFactory: () => 'second',
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    final results = await Future.wait([
      first.start(twoSetDraft()).then<Object>((id) => id).catchError(
            (Object error) => error,
          ),
      second.start(twoSetDraft()).then<Object>((id) => id).catchError(
            (Object error) => error,
          ),
    ]);

    expect(results.whereType<String>(), hasLength(1));
    expect(results.whereType<AppFailure>(), hasLength(1));
    expect(
      (await repository.findUnfinished())!.id,
      results.whereType<String>().single,
    );
  });

  test('dispatch persists before publishing the committed revision', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repository = SqliteWorkoutRepository(db);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);
    await controller.start(twoSetDraft());

    await controller.dispatch(const StartSet('s1'));

    expect(controller.state.session!.activeSetId, 's1');
    expect(controller.state.session!.revision, 1);
    expect((await repository.findUnfinished())!.revision, 1);
  });

  test('save uses injected time and returns the fixed start date', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repository = SqliteWorkoutRepository(db);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 23, 59, 30));
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);
    final expectedDate = oneSetDraft().workoutDate;
    final sessionId = await controller.start(oneSetDraft());
    await controller.dispatch(const StartSet('s1'));
    clock.advance(const Duration(seconds: 30));
    await controller.dispatch(
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    );
    await controller.dispatch(const PrepareFinish());
    clock.advance(const Duration(minutes: 10));

    final savedDate = await controller.save(note: '跨午夜完成');

    expect(savedDate, expectedDate);
    expect(controller.state.session, isNull);
    final saved = await repository.find(sessionId);
    expect(saved!.workoutDate, expectedDate);
    expect(saved.endedAt, clock.nowUtc());
    expect(saved.note, '跨午夜完成');
    expect(saved.phase, WorkoutPhase.saved);
  });

  test('saved workout clears active state and a second workout gets a new id',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repository = SqliteWorkoutRepository(db);
    final history = SqliteHistoryRepository(db);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final ids = ['workout-a', 'workout-b'].iterator;
    final controller = WorkoutController(
      repository: repository,
      clock: clock,
      sessionIdFactory: () {
        ids.moveNext();
        return ids.current;
      },
    );
    addTearDown(controller.dispose);

    expect(await controller.start(oneSetDraft()), 'workout-a');
    await controller.dispatch(const StartSet('s1'));
    clock.advance(const Duration(seconds: 30));
    await controller.dispatch(
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    );
    await controller.dispatch(const PrepareFinish());
    await controller.save(note: '第一场');

    expect(controller.state.session, isNull);
    final saved = await history.day(oneSetDraft().workoutDate);
    expect(saved, hasLength(1));
    expect(saved.single.id, 'workout-a');
    expect(saved.single.note, '第一场');

    expect(await controller.start(twoSetDraft()), 'workout-b');
    expect(controller.state.session!.id, 'workout-b');
    expect((await repository.findUnfinished())!.id, 'workout-b');
  });

  test('start retries a failed empty restore before creating its draft',
      () async {
    final repository = _LookupFailureRepository(failOnLookup: 1);
    final controller = WorkoutController(
      repository: repository,
      clock: FakeClock(DateTime.utc(2026, 9, 15, 10)),
      sessionIdFactory: () => 'after-restore',
    );
    addTearDown(controller.dispose);

    await expectLater(controller.restore(), throwsA(isA<AppFailure>()));
    expect(controller.state.pendingSession, isNull);
    expect(controller.state.failure, isNotNull);

    final id = await controller.start(twoSetDraft());

    expect(id, 'after-restore');
    expect(repository.createCalls, 1);
    expect(repository.stored!.exercises.single.sets, hasLength(2));
  });

  test('start adopts an unfinished session recovered by failed restore retry',
      () async {
    final repository = _LookupFailureRepository(failOnLookup: 1);
    final controller = WorkoutController(
      repository: repository,
      clock: FakeClock(DateTime.utc(2026, 9, 15, 10)),
      sessionIdFactory: () => 'must-not-create',
    );
    addTearDown(controller.dispose);

    await expectLater(controller.restore(), throwsA(isA<AppFailure>()));
    repository.stored = newSession(id: 'recovered');

    final id = await controller.start(twoSetDraft());

    expect(id, 'recovered');
    expect(controller.state.session!.id, 'recovered');
    expect(repository.createCalls, 0);
  });

  test('Riverpod exposes one controller and refreshes Today after commit',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    var refreshCount = 0;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => db),
        clockProvider.overrideWithValue(clock),
        workoutProjectionRefreshProvider.overrideWithValue(
          () async => refreshCount += 1,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appDatabaseProvider.future);

    final first = container.read(workoutControllerProvider.notifier);
    final second = container.read(workoutControllerProvider.notifier);
    await first.start(twoSetDraft());

    expect(identical(first, second), isTrue);
    expect(refreshCount, 1);
    expect(container.read(workoutControllerProvider).session, isNotNull);
    container.invalidate(todayOverviewProvider);
  });

  test('provider start recovers its first automatic restore lookup failure',
      () async {
    final repository = _LookupFailureRepository(failOnLookup: 1);
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 9, 15, 10)),
        ),
        workoutRepositoryProvider.overrideWithValue(repository),
        workoutProjectionRefreshProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(workoutControllerProvider.notifier);
    await _waitForControllerFailure(container);

    final id = await controller.start(twoSetDraft());

    expect(id, isNotEmpty);
    expect(repository.createCalls, 1);
    expect(repository.stored!.id, id);
    expect(container.read(workoutControllerProvider).session!.id, id);
  });

  testWidgets('preparation starts once and navigates with the durable id',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final date = twoSetDraft().workoutDate;
    await tester.runAsync(
      () async {
        await SqliteExerciseRepository(db).save(catalogExercise());
        await SqlitePlanRepository(db).save(
          catalogPlan(),
          catalogRevision(effectiveFrom: date),
        );
      },
    );
    final router = await pumpFitnessApp(
      tester,
      database: db,
    );
    router.go('/pre-workout?free=false&date=${date.iso8601}');
    await tester.pump();
    await _pumpUntil(tester, find.byKey(const ValueKey('start-workout')));

    await tester.tap(find.byKey(const ValueKey('start-workout')));
    await tester.tap(find.byKey(const ValueKey('start-workout')));
    await _pumpUntil(tester, find.byKey(const ValueKey('end-workout')));

    final stored = await tester.runAsync(
      () => SqliteWorkoutRepository(db).findUnfinished(),
    );
    expect(stored, isNotNull);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/workout/${stored!.id}',
    );
    final count = await tester.runAsync(
      () => db.database.rawQuery(
        "SELECT COUNT(*) AS count FROM workout_sessions WHERE phase != 'saved'",
      ),
    );
    expect(
      count,
      [
        <String, Object?>{'count': 1},
      ],
    );
  });

  testWidgets('start failure keeps the editable preparation draft',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final date = twoSetDraft().workoutDate;
    await tester.runAsync(
      () async {
        await SqliteExerciseRepository(db).save(catalogExercise());
        await SqlitePlanRepository(db).save(
          catalogPlan(),
          catalogRevision(effectiveFrom: date),
        );
      },
    );
    final repository = _CreateFailureRepository();
    final router = await pumpFitnessApp(
      tester,
      database: db,
      overrides: [
        themeDefinitionsProvider.overrideWith(
          (ref) async => [breathRhythmDefinition],
        ),
        workoutRepositoryProvider.overrideWithValue(repository),
      ],
    );
    router.go('/pre-workout?free=false&date=${date.iso8601}');
    await tester.pump();
    await _pumpUntil(tester, find.byKey(const ValueKey('start-workout')));

    await tester.tap(find.byKey(const ValueKey('start-workout')));
    await _pumpUntil(tester, find.text(AppStrings.workoutStartFailed));

    expect(find.text('哑铃卧推'), findsWidgets);
    expect(find.text(AppStrings.retryWorkoutStart), findsOneWidget);
    expect(
      await tester.runAsync(
        () => SqliteWorkoutRepository(db).findUnfinished(),
      ),
      isNull,
    );
  });

  testWidgets('start lookup failure retries the captured preparation draft',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final date = twoSetDraft().workoutDate;
    await tester.runAsync(
      () async {
        await SqliteExerciseRepository(db).save(catalogExercise());
        await SqlitePlanRepository(db).save(
          catalogPlan(),
          catalogRevision(effectiveFrom: date),
        );
      },
    );
    final repository = _LookupFailureRepository(failOnLookup: 2);
    final router = await pumpFitnessApp(
      tester,
      database: db,
      overrides: [
        themeDefinitionsProvider.overrideWith(
          (ref) async => [breathRhythmDefinition],
        ),
        workoutRepositoryProvider.overrideWithValue(repository),
      ],
    );
    router.go('/pre-workout?free=false&date=${date.iso8601}');
    await tester.pump();
    await _pumpUntil(tester, find.byKey(const ValueKey('start-workout')));

    await tester.tap(find.byKey(const ValueKey('start-workout')));
    await _pumpUntil(tester, find.text(AppStrings.retryWorkoutStart));
    expect(find.text('哑铃卧推'), findsWidgets);
    expect(repository.stored, isNull);

    await tester.tap(find.byKey(const ValueKey('start-workout')));
    await _pumpUntil(tester, find.byKey(const ValueKey('end-workout')));

    expect(repository.stored, isNotNull);
    expect(repository.stored!.exercises.single.nameSnapshot, '哑铃卧推');
    expect(repository.createCalls, 1);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/workout/${repository.stored!.id}',
    );
    await _completeProjectionReads(tester);
  });

  testWidgets(
      'first provider restore failure still starts the prepared draft once',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final date = twoSetDraft().workoutDate;
    await tester.runAsync(
      () async {
        await SqliteExerciseRepository(db).save(catalogExercise());
        await SqlitePlanRepository(db).save(
          catalogPlan(),
          catalogRevision(effectiveFrom: date),
        );
      },
    );
    final repository = _LookupFailureRepository(failOnLookup: 1);
    final router = await pumpFitnessApp(
      tester,
      database: db,
      overrides: [
        themeDefinitionsProvider.overrideWith(
          (ref) async => [breathRhythmDefinition],
        ),
        workoutRepositoryProvider.overrideWithValue(repository),
      ],
    );
    router.go('/pre-workout?free=false&date=${date.iso8601}');
    await tester.pump();
    await _pumpUntil(tester, find.byKey(const ValueKey('start-workout')));

    await tester.tap(find.byKey(const ValueKey('start-workout')));
    await _pumpUntil(tester, find.byKey(const ValueKey('end-workout')));

    expect(repository.stored, isNotNull);
    expect(repository.stored!.exercises.single.nameSnapshot, '哑铃卧推');
    expect(repository.createCalls, 1);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/workout/${repository.stored!.id}',
    );
    await _completeProjectionReads(tester);
  });
}

Future<void> _completeProjectionReads(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(const ValueKey('end-workout'))),
  );
  // Starting refreshes Today asynchronously. Finish native SQLite reads before
  // fake-clock test teardown closes the database. Pump provider invalidations
  // as well: awaiting their future alone can leave the fake scheduler paused.
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (!container.read(todayOverviewProvider).isLoading &&
        !container.read(todayControllerProvider).isLoading) {
      return;
    }
  }
  fail('Today projections did not finish before database teardown.');
}

Future<void> _waitForControllerFailure(ProviderContainer container) async {
  for (var attempt = 0;
      attempt < 100 &&
          container.read(workoutControllerProvider).failure == null;
      attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(container.read(workoutControllerProvider).failure, isNotNull);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 200 && finder.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(finder, findsOneWidget);
}

final class _CreateFailureRepository implements WorkoutRepository {
  @override
  Future<void> create(WorkoutSession session) async =>
      throw const AppFailure(FailureCode.persistence, detail: 'disk full');

  @override
  Future<void> discard(String id) async => throw UnimplementedError();

  @override
  Future<WorkoutSession?> find(String id) async => null;

  @override
  Future<WorkoutSession?> findUnfinished() async => null;

  @override
  Future<void> save(
    WorkoutSession session, {
    required int expectedRevision,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> saveCompleted(
    String id, {
    required String note,
    required int expectedRevision,
    DateTime? endedAtUtc,
  }) async =>
      throw UnimplementedError();
}

final class _LookupFailureRepository implements WorkoutRepository {
  _LookupFailureRepository({required this.failOnLookup});

  final int failOnLookup;
  int lookupCalls = 0;
  int createCalls = 0;
  WorkoutSession? stored;

  @override
  Future<void> create(WorkoutSession session) async {
    createCalls += 1;
    stored = session;
  }

  @override
  Future<void> discard(String id) async => throw UnimplementedError();

  @override
  Future<WorkoutSession?> find(String id) async => stored;

  @override
  Future<WorkoutSession?> findUnfinished() async {
    lookupCalls += 1;
    if (lookupCalls == failOnLookup) {
      throw const AppFailure(FailureCode.persistence, detail: 'read failed');
    }
    return stored;
  }

  @override
  Future<void> save(
    WorkoutSession session, {
    required int expectedRevision,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> saveCompleted(
    String id, {
    required String note,
    required int expectedRevision,
    DateTime? endedAtUtc,
  }) async =>
      throw UnimplementedError();
}
