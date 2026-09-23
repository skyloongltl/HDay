import '../../../core/data/app_database.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/local_date.dart';
import '../../exercises/data/sqlite_exercise_repository.dart';
import '../../exercises/domain/exercise.dart';
import '../../plans/data/sqlite_plan_repository.dart';
import '../../plans/domain/plan.dart';
import '../../plans/domain/plan_day.dart';
import '../../plans/domain/plan_revision.dart';
import '../../workout/data/sqlite_workout_repository.dart';
import '../../workout/domain/workout_draft.dart';
import '../../workout/domain/workout_event.dart';
import '../../workout/domain/workout_machine.dart';

final class TestDataSeedResult {
  const TestDataSeedResult({
    required this.exercisesAdded,
    required this.planAdded,
    required this.historyAdded,
    required this.historySkippedForActiveWorkout,
  });

  final int exercisesAdded;
  final bool planAdded;
  final int historyAdded;
  final bool historySkippedForActiveWorkout;

  int get totalAdded => exercisesAdded + (planAdded ? 1 : 0) + historyAdded;
}

/// Adds a small, recognizable catalog without replacing user-owned records.
/// Fixed IDs make retries and repeated taps idempotent.
final class TestDataSeeder {
  const TestDataSeeder(this._database, this._clock);

  final AppDatabase _database;
  final Clock _clock;

  static const _planId = 'hday-test-plan';
  static const _revisionId = 'hday-test-plan-r1';

  Future<TestDataSeedResult> seed() async {
    final exerciseRepository = SqliteExerciseRepository(_database);
    final planRepository = SqlitePlanRepository(_database);
    final workoutRepository = SqliteWorkoutRepository(_database);
    final now = _clock.nowUtc();
    final today = _clock.today();

    var exercisesAdded = 0;
    final exercises = <Exercise>[];
    for (final template in _exerciseTemplates) {
      final byId = await exerciseRepository.find(template.id);
      if (byId != null) {
        exercises.add(byId);
        continue;
      }
      final sameName = (await exerciseRepository.search(query: template.name))
          .where((exercise) => exercise.name == template.name)
          .firstOrNull;
      if (sameName != null) {
        exercises.add(sameName);
        continue;
      }
      final exercise = Exercise(
        id: template.id,
        name: template.name,
        category: template.category,
        equipment: template.equipment,
        defaultUnit: template.unit,
        note: '由设置页测试工具生成，可按需编辑或删除。',
        createdAt: now,
        updatedAt: now,
      );
      await exerciseRepository.save(exercise);
      exercises.add(exercise);
      exercisesAdded++;
    }

    var planAdded = false;
    if (await planRepository.find(_planId) == null) {
      await planRepository.save(
        Plan(
          id: _planId,
          name: '[测试] 三日全身训练',
          enabled: true,
          priority: -100,
          defaultOrder: 999,
          createdAt: now,
          updatedAt: now,
        ),
        _buildRevision(today, exercises),
      );
      planAdded = true;
    }

    var historyAdded = 0;
    final hasActiveWorkout = await workoutRepository.findUnfinished() != null;
    if (!hasActiveWorkout) {
      for (var index = 0; index < 3; index++) {
        final id = 'hday-test-history-$index';
        if (await workoutRepository.find(id) != null) continue;
        final date = today.addDays(-1 - index * 2);
        final start = DateTime.utc(
          date.year,
          date.month,
          date.day,
          10 + index,
        );
        final exercise = exercises[index % exercises.length];
        final setId = '$id-set';
        final draft = WorkoutDraft(
          workoutDate: date,
          exercises: [
            WorkoutExercise(
              id: '$id-exercise',
              exerciseId: exercise.id,
              nameSnapshot: exercise.name,
              categorySnapshot: exercise.category,
              equipmentSnapshot: exercise.equipment,
              unitSnapshot: exercise.defaultUnit,
              note: '',
              targetRestSeconds: 90,
              order: 0,
              temporary: false,
              sets: [
                WorkoutSet(
                  id: setId,
                  order: 0,
                  plannedWeight: 20 + index * 5,
                  plannedReps: 8 + index,
                  unit: exercise.defaultUnit,
                  temporary: false,
                ),
              ],
            ),
          ],
        );
        var session = WorkoutMachine.start(
          id: id,
          draft: draft,
          nowUtc: start,
        );
        await workoutRepository.create(session);
        session = WorkoutMachine.transition(
          session,
          StartSet(setId),
          start.add(const Duration(minutes: 1)),
        );
        session = WorkoutMachine.transition(
          session,
          CompleteSet(
            setId,
            actualWeight: 20 + index * 5,
            actualReps: 8 + index,
          ),
          start.add(const Duration(minutes: 2)),
        );
        session = WorkoutMachine.transition(
          session,
          const PrepareFinish(),
          start.add(const Duration(minutes: 3)),
        );
        await workoutRepository.save(session, expectedRevision: 0);
        await workoutRepository.saveCompleted(
          id,
          note: '测试训练记录',
          expectedRevision: 1,
          endedAtUtc: start.add(const Duration(minutes: 3)),
        );
        historyAdded++;
      }
    }

    return TestDataSeedResult(
      exercisesAdded: exercisesAdded,
      planAdded: planAdded,
      historyAdded: historyAdded,
      historySkippedForActiveWorkout: hasActiveWorkout,
    );
  }

  PlanRevision _buildRevision(LocalDate startsOn, List<Exercise> exercises) {
    PlanExercise plannedExercise(Exercise exercise, int day, int order) =>
        PlanExercise(
          id: 'hday-test-plan-d$day-e$order',
          exerciseId: exercise.id,
          nameSnapshot: exercise.name,
          note: '',
          targetRestSeconds: 90,
          order: order,
          sets: [
            for (var set = 0; set < 3; set++)
              PlanSet(
                id: 'hday-test-plan-d$day-e$order-s$set',
                order: set,
                plannedWeight: exercise.defaultUnit == WeightUnit.bodyweight
                    ? 0
                    : 20 + day * 2,
                unit: exercise.defaultUnit,
                plannedReps: 8 + set,
              ),
          ],
        );

    return PlanRevision(
      id: _revisionId,
      planId: _planId,
      effectiveFrom: startsOn,
      cycleAnchorDate: startsOn,
      cycleDays: 4,
      mode: PlanMode.infinite,
      days: [
        PlanDay(
          id: 'hday-test-plan-d1',
          dayNumber: 1,
          name: '上肢',
          isRest: false,
          exercises: [
            plannedExercise(exercises[0], 1, 0),
            plannedExercise(exercises[1], 1, 1),
          ],
        ),
        PlanDay(
          id: 'hday-test-plan-d2',
          dayNumber: 2,
          name: '下肢',
          isRest: false,
          exercises: [plannedExercise(exercises[2], 2, 0)],
        ),
        PlanDay(
          id: 'hday-test-plan-d3',
          dayNumber: 3,
          name: '核心与体能',
          isRest: false,
          exercises: [plannedExercise(exercises[3], 3, 0)],
        ),
        PlanDay(
          id: 'hday-test-plan-d4',
          dayNumber: 4,
          name: '休息',
          isRest: true,
          exercises: const [],
        ),
      ],
    );
  }
}

const _exerciseTemplates = <({
  String id,
  String name,
  ExerciseCategory category,
  ExerciseEquipment equipment,
  WeightUnit unit,
})>[
  (
    id: 'hday-test-bench-press',
    name: '[测试] 哑铃卧推',
    category: ExerciseCategory.chest,
    equipment: ExerciseEquipment.dumbbell,
    unit: WeightUnit.kg,
  ),
  (
    id: 'hday-test-row',
    name: '[测试] 坐姿划船',
    category: ExerciseCategory.back,
    equipment: ExerciseEquipment.cable,
    unit: WeightUnit.kg,
  ),
  (
    id: 'hday-test-squat',
    name: '[测试] 杠铃深蹲',
    category: ExerciseCategory.legs,
    equipment: ExerciseEquipment.barbell,
    unit: WeightUnit.kg,
  ),
  (
    id: 'hday-test-plank',
    name: '[测试] 平板支撑',
    category: ExerciseCategory.core,
    equipment: ExerciseEquipment.bodyweight,
    unit: WeightUnit.bodyweight,
  ),
];
