import 'dart:io';

import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/history/application/history_controller.dart';
import 'package:fitness_counter/features/history/application/history_providers.dart';
import 'package:fitness_counter/features/history/data/sqlite_history_repository.dart';
import 'package:fitness_counter/features/history/domain/history_models.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan_day.dart';
import 'package:fitness_counter/features/settings/data/sqlite_settings_repository.dart';
import 'package:fitness_counter/features/settings/domain/app_settings.dart';
import 'package:fitness_counter/features/today/application/today_providers.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/fake_clock.dart';
import '../../../support/history_test_support.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/test_database.dart';

ExerciseRecord exerciseRecord({
  required WeightUnit unit,
  required double? weight,
  required int reps,
  int day = 15,
  int minute = 0,
}) =>
    ExerciseRecord(
      sessionId: 'session-$minute',
      setId: 'set-$minute',
      exerciseId: 'bench-press',
      date: LocalDate(2026, 9, day),
      completedAt: DateTime.utc(2026, 9, day, 8, minute),
      unit: unit,
      weight: weight,
      reps: reps,
    );

void main() {
  test(
      'real saved logs exclude skipped pending and completed-but-unsaved sets across units',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    await savePerformanceSession(
      db,
      id: 'kg',
      start: DateTime.utc(2026, 9, 15, 1),
    );
    await savePerformanceSession(
      db,
      id: 'lb',
      start: DateTime.utc(2026, 9, 15, 2),
      unit: WeightUnit.lb,
      weight: 80,
      reps: 10,
    );
    final workouts = SqliteWorkoutRepository(db);
    var active = newSession(id: 'unsaved');
    await workouts.create(active);
    active =
        WorkoutMachine.transition(active, const StartSet('s1'), trainingTime);
    active = WorkoutMachine.transition(
      active,
      const CompleteSet('s1', actualWeight: 900, actualReps: 20),
      trainingTime.add(const Duration(seconds: 20)),
    );
    await workouts.save(active, expectedRevision: 0);
    final records =
        await SqliteHistoryRepository(db).exerciseRecords('bench-press');
    expect(records.map((r) => r.sessionId), ['lb', 'kg']);
    expect(records.map((r) => r.setId), ['s1', 's1']);
    final summary = ExerciseHistorySummary.fromRecords(records);
    expect(summary.bestByUnit[WeightUnit.kg]!.weight, 40);
    expect(summary.bestByUnit[WeightUnit.lb]!.weight, 80);
    expect(summary.trend(WeightUnit.kg).single.weight, 40);
    expect(
      (await SqliteHistoryRepository(db).day(LocalDate(2026, 9, 15)))
          .map((s) => s.id),
      ['kg', 'lb', 'unsaved'],
    );
  });
  test('unit-specific personal best never compares kg with lb', () {
    final summary = ExerciseHistorySummary.fromRecords([
      exerciseRecord(unit: WeightUnit.kg, weight: 40, reps: 8),
      exerciseRecord(unit: WeightUnit.lb, weight: 80, reps: 10),
    ]);
    expect(summary.bestByUnit[WeightUnit.kg]!.weight, 40);
    expect(summary.bestByUnit[WeightUnit.lb]!.weight, 80);
  });
  test(
      'best ties use reps then latest time; unweighted uses reps; trends stay chronological and isolated',
      () {
    final summary = ExerciseHistorySummary.fromRecords(
      [
        exerciseRecord(unit: WeightUnit.kg, weight: 40, reps: 8, minute: 1),
        exerciseRecord(unit: WeightUnit.kg, weight: 40, reps: 10, minute: 2),
        exerciseRecord(unit: WeightUnit.kg, weight: 40, reps: 10, minute: 3),
        exerciseRecord(
          unit: WeightUnit.kg,
          weight: 35,
          reps: 12,
          day: 14,
        ),
        exerciseRecord(unit: WeightUnit.lb, weight: 100, reps: 20),
        exerciseRecord(unit: WeightUnit.bodyweight, weight: 500, reps: 8),
        exerciseRecord(
          unit: WeightUnit.bodyweight,
          weight: null,
          reps: 12,
          minute: 1,
        ),
        exerciseRecord(unit: WeightUnit.none, weight: null, reps: 30),
      ].reversed.toList(),
    );
    expect(summary.bestByUnit[WeightUnit.kg]!.setId, 'set-3');
    expect(summary.bestByUnit[WeightUnit.bodyweight]!.reps, 12);
    expect(summary.bestByUnit[WeightUnit.none]!.reps, 30);
    expect(
      summary.trend(WeightUnit.kg).map((r) => [r.date.day, r.weight]),
      [
        [14, 35],
        [15, 40],
      ],
    );
    expect(ExerciseHistorySummary.fromRecords([]).bestByUnit, isEmpty);
  });
  test(
      'month grid handles leap February, cross-year changes and both week starts',
      () {
    expect(
      HistoryController.shiftMonth(LocalDate(2026, 12, 31), 1),
      LocalDate(2027, 1, 1),
    );
    expect(
      HistoryController.shiftMonth(LocalDate(2027, 1, 1), -1),
      LocalDate(2026, 12, 1),
    );
    final monday =
        HistoryController.monthCells(LocalDate(2024, 2, 1), WeekStart.monday);
    final sunday =
        HistoryController.monthCells(LocalDate(2024, 2, 1), WeekStart.sunday);
    expect(monday.take(3), everyElement(isNull));
    expect(monday[3], LocalDate(2024, 2, 1));
    expect(sunday[4], LocalDate(2024, 2, 1));
    expect(monday.whereType<LocalDate>(), hasLength(29));
    expect(monday.length, 35);
  });
  test(
      'controller queries coexisting saved/planned, unfinished and all-rest facts using persisted week start',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final plans = SqlitePlanRepository(db);
    final revision =
        catalogRevision(effectiveFrom: LocalDate(2026, 9, 15), cycleDays: 2);
    await plans.save(
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
    await persistCompleted(SqliteWorkoutRepository(db));
    await SqliteWorkoutRepository(db)
        .create(newSession(id: 'unfinished', date: LocalDate(2026, 9, 16)));
    await SqliteSettingsRepository(db)
        .save(AppSettings(weekStart: WeekStart.sunday));
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((_) async => db),
        clockProvider
            .overrideWithValue(FakeClock(DateTime.utc(2026, 9, 15, 8))),
      ],
    );
    addTearDown(container.dispose);
    final view = await container.read(historyControllerProvider.future);
    expect(view.weekStart, WeekStart.sunday);
    expect(view.month[14].hasSavedWorkout, isTrue);
    expect(view.month[14].hasPlan, isTrue);
    expect(view.month[15].hasUnfinishedWorkout, isTrue);
    expect(view.month[15].isAllRest, isTrue);
    expect(view.sessions.single.id, 'w1');
    await container
        .read(historyControllerProvider.notifier)
        .loadDay(LocalDate(2026, 9, 16));
    expect(
      container.read(historyControllerProvider).requireValue.sessions.single.id,
      'unfinished',
    );
  });
  test(
      'actual correction reloads committed day month exercise and today; last deletion removes statistical day',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    await persistCompleted(SqliteWorkoutRepository(db), id: 'a');
    await persistCompleted(SqliteWorkoutRepository(db), id: 'b');
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((_) async => db),
        clockProvider
            .overrideWithValue(FakeClock(DateTime.utc(2026, 9, 15, 8))),
      ],
    );
    addTearDown(container.dispose);
    await container.read(historyControllerProvider.future);
    final controller = container.read(historyControllerProvider.notifier);
    expect(
      (await container.read(todayOverviewProvider.future))
          .fitnessDayStats
          .total,
      1,
    );
    expect(
      (await container
              .read(exerciseHistorySummaryProvider('bench-press').future))
          .bestByUnit[WeightUnit.kg]!
          .weight,
      22.5,
    );
    await controller.correctSet('a', 's1', weight: 45, reps: 9);
    final set = container
        .read(historyControllerProvider)
        .requireValue
        .sessions
        .first
        .exercises
        .single
        .sets
        .first;
    expect([set.actualWeight, set.actualReps], [45, 9]);
    expect(
      [set.plannedWeight, set.plannedReps, set.unit],
      [20, 8, WeightUnit.kg],
    );
    expect(
      (await container
              .read(exerciseHistorySummaryProvider('bench-press').future))
          .bestByUnit[WeightUnit.kg]!
          .weight,
      45,
    );
    await controller.deleteSession('a');
    expect(
      (await container.read(todayOverviewProvider.future))
          .fitnessDayStats
          .total,
      1,
    );
    await controller.deleteSession('b');
    expect(
      (await container.read(todayOverviewProvider.future))
          .fitnessDayStats
          .total,
      0,
    );
    expect(
      container
          .read(historyControllerProvider)
          .requireValue
          .month[14]
          .hasSavedWorkout,
      isFalse,
    );
    expect(
      container.read(historyControllerProvider).requireValue.sessions,
      isEmpty,
    );
    expect(
      (await container
              .read(exerciseHistorySummaryProvider('bench-press').future))
          .bestByUnit,
      isEmpty,
    );
  });
  test('failed correction leaves committed values visible and retry can save',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    await persistCompleted(SqliteWorkoutRepository(db));
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((_) async => db),
        clockProvider
            .overrideWithValue(FakeClock(DateTime.utc(2026, 9, 15, 8))),
      ],
    );
    addTearDown(container.dispose);
    await container.read(historyControllerProvider.future);
    await db.database.execute(
      "CREATE TRIGGER fail_history BEFORE UPDATE ON workout_sets BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
    );
    final controller = container.read(historyControllerProvider.notifier);
    expect(
      await controller.correctSet('w1', 's1', weight: 55, reps: 9),
      isFalse,
    );
    expect(
      container
          .read(historyControllerProvider)
          .requireValue
          .sessions
          .single
          .exercises
          .single
          .sets
          .first
          .actualWeight,
      22.5,
    );
    await db.database.execute('DROP TRIGGER fail_history');
    expect(
      await controller.correctSet('w1', 's1', weight: 55, reps: 9),
      isTrue,
    );
    expect(
      container
          .read(historyControllerProvider)
          .requireValue
          .sessions
          .single
          .exercises
          .single
          .sets
          .first
          .actualWeight,
      55,
    );
  });
  test(
      'note and full snapshots survive restart and source edits/deletions without hiding completed-only logs',
      () async {
    final directory = await Directory.systemTemp.createTemp('hday-history-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/history.sqlite';
    var db = await openTestDatabase(path: path);
    final plans = SqlitePlanRepository(db);
    final plan = catalogPlan(id: 'plan-1');
    final revision = catalogRevision(
      id: 'revision-1',
      planId: 'plan-1',
      effectiveFrom: LocalDate(2026, 9, 15),
    );
    await plans.save(plan, revision);
    await SqliteExerciseRepository(db)
        .save(catalogExercise(id: 'bench-press', name: '原动作'));
    await persistCompleted(SqliteWorkoutRepository(db));
    await SqliteWorkoutRepository(db).create(newSession(id: 'active'));
    await SqliteHistoryRepository(db).updateNote('w1', '修正备注');
    await plans.save(
      plan,
      revision.revised(
        id: 'new-revision',
        effectiveFrom: LocalDate(2026, 9, 16),
      ),
    );
    await SqliteExerciseRepository(db)
        .save(catalogExercise(id: 'bench-press', name: '已改名'));
    await plans.delete('plan-1');
    await SqliteExerciseRepository(db).delete('bench-press');
    await db.close();
    db = await openTestDatabase(path: path);
    addTearDown(db.close);
    final saved = (await SqliteWorkoutRepository(db).find('w1'))!;
    expect(saved.note, '修正备注');
    final exercise = saved.exercises.single;
    expect([
      exercise.nameSnapshot,
      exercise.sourcePlanName,
      exercise.sourceRevisionId,
      exercise.sourceDayName,
    ], [
      'Bench Press',
      'Strength',
      'revision-1',
      'Push',
    ]);
    final records =
        await SqliteHistoryRepository(db).exerciseRecords('bench-press');
    expect(records, hasLength(1));
    expect(records.single.setId, 's1');
    expect(
      (await SqliteHistoryRepository(db).month(LocalDate(2026, 9, 1)))[14]
          .hasSavedWorkout,
      isTrue,
    );
  });
}
