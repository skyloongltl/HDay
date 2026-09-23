import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/test_database.dart';

void main() {
  test('catalog filters stable codes and roundtrips editable fields', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqliteExerciseRepository(db);
    expect(await repo.search(), isEmpty);
    await repo.save(catalogExercise());
    await repo.save(
      Exercise(
        id: 'x2',
        name: '  Band Row  ',
        category: ExerciseCategory.fullBody,
        equipment: ExerciseEquipment.resistanceBand,
        defaultUnit: WeightUnit.lb,
        note: '  steady  ',
        createdAt: trainingTime,
        updatedAt: trainingTime,
      ),
    );
    final found = (await repo.search(
      query: 'Band',
      category: 'full_body',
      equipment: 'resistance_band',
    ))
        .single;
    expect(found.id, 'x2');
    expect(found.name, 'Band Row');
    expect(found.note, 'steady');
    expect(found.defaultUnit, WeightUnit.lb);
    expect(found.createdAt, trainingTime);
    expect(found.updatedAt, trainingTime);
    expect(await repo.search(category: 'back'), isEmpty);
    await repo.save(catalogExercise(id: 'x2', name: 'Updated'));
    expect((await repo.find('x2'))!.name, 'Updated');
    await repo.delete('x2');
    expect(await repo.find('x2'), isNull);
  });

  test('concurrent trimmed exact-name inserts have one winner', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqliteExerciseRepository(db);
    final outcomes = await Future.wait([
      repo
          .save(catalogExercise(id: 'a', name: ' Bench '))
          .then<Object?>((_) => null, onError: (Object e) => e),
      SqliteExerciseRepository(db)
          .save(catalogExercise(id: 'b', name: 'Bench'))
          .then<Object?>((_) => null, onError: (Object e) => e),
    ]);
    expect(outcomes.whereType<AppFailure>().single.code, FailureCode.duplicate);
    expect(await repo.search(), hasLength(1));
    await repo.save(catalogExercise(id: 'c', name: 'bench'));
    expect(await repo.search(), hasLength(2));
  });

  test('recent is based on recorded use, excludes unused and deleted sources',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqliteExerciseRepository(db);
    await repo.save(catalogExercise(id: 'bench-press'));
    await repo.save(catalogExercise(id: 'unused', name: 'Unused'));
    expect(await repo.recent(), isEmpty);
    await persistCompleted(SqliteWorkoutRepository(db));
    expect((await repo.recent(limit: 1)).single.id, 'bench-press');
    await repo.delete('bench-press');
    expect(await repo.recent(), isEmpty);
  });
}
