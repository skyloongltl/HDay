import 'package:fitness_counter/core/domain/clock.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/today/application/today_controller.dart';
import 'package:fitness_counter/features/today/data/sqlite_today_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_database.dart';

void main() {
  test('refresh loads the overview for Clock today instead of a screen date',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final controller = TodayController(
      repository: SqliteTodayRepository(db),
      clock: _FixedClock(LocalDate(2026, 9, 15)),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.state.hasValue, isTrue);
    expect(controller.state.value!.scheduledDays, isEmpty);
    expect(controller.state.value!.mergedExercises, isEmpty);
    expect(controller.state.value!.fitnessDayStats.total, 0);
  });
}

final class _FixedClock implements Clock {
  const _FixedClock(this._today);
  final LocalDate _today;

  @override
  Duration get monotonicElapsed => Duration.zero;

  @override
  DateTime nowUtc() => DateTime.utc(2026, 9, 15);

  @override
  LocalDate today() => _today;
}
