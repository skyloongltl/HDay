import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/history/data/sqlite_history_repository.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan.dart';
import 'package:fitness_counter/features/plans/domain/plan_day.dart';
import 'package:fitness_counter/features/plans/domain/plan_revision.dart';
import 'package:fitness_counter/features/today/data/sqlite_today_repository.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/persistence_fixtures.dart';
import '../../../support/test_database.dart';

void main() {
  final date = LocalDate(2026, 9, 15);

  test('merges different cycles by priority then default order', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final plans = SqlitePlanRepository(db);
    final startsOn = LocalDate(2026, 9, 13);
    await plans.save(
      _plan('low', priority: 1, order: 5),
      _revision('low', startsOn, cycleDays: 2),
    );
    await plans.save(
      _plan('first', priority: 1, order: 1),
      _revision('first', startsOn, cycleDays: 3),
    );
    await plans.save(
      _plan('high', priority: 2, order: 9),
      _revision('high', startsOn, cycleDays: 4, orderedPairOnDay: 3),
    );

    final overview = await SqliteTodayRepository(db).load(date);

    expect(
      overview.scheduledDays.map((day) => day.plan.id),
      ['high', 'first', 'low'],
    );
    expect(
      overview.scheduledDays.map((day) => day.day.dayNumber),
      [3, 3, 1],
    );
    expect(
      overview.mergedExercises.map((item) => item.exercise.exerciseId),
      ['high-second-x', 'high-first-x', 'first-x', 'low-x'],
    );
    expect(
      overview.mergedExercises[1].exercise.sets.map((set) => set.id),
      ['high-first-s2', 'high-first-s1'],
    );
  });

  test('projects every unfinished phase and real saved statistics', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final workouts = SqliteWorkoutRepository(db);
    final today = SqliteTodayRepository(db);
    for (final phase
        in WorkoutPhase.values.where((p) => p != WorkoutPhase.saved)) {
      await workouts.create(newSession().copyWith(phase: phase));
      expect((await today.load(date)).unfinishedSession!.phase, phase);
      await workouts.discard('w1');
    }
    await persistCompleted(workouts, date: date);
    final overview = await today.load(date);
    expect(overview.savedCompletedSets, 1);
    expect(overview.fitnessDayStats.total, 1);
    expect(overview.fitnessDayStats.week, 1);
    expect(overview.fitnessDayStats.month, 1);
  });

  test('distinguishes rest plus training, all-rest, disabled, and expired',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final plans = SqlitePlanRepository(db);
    await plans.save(
      _plan('training', priority: 0, order: 0),
      _revision('training', date),
    );
    await plans.save(
      _plan('rest', priority: 1, order: 1),
      _revision('rest', date, rest: true),
    );
    var overview = await SqliteTodayRepository(db).load(date);
    expect(overview.scheduledDays, hasLength(2));
    expect(overview.isAllRest, isFalse);
    expect(overview.mergedExercises, hasLength(1));

    await plans.setEnabled('training', false);
    overview = await SqliteTodayRepository(db).load(date);
    expect(overview.isAllRest, isTrue);
    expect(overview.mergedExercises, isEmpty);

    await plans.setEnabled('rest', false);
    await plans.save(
      _plan('expired', priority: 0, order: 2),
      _revision(
        'expired',
        LocalDate(2026, 9, 13),
        mode: PlanMode.dateRange,
        endDate: LocalDate(2026, 9, 14),
      ),
    );
    overview = await SqliteTodayRepository(db).load(date);
    expect(overview.scheduledDays, isEmpty);
    expect(overview.isAllRest, isFalse);
  });

  test('calendar and Today share the all-rest schedule projection', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    await SqlitePlanRepository(db).save(
      _plan('rest', priority: 0, order: 0),
      _revision('rest', date, rest: true),
    );

    final today = await SqliteTodayRepository(db).load(date);
    final calendar =
        await SqliteHistoryRepository(db).month(LocalDate(2026, 9, 1));

    expect(today.isAllRest, isTrue);
    expect(today.mergedExercises, isEmpty);
    expect(calendar[14].hasPlan, isTrue);
    expect(calendar[14].isAllRest, isTrue);
  });
}

Plan _plan(String id, {required int priority, required int order}) => Plan(
      id: id,
      name: id,
      enabled: true,
      priority: priority,
      defaultOrder: order,
      createdAt: DateTime.utc(2026, 9),
      updatedAt: DateTime.utc(2026, 9),
    );

PlanRevision _revision(
  String id,
  LocalDate date, {
  int cycleDays = 1,
  bool rest = false,
  PlanMode mode = PlanMode.infinite,
  LocalDate? endDate,
  int? orderedPairOnDay,
}) =>
    PlanRevision(
      id: '$id-r',
      planId: id,
      effectiveFrom: date,
      cycleAnchorDate: date,
      cycleDays: cycleDays,
      mode: mode,
      endDate: endDate,
      days: [
        for (var index = 0; index < cycleDays; index++)
          PlanDay(
            id: '$id-d$index',
            dayNumber: index + 1,
            name: 'D${index + 1}',
            isRest: rest,
            exercises: rest
                ? const []
                : orderedPairOnDay == index + 1
                    ? [
                        PlanExercise(
                          id: '$id-second-e',
                          exerciseId: '$id-second-x',
                          nameSnapshot: '$id second',
                          note: '',
                          targetRestSeconds: 60,
                          order: 1,
                          sets: [
                            PlanSet(
                              id: '$id-second-s1',
                              order: 0,
                              plannedWeight: 20,
                              unit: WeightUnit.kg,
                              plannedReps: 5,
                            ),
                          ],
                        ),
                        PlanExercise(
                          id: '$id-first-e',
                          exerciseId: '$id-first-x',
                          nameSnapshot: '$id first',
                          note: '',
                          targetRestSeconds: 60,
                          order: 0,
                          sets: [
                            PlanSet(
                              id: '$id-first-s2',
                              order: 1,
                              plannedWeight: 12,
                              unit: WeightUnit.kg,
                              plannedReps: 6,
                            ),
                            PlanSet(
                              id: '$id-first-s1',
                              order: 0,
                              plannedWeight: 10,
                              unit: WeightUnit.kg,
                              plannedReps: 8,
                            ),
                          ],
                        ),
                      ]
                    : [
                        PlanExercise(
                          id: '$id-e',
                          exerciseId: '$id-x',
                          nameSnapshot: id,
                          note: '',
                          targetRestSeconds: 60,
                          order: 0,
                          sets: [
                            PlanSet(
                              id: '$id-s',
                              order: 0,
                              plannedWeight: 10,
                              unit: WeightUnit.kg,
                              plannedReps: 8,
                            ),
                          ],
                        ),
                      ],
          ),
      ],
    );
