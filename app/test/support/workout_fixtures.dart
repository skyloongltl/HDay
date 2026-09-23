import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/domain/workout_draft.dart';

WorkoutDraft twoSetDraft({LocalDate? date}) => WorkoutDraft(
      workoutDate: date ?? LocalDate(2026, 9, 15),
      exercises: [
        WorkoutExercise(
          id: 'e1',
          exerciseId: 'bench-press',
          nameSnapshot: 'Bench Press',
          categorySnapshot: ExerciseCategory.chest,
          equipmentSnapshot: ExerciseEquipment.barbell,
          unitSnapshot: WeightUnit.kg,
          sourcePlanId: 'plan-1',
          sourcePlanName: 'Strength',
          sourceRevisionId: 'revision-1',
          sourceDayNumber: 1,
          sourceDayName: 'Push',
          note: '',
          targetRestSeconds: 90,
          order: 0,
          temporary: false,
          sets: [
            _set('s1', 0),
            _set('s2', 1),
          ],
        ),
      ],
    );

WorkoutDraft oneSetDraft({LocalDate? date}) {
  final draft = twoSetDraft(date: date);
  final exercise = draft.exercises.single;
  return WorkoutDraft(
    workoutDate: draft.workoutDate,
    exercises: [
      exercise.copyWith(sets: [exercise.sets.first]),
    ],
  );
}

WorkoutSet temporarySet(String id, {int order = 1}) => WorkoutSet(
      id: id,
      order: order,
      plannedWeight: 20,
      plannedReps: 8,
      unit: WeightUnit.kg,
      temporary: true,
    );

WorkoutSet _set(String id, int order) => WorkoutSet(
      id: id,
      order: order,
      plannedWeight: 20,
      plannedReps: 8,
      unit: WeightUnit.kg,
      temporary: false,
    );
