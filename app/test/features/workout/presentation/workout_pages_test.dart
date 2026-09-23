import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/app/router.dart';
import 'package:fitness_counter/core/data/app_database.dart';
import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/settings/data/sqlite_settings_repository.dart';
import 'package:fitness_counter/features/settings/domain/app_settings.dart';
import 'package:fitness_counter/features/workout/application/rest_effects_controller.dart';
import 'package:fitness_counter/features/workout/application/workout_controller.dart';
import 'package:fitness_counter/features/workout/application/workout_providers.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_draft.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:fitness_counter/features/workout/domain/workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/app_theme.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:fitness_counter/theme/workout_skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/fake_clock.dart';
import '../../../support/history_test_support.dart';
import '../../../support/pump_app.dart';
import '../../../support/rest_effect_fakes.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

final _instant = DateTime.utc(2026, 9, 15, 8);
const _layoutEpsilon = 1e-9;

WorkoutSession oneSetSessionInProgress() {
  final session = WorkoutMachine.start(
    id: 'workout-1',
    draft: oneSetDraft(),
    nowUtc: _instant,
  );
  return WorkoutMachine.transition(
    session,
    const StartSet('s1'),
    _instant,
  );
}

WorkoutSession _finishingSession() {
  var session = oneSetSessionInProgress();
  session = WorkoutMachine.transition(
    session,
    const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    _instant.add(const Duration(seconds: 30)),
  );
  return WorkoutMachine.transition(
    session,
    const PrepareFinish(),
    _instant.add(const Duration(seconds: 40)),
  );
}

WorkoutSession _restingSession() {
  var session = WorkoutMachine.start(
    id: 'workout-1',
    draft: twoSetDraft(),
    nowUtc: _instant,
  );
  session = WorkoutMachine.transition(
    session,
    const StartSet('s1'),
    _instant,
  );
  return WorkoutMachine.transition(
    session,
    const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    _instant.add(const Duration(seconds: 30)),
  );
}

WorkoutSession _completedPausedSession() => WorkoutMachine.transition(
      oneSetSessionInProgress(),
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
      _instant.add(const Duration(seconds: 30)),
    );

WorkoutSession _zeroCompletedSession() {
  final started = WorkoutMachine.start(
    id: 'workout-1',
    draft: twoSetDraft(),
    nowUtc: _instant,
  );
  return WorkoutMachine.transition(
    started,
    SkipExercise(started.exercises.single.id),
    _instant,
  );
}

WorkoutDraft _threeSetDraft() {
  final draft = twoSetDraft();
  final exercise = draft.exercises.single;
  return WorkoutDraft(
    workoutDate: draft.workoutDate,
    exercises: [
      exercise.copyWith(
        sets: [
          ...exercise.sets,
          temporarySet('s3', order: 2),
        ],
      ),
    ],
  );
}

WorkoutDraft _threeExerciseDraft() {
  final source = twoSetDraft();
  final template = source.exercises.single;
  return WorkoutDraft(
    workoutDate: source.workoutDate,
    exercises: [
      WorkoutExercise(
        id: 'completed-exercise',
        exerciseId: 'completed-catalog',
        nameSnapshot: 'Completed exercise',
        categorySnapshot: template.categorySnapshot,
        equipmentSnapshot: template.equipmentSnapshot,
        unitSnapshot: template.unitSnapshot,
        note: '',
        targetRestSeconds: 90,
        order: 0,
        temporary: true,
        sets: [temporarySet('completed-set', order: 0)],
      ),
      WorkoutExercise(
        id: 'pending-exercise-1',
        exerciseId: 'pending-catalog-1',
        nameSnapshot: 'Pending exercise 1',
        categorySnapshot: template.categorySnapshot,
        equipmentSnapshot: template.equipmentSnapshot,
        unitSnapshot: template.unitSnapshot,
        note: '',
        targetRestSeconds: 90,
        order: 1,
        temporary: true,
        sets: [temporarySet('pending-set-1', order: 0)],
      ),
      WorkoutExercise(
        id: 'pending-exercise-2',
        exerciseId: 'pending-catalog-2',
        nameSnapshot: 'Pending exercise 2',
        categorySnapshot: template.categorySnapshot,
        equipmentSnapshot: template.equipmentSnapshot,
        unitSnapshot: template.unitSnapshot,
        note: '',
        targetRestSeconds: 90,
        order: 2,
        temporary: true,
        sets: [temporarySet('pending-set-2', order: 0)],
      ),
    ],
  );
}

Future<WorkoutHarness> pumpWorkout(
  WidgetTester tester, {
  required WorkoutSession session,
  String? initialLocation,
  RestEffectsController? effects,
  AppSettings? effectSettings,
  WorkoutRepository Function(SqliteWorkoutRepository repository)?
      repositoryWrapper,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final database = (await tester.runAsync(openTestDatabase))!;
  addTearDown(database.close);
  final sqliteRepository = SqliteWorkoutRepository(database);
  await tester.runAsync(() => sqliteRepository.create(session));
  await tester.runAsync(
    () => SqliteExerciseRepository(database).save(
      catalogExercise(id: 'picker-x', name: 'Picker exercise'),
    ),
  );
  final repository =
      repositoryWrapper?.call(sqliteRepository) ?? sqliteRepository;
  final clock = FakeClock(session.restStartedAt ?? _instant);
  final controller = (await tester.runAsync(
    () async => WorkoutController(
      repository: repository,
      clock: clock,
      restEffectsController: effects,
      restEffectsSettings: () async => effectSettings ?? AppSettings(),
    ),
  ))!;
  await tester.runAsync(controller.restore);
  final router = await pumpFitnessApp(
    tester,
    database: database,
    initialLocation: initialLocation ??
        switch (session.phase) {
          WorkoutPhase.resting => '/rest/${session.id}',
          WorkoutPhase.finishing => '/summary/${session.id}',
          _ => '/workout/${session.id}',
        },
    overrides: [
      themeDefinitionsProvider.overrideWith(
        (ref) async => [breathRhythmDefinition],
      ),
      clockProvider.overrideWithValue(clock),
      workoutRepositoryProvider.overrideWithValue(repository),
      workoutControllerProvider.overrideWith((ref) => controller),
    ],
  );
  await tester.pump(const Duration(milliseconds: 16));
  return WorkoutHarness(
    database: database,
    repository: repository,
    controller: controller,
    clock: clock,
    router: router,
  );
}

final class WorkoutHarness {
  const WorkoutHarness({
    required this.database,
    required this.repository,
    required this.controller,
    required this.clock,
    required this.router,
  });
  final AppDatabase database;
  final WorkoutRepository repository;
  final WorkoutController controller;
  final FakeClock clock;
  final GoRouter router;
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() predicate,
) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (!predicate()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for state.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
}

Future<void> _waitForFinder(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $finder.');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets(
      'wake lease survives workout rest workout route replacement and releases on home',
      (tester) async {
    final platform =
        (await tester.runAsync(() async => EffectHarness()..effects))!;
    final active = WorkoutMachine.start(
      id: 'route-wake',
      draft: twoSetDraft(),
      nowUtc: _instant,
    );
    final h =
        await pumpWorkout(tester, session: active, effects: platform.effects);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(platform.wake.values, isNotEmpty);
    expect(platform.wake.values.last, isTrue);
    await tester.runAsync(() => h.controller.dispatch(const StartSet('s1')));
    await tester.runAsync(
      () => h.controller
          .dispatch(const CompleteSet('s1', actualWeight: 20, actualReps: 8)),
    );
    h.router.go('/rest/route-wake');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.wake.values.last, isTrue);
    await tester.runAsync(() => h.controller.dispatch(const StartSet('s2')));
    h.router.go('/workout/route-wake');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.wake.values.last, isTrue);
    h.router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(platform.wake.values.last, isFalse);
  });

  testWidgets('disabled screen-awake stays off on workout and rest routes',
      (tester) async {
    final platform =
        (await tester.runAsync(() async => EffectHarness()..effects))!;
    final h = await pumpWorkout(
      tester,
      session: _restingSession(),
      effects: platform.effects,
      effectSettings: AppSettings(screenAwake: false),
    );
    await tester.pump();
    expect(platform.wake.values, isEmpty);
    await tester.runAsync(() => h.controller.dispatch(const StartSet('s2')));
    h.router.go('/workout/workout-1');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(platform.wake.values, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  setUpAll(() async {
    final font = File('C:/Windows/Fonts/NotoSansSC-VF.ttf');
    if (font.existsSync()) {
      final loader = FontLoader(AppTheme.fontFamily)
        ..addFont(
          font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('all pending sets are selectable without starting a set',
      (tester) async {
    final session = WorkoutMachine.start(
      id: 'workout-1',
      draft: twoSetDraft(),
      nowUtc: _instant,
    );
    final harness = await pumpWorkout(tester, session: session);

    expect(find.byKey(const ValueKey('set-row-s1')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-row-s2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('set-row-s2')));
    await _waitFor(
      tester,
      () => harness.controller.state.session?.selectedSetId == 's2',
    );

    expect(harness.controller.state.session?.selectedSetId, 's2');
    expect(harness.controller.state.session?.activeSetId, isNull);
  });

  testWidgets('complete non-final set routes to durable rest', (tester) async {
    final session = WorkoutMachine.start(
      id: 'workout-1',
      draft: twoSetDraft(),
      nowUtc: _instant,
    );
    final harness = await pumpWorkout(tester, session: session);

    await tester.tap(find.byKey(const ValueKey('primary-set-action')));
    await _waitFor(
      tester,
      () => harness.controller.state.session?.activeSetId == 's1',
    );
    harness.clock.advance(const Duration(seconds: 30));
    await tester.tap(find.byKey(const ValueKey('primary-set-action')));
    await _waitFor(
      tester,
      () => harness.controller.state.session?.phase == WorkoutPhase.resting,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('rest-workout-1')), findsOneWidget);
    expect(
      harness.controller.state.session!.exercises.single.sets.first.actualReps,
      8,
    );
  });

  testWidgets('rest target never auto-starts and explicit start records rest',
      (tester) async {
    var session = WorkoutMachine.start(
      id: 'workout-1',
      draft: twoSetDraft(),
      nowUtc: _instant,
    );
    session = WorkoutMachine.transition(
      session,
      const StartSet('s1'),
      _instant,
    );
    session = WorkoutMachine.transition(
      session,
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
      _instant.add(const Duration(seconds: 30)),
    );
    final harness = await pumpWorkout(tester, session: session);
    harness.clock.advance(const Duration(seconds: 125));
    await tester.pump(const Duration(seconds: 1));

    expect(harness.controller.state.session?.activeSetId, isNull);
    expect(find.text('已超目标'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('start-next-set')));
    await _waitFor(
      tester,
      () => harness.controller.state.session?.activeSetId == 's2',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('workout-workout-1')), findsOneWidget);
    expect(
      harness.controller.state.session!.exercises.single.sets.last
          .preSetRestSeconds,
      125,
    );
  });

  testWidgets('final completion freezes and offers add training plus finish',
      (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: oneSetSessionInProgress(),
    );
    harness.clock.advance(const Duration(seconds: 30));

    await tester.tap(find.byKey(const ValueKey('primary-set-action')));
    await _waitFor(
      tester,
      () =>
          harness.controller.state.session?.phase ==
          WorkoutPhase.completedPaused,
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('add-training')), findsOneWidget);
    expect(find.byKey(const ValueKey('finish-workout')), findsOneWidget);
    final frozen = harness.controller.state.session!.timer
        .read(harness.clock.nowUtc())
        .seconds;
    harness.clock.advance(const Duration(minutes: 5));
    expect(
      harness.controller.state.session!.timer
          .read(harness.clock.nowUtc())
          .seconds,
      frozen,
    );
  });

  testWidgets('early end blocks zero-set save and confirms discard',
      (tester) async {
    final session = WorkoutMachine.start(
      id: 'workout-1',
      draft: oneSetDraft(),
      nowUtc: _instant,
    );
    final harness = await pumpWorkout(tester, session: session);

    await tester.tap(find.byKey(const ValueKey('end-workout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('early-end-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('end-and-save')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('discard-workout')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('confirm-discard')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-discard')));
    await _waitFor(tester, () => harness.controller.state.session == null);
    expect(harness.router.routeInformationProvider.value.uri.path, '/home');
  });

  testWidgets('early end duration advances without persisting every tick',
      (tester) async {
    final harness = await pumpWorkout(tester, session: _restingSession());
    final revision = harness.controller.state.session!.revision;
    await tester.tap(find.byKey(const ValueKey('end-rest-workout')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('early-end-duration')),
        matching: find.text('00:30'),
      ),
      findsOneWidget,
    );

    harness.clock.advance(const Duration(seconds: 5));
    await tester.pump(WorkoutSkin.timerTick);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('early-end-duration')),
        matching: find.text('00:35'),
      ),
      findsOneWidget,
    );
    expect(harness.controller.state.session!.revision, revision);

    await tester.tap(find.byKey(const ValueKey('end-and-save')));
    await _waitFor(
      tester,
      () => harness.controller.state.session?.phase == WorkoutPhase.finishing,
    );
    expect(
      harness.controller.state.session!.timer
          .read(harness.clock.nowUtc())
          .seconds,
      35,
    );
  });

  testWidgets('completed pause add set stays frozen until explicit start',
      (tester) async {
    final harness =
        await pumpWorkout(tester, session: _completedPausedSession());
    final frozen = harness.controller.state.session!.timer
        .read(harness.clock.nowUtc())
        .seconds;
    await tester.tap(find.byKey(const ValueKey('add-training')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-set')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.exercises.single.sets.length == 2,
    );
    final pending =
        harness.controller.state.session!.exercises.single.sets.last;
    harness.clock.advance(const Duration(minutes: 5));
    expect(
      harness.controller.state.session!.timer
          .read(harness.clock.nowUtc())
          .seconds,
      frozen,
    );
    await tester.tap(find.byKey(ValueKey('set-row-${pending.id}')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.selectedSetId == pending.id,
    );
    expect(find.byKey(const ValueKey('primary-set-action')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('primary-set-action')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.phase == WorkoutPhase.active,
    );
    harness.clock.advance(const Duration(seconds: 10));
    expect(
      harness.controller.state.session!.timer
          .read(harness.clock.nowUtc())
          .seconds,
      frozen + 10,
    );
    final rebuilt = await tester.runAsync(
      () => SqliteWorkoutRepository(harness.database).find('workout-1'),
    );
    expect(rebuilt!.phase, WorkoutPhase.active);
    expect(rebuilt.activeSetId, pending.id);
  });

  testWidgets('early end shows duration completed remaining and skip result',
      (tester) async {
    await pumpWorkout(tester, session: _restingSession());
    await tester.tap(find.byKey(const ValueKey('end-rest-workout')));
    await tester.pump(WorkoutSkin.sheetDuration);
    expect(find.byKey(const ValueKey('early-end-duration')), findsOneWidget);
    expect(find.byKey(const ValueKey('early-end-completed')), findsOneWidget);
    expect(find.byKey(const ValueKey('early-end-remaining')), findsOneWidget);
    expect(find.textContaining('其余 1 组将标记为跳过'), findsOneWidget);
  });

  testWidgets('summary continue restores the durable checkpoint',
      (tester) async {
    final harness = await pumpWorkout(tester, session: _finishingSession());

    await tester.tap(find.byKey(const ValueKey('continue-workout')));
    await _waitFor(
      tester,
      () =>
          harness.controller.state.session?.phase ==
          WorkoutPhase.completedPaused,
    );
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/workout/workout-1',
    );
  });

  testWidgets('summary save keeps note and uses fixed workout date path',
      (tester) async {
    final harness = await pumpWorkout(tester, session: _finishingSession());
    await tester.enterText(
      find.byKey(const ValueKey('summary-note')),
      '状态不错',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-summary')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-summary')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    expect(
      harness.controller.state.failure,
      isNull,
      reason: 'summary save must not fail persistence',
    );
    await _waitFor(tester, () => harness.controller.state.session == null);

    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/history/2026-09-15',
    );
  });

  testWidgets('summary failure freezes exact note until retry succeeds',
      (tester) async {
    late _FailOnceWorkoutRepository failing;
    final harness = await pumpWorkout(
      tester,
      session: _finishingSession(),
      repositoryWrapper: (repository) =>
          failing = _FailOnceWorkoutRepository(repository),
    );
    failing.failNextCompletedSave = true;
    await tester.enterText(
      find.byKey(const ValueKey('summary-note')),
      '保留这一条',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-summary')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-summary')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _waitFor(tester, () => harness.controller.state.failure != null);

    final note = tester.widget<TextField>(
      find.byKey(const ValueKey('summary-note')),
    );
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('save-summary')),
    );
    final continueButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('continue-workout')),
    );
    expect(note.enabled, isFalse);
    expect(save.onPressed, isNull);
    expect(continueButton.onPressed, isNull);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('summary-retry')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('summary-retry')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _waitFor(tester, () => harness.controller.state.session == null);
    expect(failing.completedNote, '保留这一条');
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/history/2026-09-15',
    );
  });

  testWidgets('adjustment failure disables business controls until retry',
      (tester) async {
    late _FailOnceWorkoutRepository failing;
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
      repositoryWrapper: (repository) =>
          failing = _FailOnceWorkoutRepository(repository),
    );
    await tester.tap(find.byKey(const ValueKey('adjust-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('edit-reps')), '6');
    failing.failNextSave = true;
    await tester.tap(find.byKey(const ValueKey('confirm-edit')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _waitFor(tester, () => harness.controller.state.failure != null);

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('confirm-edit')))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('edit-reps'))).enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('adjustment-retry')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _waitFor(
      tester,
      () =>
          harness.controller.state.session!.exercises.single.sets.first
              .actualReps ==
          6,
    );
  });

  testWidgets('prepare finish failure exposes only retry then opens summary',
      (tester) async {
    late _FailOnceWorkoutRepository failing;
    final harness = await pumpWorkout(
      tester,
      session: _restingSession(),
      repositoryWrapper: (repository) =>
          failing = _FailOnceWorkoutRepository(repository),
    );
    failing.failNextSave = true;
    await tester.tap(find.byKey(const ValueKey('end-rest-workout')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    await tester.ensureVisible(find.byKey(const ValueKey('end-and-save')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('end-and-save')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _waitFor(tester, () => harness.controller.state.failure != null);

    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('end-and-save')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(
              OutlinedButton,
              AppStrings.continueTraining,
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('early-end-retry')));
    await _waitFor(
      tester,
      () => harness.controller.state.session?.phase == WorkoutPhase.finishing,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/summary/workout-1',
    );
  });

  testWidgets('discard failure disables sheet actions until exact retry',
      (tester) async {
    late _FailOnceWorkoutRepository failing;
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: oneSetDraft(),
        nowUtc: _instant,
      ),
      repositoryWrapper: (repository) =>
          failing = _FailOnceWorkoutRepository(repository),
    );
    failing.failNextDiscard = true;
    await tester.tap(find.byKey(const ValueKey('end-workout')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    await tester.tap(find.byKey(const ValueKey('discard-workout')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('confirm-discard')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _waitFor(tester, () => harness.controller.state.failure != null);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(
              OutlinedButton,
              AppStrings.continueTraining,
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('early-end-retry')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await _waitFor(tester, () => harness.controller.state.session == null);
    expect(harness.router.routeInformationProvider.value.uri.path, '/home');
  });

  testWidgets('prepare finish skips remaining work and freezes timer',
      (tester) async {
    final harness = await pumpWorkout(tester, session: _restingSession());
    final before = harness.controller.state.session!.timer
        .read(harness.clock.nowUtc())
        .seconds;
    await tester.tap(find.byKey(const ValueKey('end-rest-workout')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    await tester.ensureVisible(find.byKey(const ValueKey('end-and-save')));
    await tester.tap(find.byKey(const ValueKey('end-and-save')));
    await _waitFor(
      tester,
      () => harness.controller.state.session?.phase == WorkoutPhase.finishing,
    );
    final set = harness.controller.state.session!.exercises.single.sets.last;
    expect(set.status, SetStatus.skipped);
    harness.clock.advance(const Duration(minutes: 3));
    expect(
      harness.controller.state.session!.timer
          .read(harness.clock.nowUtc())
          .seconds,
      before,
    );
  });

  testWidgets('adjustment edit persists actual values through reconstruction',
      (tester) async {
    final session = WorkoutMachine.start(
      id: 'workout-1',
      draft: twoSetDraft(),
      nowUtc: _instant,
    );
    final harness = await pumpWorkout(tester, session: session);

    await tester.tap(find.byKey(const ValueKey('adjust-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-weight')),
      '27.5',
    );
    await tester.enterText(find.byKey(const ValueKey('edit-reps')), '6');
    await tester.tap(find.byKey(const ValueKey('confirm-edit')));
    await _waitFor(
      tester,
      () =>
          harness.controller.state.session!.exercises.single.sets.first
              .actualReps ==
          6,
    );

    final rebuilt = await tester.runAsync(
      () => harness.repository.find('workout-1'),
    );
    expect(rebuilt!.exercises.single.sets.first.actualWeight, 27.5);
    expect(rebuilt.exercises.single.sets.first.actualReps, 6);
  });

  testWidgets('adjustment add set persists a real pending set', (tester) async {
    final session = WorkoutMachine.start(
      id: 'workout-1',
      draft: twoSetDraft(),
      nowUtc: _instant,
    );
    final harness = await pumpWorkout(tester, session: session);

    await tester.tap(find.byKey(const ValueKey('adjust-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-set')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.exercises.single.sets.length == 3,
    );

    final rebuilt = await tester.runAsync(
      () => harness.repository.find('workout-1'),
    );
    expect(rebuilt!.exercises.single.sets, hasLength(3));
    expect(rebuilt.exercises.single.sets.last.status, SetStatus.pending);
  });

  testWidgets('adjustment skips selected set without starting it',
      (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('adjust-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('skip-set')));
    await _waitFor(
      tester,
      () =>
          harness
              .controller.state.session!.exercises.single.sets.first.status ==
          SetStatus.skipped,
    );
    expect(harness.controller.state.session!.activeSetId, isNull);
  });

  testWidgets('adjustment skips all pending sets in selected exercise',
      (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('adjust-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('skip-exercise')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.exercises.single.sets
          .every((set) => set.status == SetStatus.skipped),
    );
    expect(
      harness.controller.state.session!.phase,
      WorkoutPhase.completedPaused,
    );
    expect(find.text('尚未完成任何训练组，不能保存本次训练。'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-training')), findsOneWidget);
    expect(find.byKey(const ValueKey('discard-empty-workout')), findsOneWidget);
    expect(find.byKey(const ValueKey('finish-workout')), findsNothing);
    expect(find.byKey(const ValueKey('save-summary')), findsNothing);

    await expectLater(
      harness.controller.dispatch(const PrepareFinish()),
      throwsA(isA<AppFailure>()),
    );
    expect(harness.controller.state.failure, isNotNull);
    expect(
      harness.controller.state.session!.phase,
      WorkoutPhase.completedPaused,
    );
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/workout/workout-1',
    );
  });

  testWidgets('adjustment deletes a pending set', (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('adjust-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-set')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.exercises.single.sets.length == 1,
    );
    expect(
      harness.controller.state.session!.exercises.single.sets.single.id,
      's2',
    );
  });

  testWidgets('deleting all pending work cannot expose summary or save',
      (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    for (var remaining = 2; remaining > 0; remaining--) {
      await tester.tap(find.byKey(const ValueKey('adjust-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-set')));
      await _waitFor(
        tester,
        () =>
            harness.controller.state.session!.exercises
                .expand((exercise) => exercise.sets)
                .length ==
            remaining - 1,
      );
    }

    expect(
      harness.controller.state.session!.phase,
      WorkoutPhase.completedPaused,
    );
    expect(find.text('尚未完成任何训练组，不能保存本次训练。'), findsOneWidget);
    expect(find.byKey(const ValueKey('finish-workout')), findsNothing);
    expect(find.byKey(const ValueKey('save-summary')), findsNothing);
  });

  testWidgets(
      'delete-all Add Training persists defaults and resumes on explicit start',
      (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.runAsync(
      () => SqliteSettingsRepository(harness.database).save(
        AppSettings(defaultRestSeconds: 135),
      ),
    );
    for (var remaining = 2; remaining > 0; remaining--) {
      await tester.tap(find.byKey(const ValueKey('adjust-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-set')));
      await _waitFor(
        tester,
        () =>
            harness.controller.state.session!.exercises
                .expand((exercise) => exercise.sets)
                .length ==
            remaining - 1,
      );
    }

    expect(harness.controller.state.session!.exercises, isEmpty);
    expect(
      harness.controller.state.session!.phase,
      WorkoutPhase.completedPaused,
    );
    await tester.tap(find.byKey(const ValueKey('add-training')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-exercise')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('picker-exercise-picker-x')),
    );
    await tester.pump(WorkoutSkin.sheetDuration);
    await tester.ensureVisible(
      find.byKey(const ValueKey('picker-exercise-picker-x')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('picker-exercise-picker-x')),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _waitFor(
      tester,
      () => harness.controller.state.session!.exercises.length == 1,
    );

    final added = harness.controller.state.session!.exercises.single;
    final addedSet = added.sets.single;
    expect(added.exerciseId, 'picker-x');
    expect(added.nameSnapshot, 'Picker exercise');
    expect(added.targetRestSeconds, 135);
    expect(added.temporary, isTrue);
    expect(addedSet.plannedWeight, 0);
    expect(addedSet.plannedReps, 10);
    expect(addedSet.unit, WeightUnit.kg);
    expect(addedSet.status, SetStatus.pending);
    expect(addedSet.temporary, isTrue);
    expect(
      harness.controller.state.session!.phase,
      WorkoutPhase.completedPaused,
    );
    expect(
      harness.controller.state.session!.timer.runningSegmentStartedAt,
      isNull,
    );

    final rebuilt = await tester.runAsync(
      () => harness.repository.find('workout-1'),
    );
    expect(rebuilt!.exercises.single.exerciseId, 'picker-x');
    expect(rebuilt.exercises.single.targetRestSeconds, 135);
    expect(rebuilt.exercises.single.sets.single.plannedWeight, 0);
    expect(rebuilt.exercises.single.sets.single.plannedReps, 10);

    Navigator.of(
      tester.element(find.byKey(const ValueKey('add-exercise'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('set-row-${addedSet.id}')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.selectedSetId == addedSet.id,
    );
    await tester.tap(find.byKey(const ValueKey('primary-set-action')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.activeSetId == addedSet.id,
    );

    expect(harness.controller.state.session!.phase, WorkoutPhase.active);
    expect(
      harness.controller.state.session!.timer.runningSegmentStartedAt,
      _instant,
    );
    final active = await tester.runAsync(
      () => harness.repository.find('workout-1'),
    );
    expect(active!.phase, WorkoutPhase.active);
    expect(active.activeSetId, addedSet.id);
    expect(active.exercises.single.sets.single.status, SetStatus.inProgress);
  });

  testWidgets('adjustment reorders movable pending exercises', (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: _threeExerciseDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('set-row-pending-set-1')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.selectedSetId == 'pending-set-1',
    );
    await tester.tap(find.byKey(const ValueKey('adjust-add')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('move-exercise-earlier')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('move-exercise-earlier')));
    await _waitFor(
      tester,
      () =>
          harness.controller.state.session!.exercises.first.id ==
          'pending-exercise-1',
    );
    final rebuilt = await tester.runAsync(
      () => harness.repository.find('workout-1'),
    );
    expect(rebuilt!.exercises.first.id, 'pending-exercise-1');

    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('move-exercise-earlier')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('move-exercise-later')),
          )
          .onPressed,
      isNotNull,
    );
    _expectTapTarget(tester, 'move-exercise-earlier', 390);
    _expectTapTarget(tester, 'move-exercise-later', 390);
    Navigator.of(
      tester.element(find.byKey(const ValueKey('move-exercise-earlier'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('set-row-pending-set-2')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.selectedSetId == 'pending-set-2',
    );
    await tester.tap(find.byKey(const ValueKey('adjust-add')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('move-exercise-later')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('adjustment adds an exercise through the shared picker',
      (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('adjust-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-exercise')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('picker-exercise-picker-x')),
    );
    await tester.tap(
      find.byKey(const ValueKey('picker-exercise-picker-x')),
    );
    await _waitFor(
      tester,
      () => harness.controller.state.session!.exercises
          .any((exercise) => exercise.exerciseId == 'picker-x'),
    );
  });

  testWidgets('rest alternate selection starts the chosen set', (tester) async {
    var session = WorkoutMachine.start(
      id: 'workout-1',
      draft: _threeSetDraft(),
      nowUtc: _instant,
    );
    session =
        WorkoutMachine.transition(session, const StartSet('s1'), _instant);
    session = WorkoutMachine.transition(
      session,
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
      _instant.add(const Duration(seconds: 30)),
    );
    final harness = await pumpWorkout(tester, session: session);
    await tester.tap(find.byKey(const ValueKey('rest-set-s3')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.selectedSetId == 's3',
    );
    await tester.tap(find.byKey(const ValueKey('start-next-set')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.activeSetId == 's3',
    );
  });

  testWidgets('adjustment rejects zero reps before dispatch', (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('adjust-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('edit-reps')), '0');
    await tester.tap(find.byKey(const ValueKey('confirm-edit')));
    await tester.pump();
    expect(find.text(AppStrings.invalidReps), findsOneWidget);
    expect(
      harness.controller.state.session!.exercises.single.sets.first.actualReps,
      isNull,
    );
  });

  testWidgets('pending selection is visible without starting timers',
      (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('set-row-s2')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.selectedSetId == 's2',
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('set-row-s2')))
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    expect(harness.controller.state.session!.activeSetId, isNull);
    expect(
      harness.controller.state.session!.exercises.single.sets.last.status,
      SetStatus.pending,
    );
  });

  testWidgets('active set dot uses the centralized repeating pulse',
      (tester) async {
    await pumpWorkout(tester, session: oneSetSessionInProgress());
    final pulse = find.byKey(const ValueKey('active-set-pulse'));
    expect(pulse, findsOneWidget);
    final before = tester.getSize(pulse);
    await tester.pump(const Duration(milliseconds: 630));
    final during = tester.getSize(pulse);
    expect(during.width, greaterThan(before.width));
    await tester.pump(const Duration(milliseconds: 1170));
    expect(tester.getSize(pulse).width, closeTo(before.width, 0.1));
  });

  testWidgets(
      'adjustment hides pending reorder controls for a completed selection',
      (tester) async {
    final base = WorkoutMachine.start(
      id: 'workout-1',
      draft: _threeExerciseDraft(),
      nowUtc: _instant,
    );
    final selectedCompleted = base.copyWith(
      exercises: [
        base.exercises.first.copyWith(
          sets: [
            base.exercises.first.sets.first.copyWith(
              status: SetStatus.completed,
              actualWeight: 20.0,
              actualReps: 8,
              startedAt: _instant,
              completedAt: _instant.add(const Duration(seconds: 30)),
              setDurationSeconds: 30,
            ),
          ],
        ),
        ...base.exercises.skip(1),
      ],
      selectedSetId: 'completed-set',
    );
    await pumpWorkout(tester, session: selectedCompleted);

    await tester.tap(find.byKey(const ValueKey('adjust-add')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.moveExerciseEarlier), findsNothing);
    expect(find.text(AppStrings.moveExerciseLater), findsNothing);
  });

  test('durable phases map to canonical route contracts', () {
    final active = WorkoutMachine.start(
      id: 'workout-1',
      draft: oneSetDraft(),
      nowUtc: _instant,
    );
    final restingBase = WorkoutMachine.start(
      id: 'workout-1',
      draft: twoSetDraft(),
      nowUtc: _instant,
    );
    final started = WorkoutMachine.transition(
      restingBase,
      const StartSet('s1'),
      _instant,
    );
    final resting = WorkoutMachine.transition(
      started,
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
      _instant.add(const Duration(seconds: 30)),
    );
    final completed = WorkoutMachine.transition(
      oneSetSessionInProgress(),
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
      _instant.add(const Duration(seconds: 30)),
    );
    final finishing = WorkoutMachine.transition(
      completed,
      const PrepareFinish(),
      _instant.add(const Duration(seconds: 40)),
    );
    final anomaly = WorkoutMachine.transition(
      active,
      const SelectSet('s1'),
      _instant.subtract(const Duration(seconds: 1)),
    );

    expect(AppRoutes.forWorkoutSession(active), '/workout/workout-1');
    expect(AppRoutes.forWorkoutSession(resting), '/rest/workout-1');
    expect(AppRoutes.forWorkoutSession(completed), '/workout/workout-1');
    expect(AppRoutes.forWorkoutSession(finishing), '/summary/workout-1');
    expect(AppRoutes.forWorkoutSession(anomaly), '/workout/workout-1');
  });

  testWidgets('wrong-phase deep link redirects to durable canonical route',
      (tester) async {
    final active = WorkoutMachine.start(
      id: 'workout-1',
      draft: oneSetDraft(),
      nowUtc: _instant,
    );
    final harness = await pumpWorkout(
      tester,
      session: active,
      initialLocation: '/summary/workout-1',
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/workout/workout-1',
    );
    expect(find.byKey(const ValueKey('workout-workout-1')), findsOneWidget);
  });

  testWidgets('time anomaly confirms through controller then restores phase',
      (tester) async {
    final active = WorkoutMachine.start(
      id: 'workout-1',
      draft: oneSetDraft(),
      nowUtc: _instant,
    );
    final anomaly = WorkoutMachine.transition(
      active,
      const SelectSet('s1'),
      _instant.subtract(const Duration(seconds: 1)),
    );
    final harness = await pumpWorkout(tester, session: anomaly);

    expect(find.byKey(const ValueKey('time-anomaly')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-time')));
    await _waitFor(
      tester,
      () => harness.controller.state.session?.phase == WorkoutPhase.active,
    );
    expect(find.byKey(const ValueKey('workout-workout-1')), findsOneWidget);
  });

  testWidgets('system back preserves session and Home resumes it',
      (tester) async {
    final session = WorkoutMachine.start(
      id: 'workout-1',
      draft: oneSetDraft(),
      nowUtc: _instant,
    );
    final harness = await pumpWorkout(tester, session: session);

    await tester.binding.handlePopRoute();
    await _waitForFinder(tester, find.text(AppStrings.resumeWorkout));
    expect(harness.controller.state.session?.id, 'workout-1');
    expect(find.text(AppStrings.resumeWorkout), findsOneWidget);

    await tester.tap(find.text(AppStrings.resumeWorkout));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/workout/workout-1',
    );
  });

  for (final entry in [
    ('rest', _restingSession(), WorkoutPhase.resting),
    ('summary', _finishingSession(), WorkoutPhase.finishing),
  ]) {
    testWidgets('system back from ${entry.$1} preserves unfinished state',
        (tester) async {
      final harness = await pumpWorkout(tester, session: entry.$2);
      final revision = harness.controller.state.session!.revision;

      await tester.binding.handlePopRoute();
      await _waitForFinder(tester, find.text(AppStrings.resumeWorkout));

      expect(harness.controller.state.session!.phase, entry.$3);
      expect(harness.controller.state.session!.revision, revision);
      expect(
        (await tester.runAsync(
          () => harness.repository.findUnfinished(),
        ))!
            .phase,
        entry.$3,
      );
    });
  }

  for (final recovery in [
    ('resting', _restingSession(), '/rest/workout-1', 'rest-workout-1'),
    (
      'completedPaused',
      _completedPausedSession(),
      '/workout/workout-1',
      'workout-workout-1',
    ),
    (
      'finishing',
      _finishingSession(),
      '/summary/workout-1',
      'summary-workout-1'
    ),
  ]) {
    testWidgets('Home resumes ${recovery.$1} at its canonical route',
        (tester) async {
      final harness = await pumpWorkout(
        tester,
        session: recovery.$2,
        initialLocation: '/home',
      );
      await _waitForFinder(tester, find.text(AppStrings.resumeWorkout));
      await tester.tap(find.text(AppStrings.resumeWorkout));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        recovery.$3,
      );
      await _waitForFinder(tester, find.byKey(ValueKey(recovery.$4)));
    });
  }

  testWidgets('Home resumes time anomaly into explicit confirmation',
      (tester) async {
    final active = WorkoutMachine.start(
      id: 'workout-1',
      draft: oneSetDraft(),
      nowUtc: _instant,
    );
    final anomaly = WorkoutMachine.transition(
      active,
      const SelectSet('s1'),
      _instant.subtract(const Duration(seconds: 1)),
    );
    final harness = await pumpWorkout(
      tester,
      session: anomaly,
      initialLocation: '/home',
    );
    await _waitForFinder(tester, find.text(AppStrings.resumeWorkout));
    await tester.tap(find.text(AppStrings.resumeWorkout));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/workout/workout-1',
    );
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('time-anomaly')),
    );
  });

  testWidgets('mismatched deep link returns Home with clear feedback',
      (tester) async {
    final session = WorkoutMachine.start(
      id: 'workout-1',
      draft: oneSetDraft(),
      nowUtc: _instant,
    );
    final harness = await pumpWorkout(
      tester,
      session: session,
      initialLocation: '/workout/missing',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(harness.router.routeInformationProvider.value.uri.path, '/home');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-screen')),
        matching: find.text(AppStrings.workoutUnavailable),
      ),
      findsOneWidget,
    );
    await settleHistory(tester);
  });

  testWidgets('deleted session deep link falls back once with clear feedback',
      (tester) async {
    final harness = await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: oneSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.runAsync(harness.controller.discard);
    harness.router.go('/workout/workout-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(harness.router.routeInformationProvider.value.uri.path, '/home');
    expect(find.text(AppStrings.workoutUnavailable), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(harness.router.routeInformationProvider.value.uri.path, '/home');
    await settleHistory(tester);
  });

  testWidgets('saved session deep link falls back once with clear feedback',
      (tester) async {
    final harness = await pumpWorkout(tester, session: _finishingSession());
    await tester.runAsync(() => harness.controller.save(note: 'done'));
    harness.router.go('/summary/workout-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(harness.router.routeInformationProvider.value.uri.path, '/home');
    expect(find.text(AppStrings.workoutUnavailable), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(harness.router.routeInformationProvider.value.uri.path, '/home');
    await settleHistory(tester);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('workout fits $width width at $scale text scale',
          (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(
          tester.platformDispatcher.clearTextScaleFactorTestValue,
        );
        final session = WorkoutMachine.start(
          id: 'workout-1',
          draft: twoSetDraft(),
          nowUtc: _instant,
        );
        await pumpWorkout(tester, session: session);
        tester.view.physicalSize = Size(width, 844);
        await tester.pump();

        expect(tester.takeException(), isNull);
        for (final key in const [
          'adjust-edit',
          'adjust-skip',
          'adjust-add',
          'primary-set-action',
          'end-workout',
          'set-row-s1',
        ]) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        if (width == 390 && scale == 1) {
          await _captureWorkout(tester, 'workout_390_1.0');
        }
      });

      for (final entry in [
        ('rest', _restingSession()),
        ('summary', _finishingSession()),
      ]) {
        testWidgets('${entry.$1} fits $width width at $scale text scale',
            (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(
            tester.platformDispatcher.clearTextScaleFactorTestValue,
          );
          await pumpWorkout(tester, session: entry.$2);
          tester.view.physicalSize = Size(width, 844);
          await tester.pump();
          expect(tester.takeException(), isNull);
          final key = entry.$1 == 'rest' ? 'start-next-set' : 'save-summary';
          final bounds = tester.getRect(find.byKey(ValueKey(key)));
          expect(bounds.height, greaterThanOrEqualTo(48));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(width));
          expect(bounds.bottom, lessThanOrEqualTo(844));
          if (entry.$1 == 'rest') {
            _expectTapTarget(tester, 'rest-set-s2', width);
          }
        });
      }

      testWidgets('completed pause fits $width width at $scale text scale',
          (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(
          tester.platformDispatcher.clearTextScaleFactorTestValue,
        );
        await pumpWorkout(tester, session: _completedPausedSession());
        tester.view.physicalSize = Size(width, 844);
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final key in const [
          'adjust-edit',
          'adjust-skip',
          'adjust-add',
          'add-training',
          'finish-workout',
        ]) {
          _expectTapTarget(tester, key, width);
        }
      });

      testWidgets('zero-completed guard fits $width width at $scale text scale',
          (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(
          tester.platformDispatcher.clearTextScaleFactorTestValue,
        );
        await pumpWorkout(tester, session: _zeroCompletedSession());
        tester.view.physicalSize = Size(width, 844);
        await tester.pump();
        expect(tester.takeException(), isNull);
        _expectTapTarget(tester, 'add-training', width);
        _expectTapTarget(tester, 'discard-empty-workout', width);
        expect(find.byKey(const ValueKey('finish-workout')), findsNothing);
      });

      testWidgets('early end fits $width width at $scale text scale',
          (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(
          tester.platformDispatcher.clearTextScaleFactorTestValue,
        );
        await pumpWorkout(tester, session: _restingSession());
        tester.view.physicalSize = Size(width, 844);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('end-rest-workout')));
        await tester.pump();
        await tester.pump(WorkoutSkin.sheetDuration);
        expect(tester.takeException(), isNull);
        for (final key in const [
          'end-and-save',
          'continue-training',
          'discard-workout',
        ]) {
          await tester.ensureVisible(find.byKey(ValueKey(key)));
          await tester.pump();
          _expectTapTarget(tester, key, width);
        }
        await tester.tap(find.byKey(const ValueKey('discard-workout')));
        await tester.pump();
        for (final key in const ['cancel-discard', 'confirm-discard']) {
          _expectTapTarget(tester, key, width);
        }
        await tester.tap(find.byKey(const ValueKey('cancel-discard')));
        await tester.pump();
      });

      testWidgets('adjustment tabs fit $width width at $scale text scale',
          (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(
          tester.platformDispatcher.clearTextScaleFactorTestValue,
        );
        await pumpWorkout(
          tester,
          session: WorkoutMachine.start(
            id: 'workout-1',
            draft: _threeExerciseDraft(),
            nowUtc: _instant,
          ),
        );
        tester.view.physicalSize = Size(width, 844);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('adjust-edit')));
        await tester.pump();
        await tester.pump(WorkoutSkin.sheetDuration);
        for (final key in const [
          'adjust-tab-edit',
          'adjust-tab-skip',
          'adjust-tab-add',
        ]) {
          _expectTapTarget(tester, key, width);
        }
        _expectTapTarget(tester, 'confirm-edit', width);
        await tester.tap(find.byKey(const ValueKey('adjust-tab-skip')));
        await tester.pump();
        _expectTapTarget(tester, 'skip-set', width);
        _expectTapTarget(tester, 'skip-exercise', width);
        await tester.tap(find.byKey(const ValueKey('adjust-tab-add')));
        await tester.pump();
        for (final key in const [
          'add-exercise',
          'add-set',
          'delete-set',
          'move-exercise-earlier',
          'move-exercise-later',
        ]) {
          _expectTapTarget(tester, key, width);
        }
        await tester.tap(find.byKey(const ValueKey('add-exercise')));
        await tester.pump();
        await tester.pump(WorkoutSkin.sheetDuration);
        await _waitForFinder(
          tester,
          find.byKey(const ValueKey('picker-exercise-picker-x')),
        );
        for (final key in const [
          'exercise-search',
          'filter-category-',
          'filter-equipment-',
          'picker-exercise-picker-x',
        ]) {
          _expectTapTarget(tester, key, width);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('adjustment and summary remain usable with keyboard open',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    tester.view.physicalSize = const Size(360, 844);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('adjust-edit')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    await tester.showKeyboard(find.byKey(const ValueKey('edit-reps')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-edit')));
    expect(tester.takeException(), isNull);
    _expectTapTarget(tester, 'confirm-edit', 360);
  });

  testWidgets('summary note remains usable with keyboard open', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpWorkout(tester, session: _finishingSession());
    tester.view.physicalSize = const Size(360, 844);
    await tester.pump();
    await tester.showKeyboard(find.byKey(const ValueKey('summary-note')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    _expectTapTarget(tester, 'save-summary', 360);
    _expectTapTarget(tester, 'continue-workout', 360);
  });

  testWidgets('captures rest host evidence', (tester) async {
    await pumpWorkout(tester, session: _restingSession());
    await _captureWorkout(tester, 'rest_390_1.0');
  });

  testWidgets('captures completed paused host evidence', (tester) async {
    final harness =
        await pumpWorkout(tester, session: _completedPausedSession());
    await tester.tap(find.byKey(const ValueKey('add-training')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-set')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.exercises.single.sets.length == 2,
    );
    final pending =
        harness.controller.state.session!.exercises.single.sets.last;
    await tester.tap(find.byKey(ValueKey('set-row-${pending.id}')));
    await _waitFor(
      tester,
      () => harness.controller.state.session!.selectedSetId == pending.id,
    );
    await tester.pump(WorkoutSkin.sheetDuration);
    await _captureWorkout(tester, 'completed_paused_390_1.0');
  });

  testWidgets('captures zero-completed guard host evidence', (tester) async {
    await pumpWorkout(tester, session: _zeroCompletedSession());
    await _captureWorkout(tester, 'zero_completed_390_1.0');
  });

  testWidgets('captures active-set pulse host evidence', (tester) async {
    await pumpWorkout(tester, session: oneSetSessionInProgress());
    await tester.pump(const Duration(milliseconds: 630));
    await _captureWorkout(tester, 'active_set_390_1.0');
  });

  testWidgets('captures early-end host evidence', (tester) async {
    await pumpWorkout(tester, session: _restingSession());
    await tester.tap(find.byKey(const ValueKey('end-rest-workout')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    await _captureWorkout(tester, 'early_end_390_1.0');
  });

  testWidgets('captures adjustment host evidence', (tester) async {
    final session = WorkoutMachine.start(
      id: 'workout-1',
      draft: twoSetDraft(),
      nowUtc: _instant,
    );
    await pumpWorkout(tester, session: session);
    await tester.tap(find.byKey(const ValueKey('adjust-edit')));
    await tester.pumpAndSettle();
    await _captureWorkout(tester, 'adjustment_390_1.0');
  });

  testWidgets('captures adjustment skip host evidence', (tester) async {
    await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('adjust-skip')));
    await tester.pumpAndSettle();
    await _captureWorkout(tester, 'adjustment_skip_390_1.0');
  });

  testWidgets('captures adjustment add and reorder host evidence',
      (tester) async {
    await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: _threeExerciseDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('adjust-add')));
    await tester.pumpAndSettle();
    await _captureWorkout(tester, 'adjustment_add_reorder_390_1.0');
  });

  testWidgets('captures shared picker host evidence', (tester) async {
    await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: twoSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('adjust-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-exercise')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('picker-exercise-picker-x')),
    );
    await _captureWorkout(tester, 'adjustment_picker_390_1.0');
  });

  testWidgets('captures discard dialog host evidence', (tester) async {
    await pumpWorkout(
      tester,
      session: WorkoutMachine.start(
        id: 'workout-1',
        draft: oneSetDraft(),
        nowUtc: _instant,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('end-workout')));
    await tester.pump();
    await tester.pump(WorkoutSkin.sheetDuration);
    await tester.ensureVisible(find.byKey(const ValueKey('discard-workout')));
    await tester.tap(find.byKey(const ValueKey('discard-workout')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _waitForFinder(
      tester,
      find.byKey(const ValueKey('confirm-discard')),
    );
    await _captureWorkout(tester, 'discard_dialog_390_1.0');
  });

  testWidgets('captures summary host evidence', (tester) async {
    await pumpWorkout(tester, session: _finishingSession());
    await _captureWorkout(tester, 'summary_390_1.0');
  });
}

Future<void> _captureWorkout(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(const Key('app-render')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final directory = Directory(
      '../.superpowers/sdd/2026-09-15-flutter-rewrite/task-9-ui',
    );
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data.buffer.asUint8List());
    image.dispose();
  });
}

void _expectTapTarget(WidgetTester tester, String key, double width) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  expect(
    rect.height + _layoutEpsilon,
    greaterThanOrEqualTo(48),
    reason: key,
  );
  expect(rect.left, greaterThanOrEqualTo(0), reason: key);
  expect(rect.right, lessThanOrEqualTo(width), reason: key);
  expect(rect.top, greaterThanOrEqualTo(0), reason: key);
  expect(rect.bottom, lessThanOrEqualTo(844), reason: key);
}

final class _FailOnceWorkoutRepository implements WorkoutRepository {
  _FailOnceWorkoutRepository(this.delegate);

  final WorkoutRepository delegate;
  bool failNextSave = false;
  bool failNextCompletedSave = false;
  bool failNextDiscard = false;
  String? completedNote;

  @override
  Future<void> create(WorkoutSession session) => delegate.create(session);

  @override
  Future<void> discard(String id) async {
    if (failNextDiscard) {
      failNextDiscard = false;
      throw const AppFailure(FailureCode.persistence);
    }
    await delegate.discard(id);
  }

  @override
  Future<WorkoutSession?> find(String id) => delegate.find(id);

  @override
  Future<WorkoutSession?> findUnfinished() => delegate.findUnfinished();

  @override
  Future<void> save(
    WorkoutSession session, {
    required int expectedRevision,
  }) async {
    if (failNextSave) {
      failNextSave = false;
      throw const AppFailure(FailureCode.persistence);
    }
    await delegate.save(session, expectedRevision: expectedRevision);
  }

  @override
  Future<void> saveCompleted(
    String id, {
    required String note,
    required int expectedRevision,
    DateTime? endedAtUtc,
  }) async {
    completedNote = note;
    if (failNextCompletedSave) {
      failNextCompletedSave = false;
      throw const AppFailure(FailureCode.persistence);
    }
    await delegate.saveCompleted(
      id,
      note: note,
      expectedRevision: expectedRevision,
      endedAtUtc: endedAtUtc,
    );
  }
}
