import 'dart:convert';

import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/data/app_database.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/core/platform/notification_gateway.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan.dart';
import 'package:fitness_counter/features/plans/domain/plan_day.dart';
import 'package:fitness_counter/features/today/application/today_providers.dart';
import 'package:fitness_counter/features/today/data/sqlite_today_repository.dart';
import 'package:fitness_counter/features/today/domain/today_repository.dart';
import 'package:fitness_counter/features/workout/application/rest_effects_controller.dart';
import 'package:fitness_counter/features/workout/application/workout_providers.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:fitness_counter/theme/app_theme.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../features/workout/presentation/workout_pages_test.dart'
    show pumpWorkout;
import 'catalog_fixtures.dart';
import 'fake_clock.dart';
import 'history_test_support.dart';
import 'pump_app.dart';
import 'test_database.dart';
import 'workout_fixtures.dart';

/// All records live in an isolated in-memory SQLite database. Production
/// repositories, controllers, routes and widgets perform every read/render.
final class Task13Screen {
  const Task13Screen(
    this.name,
    this.route,
    this.root,
    this.targets, {
    this.phase,
    this.empty = false,
    this.longContent = false,
  });
  final String name, route, root;
  final List<String> targets;
  final WorkoutPhase? phase;
  final bool empty;
  final bool longContent;
}

const task13Screens = [
  Task13Screen(
    'home_planned',
    '/home',
    'home-screen',
    ['today-primary-action'],
  ),
  Task13Screen(
    'plan_data',
    '/plan',
    'plan-screen',
    ['plan-search', 'plan-enabled-p1'],
  ),
  Task13Screen(
    'plan_create',
    '/create-plan',
    'create-plan-screen',
    ['plan-save', 'plan-primary-save'],
  ),
  Task13Screen(
    'plan_edit',
    '/edit-plan/p1',
    'create-plan-screen',
    ['plan-save', 'plan-primary-save'],
  ),
  Task13Screen(
    'plan_day',
    '/plan-edit/p1',
    'plan-edit-screen',
    ['plan-save', 'day-jump', 'day-add-exercise'],
  ),
  Task13Screen(
    'exercise_library',
    '/exercises',
    'exercises-screen',
    ['exercise-search'],
  ),
  Task13Screen(
    'exercise_create',
    '/exercise-create',
    'exercise-edit-screen',
    ['exercise-primary-save'],
  ),
  Task13Screen(
    'exercise_edit',
    '/exercise-edit/x1',
    'exercise-edit-screen',
    ['exercise-save'],
  ),
  Task13Screen(
    'exercise_detail',
    '/exercise-detail/x1',
    'exercise-detail-screen',
    ['exercise-detail-back'],
  ),
  Task13Screen(
    'pre_workout',
    '/pre-workout?free=false&date=2026-12-15',
    'pre-workout-screen',
    ['pre-workout-back', 'start-workout'],
  ),
  Task13Screen(
    'workout_active',
    '/workout/task13-active',
    'workout-task13-active',
    ['end-workout', 'primary-set-action'],
    phase: WorkoutPhase.active,
  ),
  Task13Screen(
    'rest',
    '/rest/task13-resting',
    'rest-task13-resting',
    ['end-rest-workout', 'start-next-set'],
    phase: WorkoutPhase.resting,
  ),
  Task13Screen(
    'workout_paused',
    '/workout/task13-completedPaused',
    'workout-task13-completedPaused',
    ['end-workout', 'finish-workout', 'add-training'],
    phase: WorkoutPhase.completedPaused,
  ),
  Task13Screen(
    'summary',
    '/summary/task13-finishing',
    'summary-task13-finishing',
    ['save-summary'],
    phase: WorkoutPhase.finishing,
  ),
  Task13Screen(
    'time_anomaly',
    '/workout/task13-timeAnomaly',
    'time-anomaly',
    ['confirm-time'],
    phase: WorkoutPhase.timeAnomaly,
  ),
  Task13Screen(
    'calendar_december',
    '/calendar',
    'calendar-screen',
    ['calendar-previous', 'calendar-next', 'calendar-day-2026-12-15'],
  ),
  Task13Screen(
    'history_saved',
    '/history/2026-12-15',
    'history-day-detail',
    ['history-back', 'expand-session-history-a'],
  ),
  Task13Screen(
    'settings',
    '/settings',
    'settings-screen',
    ['setting-weight-unit', 'setting-default-rest', 'setting-screen-awake'],
  ),
];

const task13ExtraScreens = [
  Task13Screen(
    'home_active',
    '/home',
    'home-screen',
    ['today-primary-action'],
    phase: WorkoutPhase.active,
  ),
  Task13Screen(
    'plan_365_long',
    '/plan-edit/p1',
    'plan-edit-screen',
    ['plan-save', 'day-jump', 'day-add-exercise'],
    longContent: true,
  ),
  Task13Screen(
    'pre_workout_many',
    '/pre-workout?free=false&date=2026-12-15',
    'pre-workout-screen',
    ['pre-workout-back', 'start-workout'],
    longContent: true,
  ),
];

const task13EmptyHome = Task13Screen(
  'home_empty',
  '/home',
  'home-screen',
  ['today-primary-action'],
  empty: true,
);
final task13Date = LocalDate(2026, 12, 15);
final task13Instant = DateTime.utc(2026, 12, 15, 8);

Future<void> seedTask13(AppDatabase db, {bool longContent = false}) async {
  await SqliteExerciseRepository(db).save(catalogExercise(id: 'x1'));
  await SqliteExerciseRepository(db)
      .save(catalogExercise(id: 'x2', name: '杠铃深蹲'));
  final plan = catalogPlan();
  final revision = catalogRevision(
    effectiveFrom: task13Date,
    cycleDays: longContent ? 365 : 7,
  );
  await SqlitePlanRepository(db).save(
    longContent
        ? Plan(
            id: plan.id,
            name: '全年渐进力量训练与动作控制基础循环计划',
            enabled: plan.enabled,
            priority: plan.priority,
            defaultOrder: plan.defaultOrder,
            createdAt: plan.createdAt,
            updatedAt: plan.updatedAt,
          )
        : plan,
    longContent
        ? revision.revised(
            id: revision.id,
            days: [
              for (final day in revision.days)
                PlanDay(
                  id: day.id,
                  dayNumber: day.dayNumber,
                  name: day.name,
                  isRest: day.isRest,
                  exercises: day.dayNumber == 1
                      ? [
                          for (var i = 0; i < 8; i++)
                            PlanExercise(
                              id: 'long-$i',
                              exerciseId: 'x1',
                              nameSnapshot: '第${i + 1}项上斜哑铃卧推与胸部肌肉控制训练',
                              note: '',
                              targetRestSeconds: 90,
                              order: i,
                              sets: day.exercises.first.sets,
                            ),
                        ]
                      : [],
                ),
            ],
          )
        : revision,
  );
  await savePerformanceSession(
    db,
    id: 'history-a',
    start: DateTime.utc(2026, 12, 15, 1),
    exerciseId: 'x1',
    date: task13Date,
  );
}

WorkoutSession task13Session(WorkoutPhase phase) {
  var session = WorkoutMachine.start(
    id: 'task13-${phase.name}',
    draft: phase == WorkoutPhase.completedPaused
        ? oneSetDraft(date: task13Date)
        : twoSetDraft(date: task13Date),
    nowUtc: task13Instant,
  );
  session =
      WorkoutMachine.transition(session, const StartSet('s1'), task13Instant);
  if (phase == WorkoutPhase.timeAnomaly) {
    return WorkoutMachine.transition(
      session,
      const SelectSet('s1'),
      task13Instant.subtract(const Duration(seconds: 1)),
    );
  }
  if (phase == WorkoutPhase.active) return session;
  session = WorkoutMachine.transition(
    session,
    const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    task13Instant.add(const Duration(seconds: 30)),
  );
  if (phase == WorkoutPhase.finishing) {
    return WorkoutMachine.transition(
      session,
      const PrepareFinish(),
      task13Instant.add(const Duration(seconds: 40)),
    );
  }
  return session;
}

void task13Viewport(WidgetTester tester, double width, double scale) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<GoRouter> pumpTask13(
  WidgetTester tester,
  Task13Screen screen, {
  double width = 390,
  double scale = 1,
  bool waitForContent = true,
  TodayRepository Function(TodayRepository)? todayWrapper,
}) async {
  task13Viewport(tester, width, scale);
  late GoRouter router;
  if (screen.phase case final phase?) {
    final harness = await pumpWorkout(
      tester,
      session: task13Session(phase),
      initialLocation: screen.route,
    );
    router = harness.router;
    harness.clock.setUtc(
      harness.controller.state.session!.restStartedAt ?? task13Instant,
    );
    // The established Task9 harness sets 390. Restore and assert the requested
    // viewport before assessing responsive evidence.
    tester.view.physicalSize = Size(width, 844);
  } else {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    if (!screen.empty) {
      await tester
          .runAsync(() => seedTask13(db, longContent: screen.longContent));
    }
    router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: screen.route,
      waitForLoading: false,
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        clockProvider.overrideWithValue(FakeClock(task13Instant)),
        if (todayWrapper != null)
          todayRepositoryProvider.overrideWith(
            (_) async => todayWrapper(SqliteTodayRepository(db)),
          ),
        // Host fixture for the existing permission status presentation; actual
        // Android permission requests remain Task14 acceptance.
        restEffectsStatusProvider.overrideWithValue(
          const RestEffectsStatus(
            permission: NotificationPermissionState(
              notificationsGranted: true,
              exactAlarmsGranted: true,
            ),
          ),
        ),
      ],
    );
  }
  if (waitForContent) {
    await settleTask13(tester, screen);
  } else {
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 25));
    }
  }
  expect(router.state.uri.toString(), screen.route);
  expect(tester.view.physicalSize.width / tester.view.devicePixelRatio, width);
  return router;
}

Future<void> settleTask13(WidgetTester tester, Task13Screen screen) async {
  // Native SQLite futures must finish outside the fake test clock, as in Task11.
  // Bounded pumps also settle route transitions without waiting on workout tickers.
  for (var i = 0; i < 30; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 25));
    if (i >= 14 &&
        find.byKey(ValueKey(screen.root)).evaluate().length == 1 &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  expect(
    find.byKey(ValueKey(screen.root)),
    findsOneWidget,
    reason: '${screen.route} must render its actual screen',
  );
  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason: '${screen.route} must finish loading',
  );
  expect(
    tester.takeException(),
    isNull,
    reason: '${screen.name} framework render/overflow exception',
  );
}

Future<void> assertTask13Targets(
  WidgetTester tester,
  Task13Screen screen,
  double width,
) async {
  final context = tester.element(find.byKey(ValueKey(screen.root)));
  final theme = AppTheme.of(context);
  // Literal reference colors come from the read-only React tokens.ts.
  expect(theme.page, const Color(0xFFF4F7FA));
  expect(theme.hero, const Color(0xFF19344C));
  expect(theme.primaryAction, const Color(0xFFC76F62));
  expect(theme.colors.outline, const Color(0xFFDFE7EC));
  final measurements = <String, List<double>>{};
  for (final key in screen.targets) {
    final target = find.byKey(ValueKey(key));
    expect(target, findsOneWidget, reason: '${screen.name} requires $key');
    await tester.ensureVisible(target);
    await tester.pump();
    final bounds = tester.getRect(target);
    measurements[key] = [bounds.left, bounds.top, bounds.width, bounds.height];
    expect(
      bounds.shortestSide,
      greaterThanOrEqualTo(48),
      reason: '${screen.name}/$key hit target',
    );
    expect(
      bounds.left,
      greaterThanOrEqualTo(0),
      reason: '${screen.name}/$key left edge',
    );
    expect(
      bounds.right,
      lessThanOrEqualTo(width),
      reason: '${screen.name}/$key right edge',
    );
    expect(
      bounds.top,
      greaterThanOrEqualTo(0),
      reason: '${screen.name}/$key top edge',
    );
    expect(
      bounds.bottom,
      lessThanOrEqualTo(844),
      reason: '${screen.name}/$key bottom edge',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: '${screen.name}/$key overflow while scrolling',
    );
  }
  debugPrint('TASK13_BOUNDS ${jsonEncode({
        'screen': screen.name,
        'width': width,
        'scale': tester.platformDispatcher.textScaleFactor,
        'targets': measurements,
      })}');
}
