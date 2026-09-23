import '../../../core/domain/local_date.dart';
import '../../exercises/domain/exercise.dart';

enum SetStatus { pending, inProgress, completed, skipped }

final class WorkoutSet {
  WorkoutSet({
    required this.id,
    required this.order,
    required this.plannedWeight,
    required this.plannedReps,
    required this.unit,
    this.actualWeight,
    this.actualReps,
    this.status = SetStatus.pending,
    this.startedAt,
    this.completedAt,
    this.skippedAt,
    this.setDurationSeconds = 0,
    this.preSetRestSeconds = 0,
    required this.temporary,
  }) {
    _requireNonempty(id, 'id');
    _requireNonnegative(order, 'order');
    _requireWeight(plannedWeight, 'plannedWeight');
    if (plannedReps < 1) {
      throw ArgumentError.value(
        plannedReps,
        'plannedReps',
        'Must be at least 1.',
      );
    }
    _requireNullableWeight(actualWeight, 'actualWeight');
    if (actualReps != null && actualReps! < 0) {
      throw ArgumentError.value(
        actualReps,
        'actualReps',
        'Must not be negative.',
      );
    }
    _requireNonnegative(setDurationSeconds, 'setDurationSeconds');
    _requireNonnegative(preSetRestSeconds, 'preSetRestSeconds');
    _requireUtc(startedAt, 'startedAt');
    _requireUtc(completedAt, 'completedAt');
    _requireUtc(skippedAt, 'skippedAt');
  }

  final String id;
  final int order;
  final double plannedWeight;
  final int plannedReps;
  final WeightUnit unit;
  final double? actualWeight;
  final int? actualReps;
  final SetStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? skippedAt;
  final int setDurationSeconds;
  final int preSetRestSeconds;
  final bool temporary;

  WorkoutSet copyWith({
    int? order,
    double? plannedWeight,
    int? plannedReps,
    Object? actualWeight = _unset,
    Object? actualReps = _unset,
    SetStatus? status,
    Object? startedAt = _unset,
    Object? completedAt = _unset,
    Object? skippedAt = _unset,
    int? setDurationSeconds,
    int? preSetRestSeconds,
  }) =>
      WorkoutSet(
        id: id,
        order: order ?? this.order,
        plannedWeight: plannedWeight ?? this.plannedWeight,
        plannedReps: plannedReps ?? this.plannedReps,
        unit: unit,
        actualWeight: identical(actualWeight, _unset)
            ? this.actualWeight
            : actualWeight as double?,
        actualReps: identical(actualReps, _unset)
            ? this.actualReps
            : actualReps as int?,
        status: status ?? this.status,
        startedAt: identical(startedAt, _unset)
            ? this.startedAt
            : startedAt as DateTime?,
        completedAt: identical(completedAt, _unset)
            ? this.completedAt
            : completedAt as DateTime?,
        skippedAt: identical(skippedAt, _unset)
            ? this.skippedAt
            : skippedAt as DateTime?,
        setDurationSeconds: setDurationSeconds ?? this.setDurationSeconds,
        preSetRestSeconds: preSetRestSeconds ?? this.preSetRestSeconds,
        temporary: temporary,
      );
}

final class WorkoutExercise {
  WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required String nameSnapshot,
    required this.categorySnapshot,
    required this.equipmentSnapshot,
    required this.unitSnapshot,
    this.sourcePlanId,
    this.sourcePlanName,
    this.sourceRevisionId,
    this.sourceDayNumber,
    this.sourceDayName,
    required String note,
    required this.targetRestSeconds,
    required this.order,
    required this.temporary,
    required List<WorkoutSet> sets,
  })  : nameSnapshot = nameSnapshot.trim(),
        note = note.trim(),
        sets = List.unmodifiable(sets) {
    _requireNonempty(id, 'id');
    _requireNonempty(exerciseId, 'exerciseId');
    _requireNonempty(this.nameSnapshot, 'nameSnapshot');
    _requireNonnegative(targetRestSeconds, 'targetRestSeconds');
    _requireNonnegative(order, 'order');
    if (this.sets.isEmpty) {
      throw ArgumentError.value(sets, 'sets', 'Must not be empty.');
    }
    _requireUnique(this.sets.map((set) => set.id), 'set ids');
  }

  final String id;
  final String exerciseId;
  final String nameSnapshot;
  final ExerciseCategory categorySnapshot;
  final ExerciseEquipment equipmentSnapshot;
  final WeightUnit unitSnapshot;
  final String? sourcePlanId;
  final String? sourcePlanName;
  final String? sourceRevisionId;
  final int? sourceDayNumber;
  final String? sourceDayName;
  final String note;
  final int targetRestSeconds;
  final int order;
  final bool temporary;
  final List<WorkoutSet> sets;

  WorkoutExercise copyWith({
    int? targetRestSeconds,
    int? order,
    List<WorkoutSet>? sets,
  }) =>
      WorkoutExercise(
        id: id,
        exerciseId: exerciseId,
        nameSnapshot: nameSnapshot,
        categorySnapshot: categorySnapshot,
        equipmentSnapshot: equipmentSnapshot,
        unitSnapshot: unitSnapshot,
        sourcePlanId: sourcePlanId,
        sourcePlanName: sourcePlanName,
        sourceRevisionId: sourceRevisionId,
        sourceDayNumber: sourceDayNumber,
        sourceDayName: sourceDayName,
        note: note,
        targetRestSeconds: targetRestSeconds ?? this.targetRestSeconds,
        order: order ?? this.order,
        temporary: temporary,
        sets: sets ?? this.sets,
      );
}

final class WorkoutDraft {
  WorkoutDraft({
    required this.workoutDate,
    required List<WorkoutExercise> exercises,
  }) : exercises = List.unmodifiable(exercises) {
    _requireUnique(
      this.exercises.map((exercise) => exercise.id),
      'exercise ids',
    );
    _requireUnique(
      this.exercises.expand((exercise) => exercise.sets).map((set) => set.id),
      'set ids',
    );
  }

  final LocalDate workoutDate;
  final List<WorkoutExercise> exercises;
}

const _unset = Object();

void _requireNonempty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

void _requireNonnegative(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'Must not be negative.');
  }
}

void _requireWeight(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and nonnegative.');
  }
}

void _requireNullableWeight(double? value, String name) {
  if (value != null) {
    _requireWeight(value, name);
  }
}

void _requireUtc(DateTime? value, String name) {
  if (value != null && !value.isUtc) {
    throw ArgumentError.value(value, name, 'Must use UTC.');
  }
}

void _requireUnique(Iterable<String> values, String name) {
  final all = values.toList();
  if (all.toSet().length != all.length) {
    throw ArgumentError.value(all, name, 'Must be unique.');
  }
}
