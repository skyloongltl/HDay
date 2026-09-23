import 'workout_session.dart';

abstract interface class WorkoutRepository {
  Future<void> create(WorkoutSession session);

  Future<WorkoutSession?> findUnfinished();

  Future<WorkoutSession?> find(String id);

  Future<void> save(
    WorkoutSession session, {
    required int expectedRevision,
  });

  Future<void> saveCompleted(
    String id, {
    required String note,
    required int expectedRevision,
    DateTime? endedAtUtc,
  });

  Future<void> discard(String id);
}
