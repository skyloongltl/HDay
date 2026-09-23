import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/history/application/history_providers.dart';
import 'package:fitness_counter/features/history/data/sqlite_history_repository.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan_day.dart';
import 'package:fitness_counter/features/workout/application/workout_providers.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/fake_clock.dart';
import '../../../support/history_test_support.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/pump_app.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  setUpAll(loadHistoryFonts);
  testWidgets('calendar initial read failure stays visible and retries',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    var shouldFail = true;
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/calendar',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        historyRepositoryProvider.overrideWith((_) async {
          if (shouldFail) throw StateError('history unavailable');
          return SqliteHistoryRepository(db);
        }),
      ],
    );
    await settleHistory(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.retry), findsOneWidget);
    shouldFail = false;
    await tester.tap(find.text(AppStrings.retry));
    await settleHistory(tester);
    expect(find.byKey(const Key('calendar-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'calendar shows saved plus planned, unfinished and all-rest as separate facts',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(() async {
      final revision =
          catalogRevision(effectiveFrom: LocalDate(2026, 9, 15), cycleDays: 2);
      await SqlitePlanRepository(db).save(
        catalogPlan(),
        revision.revised(
          id: 'r1',
          days: [
            revision.days.first,
            PlanDay(
              id: 'rest',
              dayNumber: 2,
              name: '恢复',
              isRest: true,
              exercises: [],
            ),
          ],
        ),
      );
      await savePerformanceSession(
        db,
        id: 'saved',
        start: DateTime.utc(2026, 9, 15, 1),
      );
      await SqliteWorkoutRepository(db)
          .create(newSession(id: 'unfinished', date: LocalDate(2026, 9, 16)));
    });
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/calendar',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        clockProvider
            .overrideWithValue(FakeClock(DateTime.utc(2026, 9, 17, 8))),
      ],
    );
    await settleHistory(tester);
    expect(
      find.bySemanticsLabel(RegExp('2026-09-15.*已保存训练.*计划训练')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('2026-09-16.*未结束训练.*休息日')),
      findsOneWidget,
    );
    await captureHistory(tester, 'calendar_all_states_390_1.0');
    await tester.tap(find.byKey(const Key('calendar-day-2026-09-16')));
    await settleHistory(tester);
    await captureHistory(tester, 'calendar_unfinished_390_1.0');
  });
  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'calendar history correction fit $width text $scale with 48px actions',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final db = (await tester.runAsync(openTestDatabase))!;
        addTearDown(db.close);
        final router = await pumpFitnessApp(
          tester,
          database: db,
          initialLocation: '/calendar',
          overrides: [
            themeDefinitionsProvider
                .overrideWith((_) async => [breathRhythmDefinition]),
            clockProvider
                .overrideWithValue(FakeClock(DateTime.utc(2026, 9, 15, 8))),
          ],
        );
        await settleHistory(tester);
        await captureHistory(tester, 'calendar_empty_${width.toInt()}_$scale');
        expect(
          tester
              .getSize(find.byKey(const Key('calendar-day-2026-09-15')))
              .shortestSide,
          greaterThanOrEqualTo(48),
        );
        await tester.runAsync(() async {
          await SqlitePlanRepository(db).save(
            catalogPlan(),
            catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
          );
          await SqliteExerciseRepository(db)
              .save(catalogExercise(id: 'bench-press', name: '杠铃卧推'));
          await savePerformanceSession(
            db,
            id: 'a',
            start: DateTime.utc(2026, 9, 15, 1),
          );
          await savePerformanceSession(
            db,
            id: 'b',
            start: DateTime.utc(2026, 9, 15, 10),
            weight: 45,
          );
        });
        router.go('/exercises');
        await settleHistory(tester);
        router.go('/calendar');
        await settleHistory(tester);
        expect(
          find.byKey(const Key('planned-marker-2026-09-15')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('2026-09-15.*已保存训练.*计划训练')),
          findsOneWidget,
        );
        await captureHistory(
          tester,
          'calendar_saved_planned_${width.toInt()}_$scale',
        );
        router.go('/history/2026-09-15');
        await settleHistory(tester);
        await captureHistory(
          tester,
          'history_expanded_${width.toInt()}_$scale',
        );
        await tester.tap(find.byKey(const Key('expand-session-a')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('session-b')), findsOneWidget);
        await captureHistory(
          tester,
          'history_two_sessions_${width.toInt()}_$scale',
        );
        await tester.tap(find.byKey(const Key('expand-session-a')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('correct-a-s1')));
        expect(
          tester.getSize(find.byKey(const Key('correct-a-s1'))).shortestSide,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byKey(const Key('correct-a-s1')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('history-actual-weight')),
          '47.5',
        );
        await captureHistory(
          tester,
          'correction_sheet_${width.toInt()}_$scale',
        );
        await tester.tap(find.byKey(const Key('history-correction-save')));
        await settleHistory(tester);
        expect(find.textContaining('47.5 kg'), findsWidgets);
        await captureHistory(
          tester,
          'correction_saved_${width.toInt()}_$scale',
        );
        expect(tester.takeException(), isNull);
        // Check notes through the real controller/UI, including editable retained draft.
        await tester.scrollUntilVisible(
          find.byKey(const Key('history-note-a')),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(
          find.byKey(const Key('history-note-a')),
          '新的训练备注',
        );
        await tester.ensureVisible(find.byKey(const Key('save-note-a')));
        await tester.tap(find.byKey(const Key('save-note-a')));
        await settleHistory(tester);
        expect(
          (await tester.runAsync(() => SqliteWorkoutRepository(db).find('a')))!
              .note,
          '新的训练备注',
        );
      });
    }
  }
  testWidgets(
      'Task9 summary save opens real history for fixed workout date after midnight',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 8));
    final router = await pumpFitnessApp(
      tester,
      database: db,
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        clockProvider.overrideWithValue(clock),
      ],
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final controller = container.read(workoutControllerProvider.notifier);
    String? id;
    await tester.runAsync(() async {
      id = await controller.start(oneSetDraft(date: LocalDate(2026, 9, 14)));
      await controller.dispatch(const StartSet('s1'));
      clock.advance(const Duration(seconds: 30));
      await controller
          .dispatch(const CompleteSet('s1', actualWeight: 40, actualReps: 8));
      await controller.dispatch(const PrepareFinish());
    });
    router.go('/summary/$id');
    await settleHistory(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('summary-note')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('summary-note')), '跨日后保存');
    await tester.ensureVisible(find.byKey(const Key('save-summary')));
    await tester.tap(find.byKey(const Key('save-summary')));
    await settleHistory(tester);
    expect(router.state.uri.path, '/history/2026-09-14');
    expect(find.byKey(const Key('history-day-detail')), findsOneWidget);
    expect(find.byKey(Key('session-$id')), findsOneWidget);
    expect(
      (await tester.runAsync(
        () => SqliteHistoryRepository(db).day(LocalDate(2026, 9, 15)),
      ))!,
      isEmpty,
    );
  });
  testWidgets(
      'actual correction sheet keeps failed draft and commits retry without changing prescription',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(() => persistCompleted(SqliteWorkoutRepository(db)));
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/history/2026-09-15',
    );
    expect(find.byKey(const Key('history-day-detail')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('correct-w1-s1')));
    await tester.tap(find.byKey(const Key('correct-w1-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('history-actual-weight')),
      '35',
    );
    await tester.enterText(find.byKey(const Key('history-actual-reps')), '10');
    await tester.runAsync(
      () => db.database.execute(
        "CREATE TRIGGER fail_correction BEFORE UPDATE ON workout_sets BEGIN SELECT RAISE(ABORT, 'fail'); END",
      ),
    );
    await tester.tap(find.byKey(const Key('history-correction-save')));
    await settleHistory(tester);
    expect(find.widgetWithText(TextField, '35'), findsOneWidget);
    expect(find.text(AppStrings.historyWriteFailed), findsOneWidget);
    expect(
      (await tester.runAsync(() => SqliteWorkoutRepository(db).find('w1')))!
          .exercises
          .single
          .sets
          .first
          .actualWeight,
      22.5,
    );
    await tester
        .runAsync(() => db.database.execute('DROP TRIGGER fail_correction'));
    await tester.tap(find.byKey(const Key('history-correction-save')));
    await settleHistory(tester);
    expect(find.byKey(const Key('history-actual-weight')), findsNothing);
    final set =
        (await tester.runAsync(() => SqliteWorkoutRepository(db).find('w1')))!
            .exercises
            .single
            .sets
            .first;
    expect([
      set.actualWeight,
      set.actualReps,
      set.plannedWeight,
      set.plannedReps,
      set.unit.code,
    ], [
      35,
      10,
      20,
      8,
      'kg',
    ]);
    expect(find.textContaining('35 kg'), findsWidgets);
  });
  testWidgets(
      'delete requires confirmation, failed write retains session, last success removes day',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(() => persistCompleted(SqliteWorkoutRepository(db)));
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/history/2026-09-15',
    );
    expect(find.byKey(const Key('history-day-detail')), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-session-w1')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.deleteLastHistoryHint), findsOneWidget);
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-w1')), findsOneWidget);
    await tester.runAsync(
      () => db.database.execute(
        "CREATE TRIGGER fail_delete BEFORE DELETE ON workout_sessions BEGIN SELECT RAISE(ABORT, 'fail'); END",
      ),
    );
    await tester.tap(find.byKey(const Key('delete-session-w1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.confirmDelete));
    await settleHistory(tester);
    expect(find.byKey(const Key('session-w1')), findsOneWidget);
    expect(find.text(AppStrings.historyDeleteFailed), findsOneWidget);
    await tester
        .runAsync(() => db.database.execute('DROP TRIGGER fail_delete'));
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.confirmDelete));
    await settleHistory(tester);
    expect(find.byKey(const Key('session-w1')), findsNothing);
    expect(find.text(AppStrings.noDateHistory), findsOneWidget);
    await captureHistory(tester, 'deleted_last_session_390_1.0');
    expect(
      (await tester.runAsync(
        () => SqliteHistoryRepository(db)
            .stats(LocalDate(2026, 9, 15), weekStart: 1),
      ))!
          .total,
      0,
    );
  });
  testWidgets('calendar exposes real selectable days and cross-year navigation',
      (tester) async {
    await pumpFitnessApp(
      tester,
      initialLocation: '/calendar',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 12, 15))),
      ],
    );
    expect(find.byKey(const Key('calendar-day-2026-12-15')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-next')));
    await settleHistory(tester);
    expect(find.byKey(const Key('calendar-day-2027-01-01')), findsOneWidget);
  });

  testWidgets(
      'date history shows both saved sessions and immutable snapshot data',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(() async {
      await persistCompleted(SqliteWorkoutRepository(db), id: 'a');
      await persistCompleted(SqliteWorkoutRepository(db), id: 'b');
    });
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/history/2026-09-15',
    );
    expect(find.byKey(const Key('history-day-detail')), findsOneWidget);
    expect(find.byKey(const Key('session-a')), findsOneWidget);
    expect(find.textContaining('22.5'), findsWidgets);
    expect(find.textContaining('20'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('session-b')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('session-b')), findsOneWidget);
    expect(
      await tester.runAsync(() => SqliteWorkoutRepository(db).find('a')),
      isNotNull,
    );
  });
}
