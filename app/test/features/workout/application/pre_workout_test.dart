import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan_day.dart';
import 'package:fitness_counter/features/plans/domain/plan_revision.dart';
import 'package:fitness_counter/features/today/data/sqlite_today_repository.dart';
import 'package:fitness_counter/features/workout/application/pre_workout_controller.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/test_database.dart';

void main() {
  final date = LocalDate(2026, 9, 15);

  test('preparation edits never rewrite plan templates', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final plans = SqlitePlanRepository(db);
    await plans.save(
      catalogPlan(),
      catalogRevision(effectiveFrom: date),
    );
    final workouts = SqliteWorkoutRepository(db);
    final prepare = PreWorkoutController(
      todayRepository: SqliteTodayRepository(db),
    );
    addTearDown(prepare.dispose);

    await prepare.prepare(date: date, freeWorkout: false);
    prepare.updateSet('s1', weight: 25, reps: 10);
    prepare.addSet('pe1');
    prepare.reorderSets('pe1', const ['s1', 'pe1-set-2']);
    prepare.reorderExercises(const ['pe1']);

    expect(prepare.takeDraft().exercises.first.sets.first.plannedWeight, 25);
    expect(prepare.takeDraft().exercises.first.sets.first.plannedReps, 10);
    expect(
      (await plans.revisions('p1'))
          .first
          .days
          .first
          .exercises
          .first
          .sets
          .first
          .plannedReps,
      8,
    );
    expect(await workouts.findUnfinished(), isNull);
  });

  test('free workout starts empty and can add an exercise without a session',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final workouts = SqliteWorkoutRepository(db);
    final prepare = PreWorkoutController(
      todayRepository: SqliteTodayRepository(db),
    );
    addTearDown(prepare.dispose);

    await prepare.prepare(date: date, freeWorkout: true);
    prepare.addExercise(catalogExercise(id: 'free-exercise'));

    expect(prepare.draft.exercises.single.exerciseId, 'free-exercise');
    expect(prepare.draft.exercises.single.temporary, isTrue);
    expect(await workouts.findUnfinished(), isNull);
  });

  test('deleting a draft set reindexes remaining orders without persistence',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final plans = SqlitePlanRepository(db);
    await plans.save(catalogPlan(), catalogRevision(effectiveFrom: date));
    final prepare =
        PreWorkoutController(todayRepository: SqliteTodayRepository(db));
    addTearDown(prepare.dispose);
    await prepare.prepare(date: date, freeWorkout: false);
    prepare.addSet('pe1');
    prepare.deleteSet('s1');
    expect(prepare.draft.exercises.single.sets.map((set) => set.order), [0]);
    expect(prepare.draft.exercises.single.sets.single.id, 'pe1-set-2');
  });

  test('planned preparation snapshots catalog category and equipment',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    await SqliteExerciseRepository(db).save(
      Exercise(
        id: 'x1',
        name: '哑铃卧推',
        category: ExerciseCategory.chest,
        equipment: ExerciseEquipment.dumbbell,
        defaultUnit: WeightUnit.kg,
        note: '',
        createdAt: DateTime.utc(2026, 9),
        updatedAt: DateTime.utc(2026, 9),
      ),
    );
    await SqlitePlanRepository(db)
        .save(catalogPlan(), catalogRevision(effectiveFrom: date));
    final prepare =
        PreWorkoutController(todayRepository: SqliteTodayRepository(db));
    addTearDown(prepare.dispose);

    await prepare.prepare(date: date, freeWorkout: false);

    expect(
      prepare.draft.exercises.single.categorySnapshot,
      ExerciseCategory.chest,
    );
    expect(
      prepare.draft.exercises.single.equipmentSnapshot,
      ExerciseEquipment.dumbbell,
    );
  });

  test('deleting a set keeps every other draft exercise', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final prepare =
        PreWorkoutController(todayRepository: SqliteTodayRepository(db));
    addTearDown(prepare.dispose);
    await prepare.prepare(date: date, freeWorkout: true);
    prepare.addExercise(catalogExercise(id: 'first'));
    prepare.addExercise(catalogExercise(id: 'second'));
    prepare.addSet('first');

    prepare.deleteSet('first-set-1');

    expect(
      prepare.draft.exercises.map((exercise) => exercise.id),
      ['first', 'second'],
    );
    expect(prepare.draft.exercises.first.sets.single.order, 0);
  });

  test('planned preparation omits a valid plan exercise with zero sets',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    await SqlitePlanRepository(db).save(
      catalogPlan(),
      PlanRevision(
        id: 'zero-r',
        planId: 'p1',
        effectiveFrom: date,
        cycleAnchorDate: date,
        cycleDays: 1,
        mode: PlanMode.infinite,
        days: [
          PlanDay(
            id: 'zero-d',
            dayNumber: 1,
            name: '未配置组',
            isRest: false,
            exercises: [
              PlanExercise(
                id: 'zero-e',
                exerciseId: 'x1',
                nameSnapshot: '待配置动作',
                note: '',
                targetRestSeconds: 60,
                order: 0,
                sets: const [],
              ),
            ],
          ),
        ],
      ),
    );
    final prepare =
        PreWorkoutController(todayRepository: SqliteTodayRepository(db));
    addTearDown(prepare.dispose);

    await prepare.prepare(date: date, freeWorkout: false);

    expect(prepare.draft.exercises, isEmpty);
    expect(
      (await SqlitePlanRepository(db).revisions('p1'))
          .single
          .days
          .single
          .exercises
          .single
          .sets,
      isEmpty,
    );
  });

  test('invalid partial set values are ignored without throwing', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    await SqlitePlanRepository(db)
        .save(catalogPlan(), catalogRevision(effectiveFrom: date));
    final prepare =
        PreWorkoutController(todayRepository: SqliteTodayRepository(db));
    addTearDown(prepare.dispose);
    await prepare.prepare(date: date, freeWorkout: false);

    expect(() => prepare.updateSet('s1', weight: -1), returnsNormally);
    expect(() => prepare.updateSet('s1', reps: 0), returnsNormally);
    expect(prepare.draft.exercises.single.sets.single.plannedWeight, 20);
    expect(prepare.draft.exercises.single.sets.single.plannedReps, 8);
  });

  test('delete and real reorders stay draft-only after repository reread',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final plans = SqlitePlanRepository(db);
    await plans.save(catalogPlan(), _multiRevision(date));
    final workouts = SqliteWorkoutRepository(db);
    final prepare =
        PreWorkoutController(todayRepository: SqliteTodayRepository(db));
    addTearDown(prepare.dispose);
    await prepare.prepare(date: date, freeWorkout: false);

    prepare.reorderExercises(const ['pe2', 'pe1']);
    prepare.reorderSets('pe1', const ['s2', 's1']);
    prepare.deleteSet('s1');
    prepare.removeExercise('pe2');

    expect(prepare.draft.exercises.single.id, 'pe1');
    expect(prepare.draft.exercises.single.sets.single.id, 's2');
    final persisted = (await plans.revisions('p1')).single;
    expect(
      persisted.days.single.exercises.map((item) => item.id),
      ['pe1', 'pe2'],
    );
    expect(
      persisted.days.single.exercises.first.sets.map((set) => set.id),
      ['s1', 's2'],
    );
    expect(await workouts.findUnfinished(), isNull);
  });
}

PlanRevision _multiRevision(LocalDate date) => PlanRevision(
      id: 'multi-r',
      planId: 'p1',
      effectiveFrom: date,
      cycleAnchorDate: date,
      cycleDays: 1,
      mode: PlanMode.infinite,
      days: [
        PlanDay(
          id: 'multi-d',
          dayNumber: 1,
          name: '多动作',
          isRest: false,
          exercises: [
            PlanExercise(
              id: 'pe1',
              exerciseId: 'x1',
              nameSnapshot: '动作一',
              note: '',
              targetRestSeconds: 60,
              order: 0,
              sets: [
                PlanSet(
                  id: 's1',
                  order: 0,
                  plannedWeight: 10,
                  unit: WeightUnit.kg,
                  plannedReps: 8,
                ),
                PlanSet(
                  id: 's2',
                  order: 1,
                  plannedWeight: 12,
                  unit: WeightUnit.kg,
                  plannedReps: 6,
                ),
              ],
            ),
            PlanExercise(
              id: 'pe2',
              exerciseId: 'x2',
              nameSnapshot: '动作二',
              note: '',
              targetRestSeconds: 90,
              order: 1,
              sets: [
                PlanSet(
                  id: 's3',
                  order: 0,
                  plannedWeight: 20,
                  unit: WeightUnit.kg,
                  plannedReps: 5,
                ),
              ],
            ),
          ],
        ),
      ],
    );
