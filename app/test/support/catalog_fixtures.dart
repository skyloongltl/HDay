import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/plans/domain/plan.dart';
import 'package:fitness_counter/features/plans/domain/plan_day.dart';
import 'package:fitness_counter/features/plans/domain/plan_revision.dart';

final _catalogTimestamp = DateTime.utc(2026, 9);

Exercise catalogExercise({String id = 'x1', String name = '哑铃卧推'}) => Exercise(
      id: id,
      name: name,
      category: ExerciseCategory.chest,
      equipment: ExerciseEquipment.dumbbell,
      defaultUnit: WeightUnit.kg,
      note: '',
      createdAt: _catalogTimestamp,
      updatedAt: _catalogTimestamp,
    );

Plan catalogPlan({
  String id = 'p1',
  int priority = 0,
  int defaultOrder = 0,
  bool enabled = true,
}) =>
    Plan(
      id: id,
      name: '三日训练计划',
      enabled: enabled,
      priority: priority,
      defaultOrder: defaultOrder,
      createdAt: _catalogTimestamp,
      updatedAt: _catalogTimestamp,
    );

PlanRevision catalogRevision({
  String id = 'r1',
  String planId = 'p1',
  required LocalDate effectiveFrom,
  LocalDate? anchor,
  int cycleDays = 3,
  PlanMode mode = PlanMode.infinite,
  int? cycleCount,
  LocalDate? endDate,
}) =>
    PlanRevision(
      id: id,
      planId: planId,
      effectiveFrom: effectiveFrom,
      cycleAnchorDate: anchor ?? effectiveFrom,
      cycleDays: cycleDays,
      mode: mode,
      cycleCount: cycleCount,
      endDate: endDate,
      days: List.generate(
        cycleDays < 0 ? 0 : cycleDays,
        (index) => PlanDay(
          id: '$id-d${index + 1}',
          dayNumber: index + 1,
          name: 'D${index + 1}',
          isRest: false,
          exercises: [
            PlanExercise(
              id: 'pe1',
              exerciseId: 'x1',
              nameSnapshot: '哑铃卧推',
              note: '',
              targetRestSeconds: 90,
              order: 0,
              sets: [
                PlanSet(
                  id: 's1',
                  order: 0,
                  plannedWeight: 20,
                  unit: WeightUnit.kg,
                  plannedReps: 8,
                ),
              ],
            ),
          ],
        ),
      ),
    );
