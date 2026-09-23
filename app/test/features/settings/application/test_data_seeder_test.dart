import 'package:fitness_counter/features/settings/application/test_data_seeder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_clock.dart';
import '../../../support/test_database.dart';

void main() {
  test('seeds a useful catalog once and repeated runs are idempotent',
      () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final seeder = TestDataSeeder(
      database,
      FakeClock(DateTime.utc(2026, 9, 23, 8)),
    );

    final first = await seeder.seed();
    expect(first.exercisesAdded, 4);
    expect(first.planAdded, isTrue);
    expect(first.historyAdded, 3);
    expect(first.historySkippedForActiveWorkout, isFalse);

    final second = await seeder.seed();
    expect(second.totalAdded, 0);
    expect(second.historySkippedForActiveWorkout, isFalse);

    expect(
      (await database.database.query(
        'exercises',
        where: "id LIKE 'hday-test-%'",
      )),
      hasLength(4),
    );
    expect(
      await database.database.query(
        'plans',
        where: 'id = ?',
        whereArgs: ['hday-test-plan'],
      ),
      hasLength(1),
    );
    expect(
      await database.database.query(
        'workout_sessions',
        where: "id LIKE 'hday-test-history-%' AND phase = 'saved'",
      ),
      hasLength(3),
    );
  });
}
