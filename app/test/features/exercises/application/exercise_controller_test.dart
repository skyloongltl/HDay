import 'dart:io';

import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/core/domain/clock.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/application/exercise_providers.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/persistence_fixtures.dart';
import '../../../support/test_database.dart';

final class FixedClock implements Clock {
  DateTime value = DateTime.utc(2026, 9, 16, 10);
  @override
  DateTime nowUtc() => value;
  @override
  LocalDate today() => LocalDate(2026, 9, 16);
  @override
  Duration get monotonicElapsed => Duration.zero;
}

Exercise draft(
  String id,
  String name, {
  ExerciseCategory category = ExerciseCategory.chest,
  ExerciseEquipment equipment = ExerciseEquipment.dumbbell,
  WeightUnit unit = WeightUnit.kg,
}) =>
    Exercise(
      id: id,
      name: name,
      category: category,
      equipment: equipment,
      defaultUnit: unit,
      note: '20kg训练笔记',
      createdAt: DateTime.utc(2000),
      updatedAt: DateTime.utc(2000),
    );

void main() {
  test('save and edit use injected clock and survive database reopen',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('exercise-controller-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/catalog.db';
    final db = await openTestDatabase(path: path);
    addTearDown(db.close);
    final clock = FixedClock();
    final scope = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => db),
        clockProvider.overrideWithValue(clock),
      ],
    );
    await scope.read(exerciseControllerProvider.future);
    final controller = scope.read(exerciseControllerProvider.notifier);
    await controller.save(draft('first', '哑铃卧推'));
    final result = await SqliteExerciseRepository(db).find('first');
    expect(result, isNotNull, reason: 'save must commit the new catalog entry');
    final created = result!;
    expect(created.createdAt, DateTime.utc(2026, 9, 16, 10));
    clock.value = DateTime.utc(2026, 9, 16, 11);
    await controller.save(
      draft(
        'first',
        '哑铃划船',
        category: ExerciseCategory.back,
        equipment: ExerciseEquipment.cable,
        unit: WeightUnit.lb,
      ),
    );
    scope.dispose();
    await db.close();
    final reopened = await openTestDatabase(path: path);
    addTearDown(reopened.close);
    final saved = (await SqliteExerciseRepository(reopened).find('first'))!;
    expect(saved.name, '哑铃划船');
    expect(saved.category, ExerciseCategory.back);
    expect(saved.equipment, ExerciseEquipment.cable);
    expect(saved.defaultUnit, WeightUnit.lb);
    expect(saved.createdAt, DateTime.utc(2026, 9, 16, 10));
    expect(saved.updatedAt, DateTime.utc(2026, 9, 16, 11));
  });

  test('controller combines query category equipment and recent actual usage',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqliteExerciseRepository(db);
    await repo.save(draft('bench-press', '卧推'));
    await repo
        .save(draft('other', '杠铃卧推', equipment: ExerciseEquipment.barbell));
    await repo.save(draft('back', '背部卧推', category: ExerciseCategory.back));
    await persistCompleted(SqliteWorkoutRepository(db));
    final scope = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(scope.dispose);
    var state = await scope.read(exerciseControllerProvider.future);
    expect(state.recentItems.map((e) => e.id), ['bench-press']);
    final controller = scope.read(exerciseControllerProvider.notifier);
    await controller.search('卧推');
    await controller.setCategory('chest');
    await controller.setEquipment('dumbbell');
    state = scope.read(exerciseControllerProvider).requireValue;
    expect(state.items.map((e) => e.id), ['bench-press']);
    await controller.delete('bench-press');
    state = scope.read(exerciseControllerProvider).requireValue;
    expect(state.items, isEmpty);
    expect(state.recentItems, isEmpty);
    expect(await repo.find('bench-press'), isNull);
  });

  test('duplicate and SQLite write failure publish failure and retry commits',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final scope = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(scope.dispose);
    await scope.read(exerciseControllerProvider.future);
    final controller = scope.read(exerciseControllerProvider.notifier);
    await controller.save(draft('a', '卧推'));
    await controller.save(draft('b', ' 卧推 '));
    expect(
      scope.read(exerciseControllerProvider).requireValue.failure?.code,
      FailureCode.duplicate,
    );
    await db.database.execute(
      "CREATE TRIGGER fail_save BEFORE INSERT ON exercises BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
    );
    await controller.save(draft('b', '划船'));
    expect(
      scope.read(exerciseControllerProvider).requireValue.failure?.code,
      FailureCode.persistence,
    );
    expect(await SqliteExerciseRepository(db).find('b'), isNull);
    await db.database.execute('DROP TRIGGER fail_save');
    await controller.save(draft('b', '划船'));
    expect(scope.read(exerciseControllerProvider).requireValue.failure, isNull);
    expect((await SqliteExerciseRepository(db).find('b'))?.name, '划船');
  });
}
