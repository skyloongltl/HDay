import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:fitness_counter/features/workout/domain/workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';

import 'workout_fixtures.dart';

final trainingTime = DateTime.utc(2026, 9, 15, 23, 59, 40, 123, 456);

WorkoutSession newSession({String id = 'w1', LocalDate? date}) =>
    WorkoutMachine.start(
      id: id,
      draft: twoSetDraft(date: date),
      nowUtc: trainingTime,
    );

Future<void> persistCompleted(
  WorkoutRepository repository, {
  String id = 'w1',
  LocalDate? date,
}) async {
  var session = newSession(id: id, date: date);
  await repository.create(session);
  session = WorkoutMachine.transition(
    session,
    const StartSet('s1'),
    trainingTime,
  );
  session = WorkoutMachine.transition(
    session,
    const CompleteSet('s1', actualWeight: 22.5, actualReps: 7),
    trainingTime.add(const Duration(seconds: 20)),
  );
  session = WorkoutMachine.transition(
    session,
    const PrepareFinish(),
    trainingTime.add(const Duration(seconds: 35)),
  );
  await repository.save(session, expectedRevision: 0);
  await repository.saveCompleted(id, note: 'first note', expectedRevision: 1);
}
