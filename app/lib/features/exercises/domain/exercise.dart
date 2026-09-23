import '../../../core/domain/app_failure.dart';

enum WeightUnit {
  kg('kg'),
  lb('lb'),
  bodyweight('bodyweight'),
  none('none');

  const WeightUnit(this.code);

  final String code;

  static WeightUnit fromCode(String code) => values.firstWhere(
        (value) => value.code == code,
        orElse: () => throw FormatException('Unknown weight unit: $code'),
      );
}

enum ExerciseCategory {
  chest('chest'),
  back('back'),
  shoulders('shoulders'),
  legs('legs'),
  arms('arms'),
  core('core'),
  fullBody('full_body'),
  cardio('cardio');

  const ExerciseCategory(this.code);

  final String code;

  static ExerciseCategory fromCode(String code) => values.firstWhere(
        (value) => value.code == code,
        orElse: () => throw FormatException('Unknown exercise category: $code'),
      );
}

enum ExerciseEquipment {
  bodyweight('bodyweight'),
  barbell('barbell'),
  dumbbell('dumbbell'),
  machine('machine'),
  cable('cable'),
  kettlebell('kettlebell'),
  resistanceBand('resistance_band');

  const ExerciseEquipment(this.code);

  final String code;

  static ExerciseEquipment fromCode(String code) => values.firstWhere(
        (value) => value.code == code,
        orElse: () =>
            throw FormatException('Unknown exercise equipment: $code'),
      );
}

final class Exercise {
  Exercise({
    required this.id,
    required String name,
    required this.category,
    required this.equipment,
    required this.defaultUnit,
    required String note,
    required this.createdAt,
    required this.updatedAt,
  })  : name = name.trim(),
        note = note.trim() {
    _requireNonempty(id, 'id');
    _requireNonempty(this.name, 'name');
    _requireUtc(createdAt, 'createdAt');
    _requireUtc(updatedAt, 'updatedAt');
  }

  final String id;
  final String name;
  final ExerciseCategory category;
  final ExerciseEquipment equipment;
  final WeightUnit defaultUnit;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  static void ensureNameAvailable(
    String name,
    Iterable<Exercise> existing, {
    String? excludingId,
  }) {
    final candidate = name.trim();
    _requireNonempty(candidate, 'name');
    if (existing.any(
      (exercise) => exercise.id != excludingId && exercise.name == candidate,
    )) {
      throw AppFailure(FailureCode.duplicate, detail: candidate);
    }
  }
}

void _requireNonempty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'Must use UTC.');
  }
}
