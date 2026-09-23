import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/history/data/sqlite_history_repository.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/persistence_fixtures.dart';
import '../../../support/test_database.dart';

void main() {
  test('stats count distinct saved dates with configured week boundaries',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final workouts = SqliteWorkoutRepository(db);
    final history = SqliteHistoryRepository(db);
    await persistCompleted(workouts, id: 'aug', date: LocalDate(2026, 8, 31));
    await persistCompleted(workouts, id: 'sun', date: LocalDate(2026, 9, 13));
    await persistCompleted(workouts, id: 'a');
    await persistCompleted(workouts, id: 'b');
    await workouts
        .create(newSession(id: 'unfinished', date: LocalDate(2026, 9, 16)));
    final stats =
        await history.stats(LocalDate(2026, 9, 16), weekStart: DateTime.monday);
    expect(stats.total, 3);
    expect(stats.week, 1);
    expect(stats.month, 2);
    expect(stats.lastWorkoutAt!.isUtc, isTrue);
    expect(
      (await history.stats(
        LocalDate(2026, 9, 16),
        weekStart: DateTime.sunday,
      ))
          .week,
      2,
    );
    expect(
      (await history.day(LocalDate(2026, 9, 15))).map((s) => s.id),
      ['a', 'b'],
    );
    final month = await history.month(LocalDate(2026, 9, 1));
    expect(month, hasLength(30));
    expect(month[14].hasSavedWorkout, isTrue);
    expect(month[15].hasSavedWorkout, isFalse);
    expect(month[15].hasUnfinishedWorkout, isTrue);
    expect(month[0].hasPlan, isFalse);
    expect(month[0].isAllRest, isFalse);
  });

  test(
      'history corrections change only actual values and note; delete clears stats and descendants',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final workouts = SqliteWorkoutRepository(db);
    final history = SqliteHistoryRepository(db);
    await persistCompleted(workouts);
    await history.correctSet('w1', 's1', weight: null, reps: 6);
    await history.updateNote('w1', '  corrected note  ');
    final record = (await history.exerciseRecords('bench-press')).single;
    expect(record.sessionId, 'w1');
    expect(record.setId, 's1');
    expect(record.exerciseId, 'bench-press');
    expect(record.date, LocalDate(2026, 9, 15));
    expect(record.completedAt, trainingTime.add(const Duration(seconds: 20)));
    expect(record.unit.code, 'kg');
    expect(record.weight, isNull);
    expect(record.reps, 6);
    final saved = (await workouts.find('w1'))!;
    expect(saved.note, 'corrected note');
    expect(saved.revision, 4);
    expect(saved.exercises.single.sets.first.plannedWeight, 20);
    expect(saved.exercises.single.sets.first.plannedReps, 8);
    await expectLater(
      history.correctSet('w1', 's1', weight: -1, reps: 6),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      history.correctSet('w1', 'missing', weight: 20, reps: 6),
      throwsA(isA<AppFailure>()),
    );
    await history.deleteSession('w1');
    expect(await history.day(LocalDate(2026, 9, 15)), isEmpty);
    expect(await history.exerciseRecords('bench-press'), isEmpty);
    expect(await db.database.query('workout_exercises'), isEmpty);
    expect(await db.database.query('workout_sets'), isEmpty);
    expect(
      (await history.stats(LocalDate(2026, 9, 15), weekStart: 1)).total,
      0,
    );
  });

  test('history mutations reject unfinished sessions', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    await SqliteWorkoutRepository(db).create(newSession());
    final history = SqliteHistoryRepository(db);
    await expectLater(
      history.updateNote('w1', 'unsafe'),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      history.correctSet('w1', 's1', weight: 2, reps: 3),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(history.deleteSession('w1'), throwsA(isA<AppFailure>()));
  });
}
