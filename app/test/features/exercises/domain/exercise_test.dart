import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';

void main() {
  test('category and equipment expose the persisted codes', () {
    expect(
      ExerciseCategory.values.map((value) => value.code),
      [
        'chest',
        'back',
        'shoulders',
        'legs',
        'arms',
        'core',
        'full_body',
        'cardio',
      ],
    );
    expect(
      ExerciseEquipment.values.map((value) => value.code),
      [
        'bodyweight',
        'barbell',
        'dumbbell',
        'machine',
        'cable',
        'kettlebell',
        'resistance_band',
      ],
    );
    expect(ExerciseCategory.fromCode('full_body'), ExerciseCategory.fullBody);
    expect(
      ExerciseEquipment.fromCode('resistance_band'),
      ExerciseEquipment.resistanceBand,
    );
    expect(WeightUnit.fromCode('bodyweight'), WeightUnit.bodyweight);
    expect(() => ExerciseCategory.fromCode('unknown'), throwsFormatException);
  });

  test('exercise trims a nonempty name and keeps catalog fields', () {
    final exercise = catalogExercise(name: '  哑铃卧推  ');

    expect(exercise.name, '哑铃卧推');
    expect(exercise.category, ExerciseCategory.chest);
    expect(exercise.equipment, ExerciseEquipment.dumbbell);
    expect(exercise.defaultUnit, WeightUnit.kg);
    expect(exercise.note, '');
    expect(exercise.createdAt, DateTime.utc(2026, 9));
  });

  test('exercise rejects empty names and non-UTC timestamps', () {
    expect(() => catalogExercise(name: '   '), throwsArgumentError);
    expect(
      () => Exercise(
        id: 'x1',
        name: '哑铃卧推',
        category: ExerciseCategory.chest,
        equipment: ExerciseEquipment.dumbbell,
        defaultUnit: WeightUnit.kg,
        note: '',
        createdAt: DateTime(2026, 9),
        updatedAt: DateTime.utc(2026, 9),
      ),
      throwsArgumentError,
    );
  });

  test('an exact existing exercise name is rejected after trimming', () {
    final existing = [catalogExercise()];

    expect(
      () => Exercise.ensureNameAvailable('  哑铃卧推 ', existing),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.code,
          'code',
          FailureCode.duplicate,
        ),
      ),
    );
    expect(
      () => Exercise.ensureNameAvailable('哑铃卧推（上斜）', existing),
      returnsNormally,
    );
  });
}
