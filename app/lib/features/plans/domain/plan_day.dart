import '../../exercises/domain/exercise.dart';

final class PlanSet {
  PlanSet({
    required this.id,
    required this.order,
    required this.plannedWeight,
    required this.unit,
    required this.plannedReps,
  }) {
    _requireNonempty(id, 'id');
    if (order < 0) {
      throw ArgumentError.value(order, 'order', 'Must not be negative.');
    }
    if (!plannedWeight.isFinite || plannedWeight < 0) {
      throw ArgumentError.value(
        plannedWeight,
        'plannedWeight',
        'Must be finite and nonnegative.',
      );
    }
    if (plannedReps < 1) {
      throw ArgumentError.value(
        plannedReps,
        'plannedReps',
        'Must be at least 1.',
      );
    }
  }

  final String id;
  final int order;
  final double plannedWeight;
  final WeightUnit unit;
  final int plannedReps;
}

final class PlanExercise {
  PlanExercise({
    required this.id,
    required this.exerciseId,
    required String nameSnapshot,
    required String note,
    required this.targetRestSeconds,
    required this.order,
    required List<PlanSet> sets,
  })  : nameSnapshot = nameSnapshot.trim(),
        note = note.trim(),
        sets = List.unmodifiable(sets) {
    _requireNonempty(id, 'id');
    _requireNonempty(exerciseId, 'exerciseId');
    _requireNonempty(this.nameSnapshot, 'nameSnapshot');
    if (targetRestSeconds < 0) {
      throw ArgumentError.value(
        targetRestSeconds,
        'targetRestSeconds',
        'Must not be negative.',
      );
    }
    if (order < 0) {
      throw ArgumentError.value(order, 'order', 'Must not be negative.');
    }
  }

  final String id;
  final String exerciseId;
  final String nameSnapshot;
  final String note;
  final int targetRestSeconds;
  final int order;
  final List<PlanSet> sets;
}

final class PlanDay {
  PlanDay({
    required this.id,
    required this.dayNumber,
    required String name,
    required this.isRest,
    required List<PlanExercise> exercises,
  })  : name = name.trim(),
        exercises = List.unmodifiable(exercises) {
    _requireNonempty(id, 'id');
    _requireNonempty(this.name, 'name');
    if (dayNumber < 1) {
      throw ArgumentError.value(
        dayNumber,
        'dayNumber',
        'Must be at least 1.',
      );
    }
    if (isRest && this.exercises.isNotEmpty) {
      throw ArgumentError.value(
        exercises,
        'exercises',
        'Rest days cannot contain exercises.',
      );
    }
  }

  final String id;
  final int dayNumber;
  final String name;
  final bool isRest;
  final List<PlanExercise> exercises;
}

void _requireNonempty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}
