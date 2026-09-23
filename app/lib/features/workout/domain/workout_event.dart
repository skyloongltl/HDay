import 'workout_draft.dart';

sealed class WorkoutEvent {
  const WorkoutEvent();
}

final class SelectSet extends WorkoutEvent {
  const SelectSet(this.setId);
  final String setId;
}

final class StartSet extends WorkoutEvent {
  const StartSet(this.setId);
  final String setId;
}

final class CompleteSet extends WorkoutEvent {
  const CompleteSet(
    this.setId, {
    required this.actualWeight,
    required this.actualReps,
  });
  final String setId;
  final double? actualWeight;
  final int actualReps;
}

final class SkipSet extends WorkoutEvent {
  const SkipSet(this.setId);
  final String setId;
}

final class SkipExercise extends WorkoutEvent {
  const SkipExercise(this.exerciseId);
  final String exerciseId;
}

final class UpdateActual extends WorkoutEvent {
  const UpdateActual(
    this.setId, {
    this.weight,
    required this.reps,
  });
  final String setId;
  final double? weight;
  final int reps;
}

final class AddExercise extends WorkoutEvent {
  const AddExercise(this.exercise);
  final WorkoutExercise exercise;
}

final class AddSet extends WorkoutEvent {
  const AddSet(this.exerciseId, this.set);
  final String exerciseId;
  final WorkoutSet set;
}

final class DeletePendingSet extends WorkoutEvent {
  const DeletePendingSet(this.setId);
  final String setId;
}

final class ReorderPendingExercises extends WorkoutEvent {
  const ReorderPendingExercises(this.ids);
  final List<String> ids;
}

final class PrepareFinish extends WorkoutEvent {
  const PrepareFinish();
}

final class ContinueWorkout extends WorkoutEvent {
  const ContinueWorkout();
}

final class ConfirmTime extends WorkoutEvent {
  const ConfirmTime({required this.nowUtc});
  final DateTime nowUtc;
}

/// Applied only after persistence succeeds; repository I/O stays outside domain.
final class SaveWorkout extends WorkoutEvent {
  const SaveWorkout({required this.note});
  final String note;
}
