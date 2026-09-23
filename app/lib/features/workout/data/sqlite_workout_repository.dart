import '../../../core/data/app_database.dart';
import '../../../core/domain/app_failure.dart';
import '../domain/workout_event.dart';
import '../domain/workout_machine.dart';
import '../domain/workout_repository.dart';
import '../domain/workout_session.dart';
import 'workout_mapper.dart';

final class SqliteWorkoutRepository implements WorkoutRepository {
  const SqliteWorkoutRepository(this._db);
  final AppDatabase _db;

  @override
  Future<void> create(WorkoutSession session) => _db.transaction((tx) async {
        if (session.phase == WorkoutPhase.saved || session.revision != 0) {
          throw const AppFailure(
            FailureCode.validation,
            detail: 'Create an unfinished revision-zero session.',
          );
        }
        if ((await tx.query(
          'workout_sessions',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [session.id],
        ))
            .isNotEmpty) {
          throw const AppFailure(
            FailureCode.conflict,
            detail: 'Session already exists.',
          );
        }
        // The partial unique index owns exclusivity, including concurrent writers.
        await tx.insert('workout_sessions', WorkoutMapper.sessionRow(session));
        await WorkoutMapper.writeChildren(tx, session);
      });

  @override
  Future<WorkoutSession?> findUnfinished() => _db.transaction((tx) async {
        final rows = await tx.query(
          'workout_sessions',
          where: "phase != 'saved'",
          limit: 1,
        );
        return rows.isEmpty ? null : WorkoutMapper.read(tx, rows.single);
      });

  @override
  Future<WorkoutSession?> find(String id) =>
      _db.transaction((tx) => WorkoutMapper.find(tx, id));

  /// The reducer leaves revision unchanged. Success writes expectedRevision+1;
  /// callers must re-read or adopt that revision only after this future succeeds.
  @override
  Future<void> save(WorkoutSession session, {required int expectedRevision}) =>
      _db.transaction((tx) async {
        final previous = await WorkoutMapper.find(tx, session.id);
        if (previous == null) throw const AppFailure(FailureCode.notFound);
        if (previous.phase == WorkoutPhase.saved ||
            previous.revision != expectedRevision ||
            session.revision != expectedRevision) {
          throw const AppFailure(
            FailureCode.conflict,
            detail: 'Stale or finalized session.',
          );
        }
        if (session.phase == WorkoutPhase.saved ||
            session.workoutDate != previous.workoutDate ||
            session.startedAt != previous.startedAt) {
          throw const AppFailure(
            FailureCode.validation,
            detail:
                'Use saveCompleted; session identity and start date are immutable.',
          );
        }
        final next = session.copyWith(revision: expectedRevision + 1);
        final changed = await tx.update(
          'workout_sessions',
          WorkoutMapper.sessionRow(next),
          where: "id = ? AND revision = ? AND phase != 'saved'",
          whereArgs: [session.id, expectedRevision],
        );
        if (changed != 1) throw const AppFailure(FailureCode.conflict);
        await WorkoutMapper.writeChildren(tx, next);
      });

  @override
  Future<void> saveCompleted(
    String id, {
    required String note,
    required int expectedRevision,
    DateTime? endedAtUtc,
  }) =>
      _db.transaction((tx) async {
        final previous = await WorkoutMapper.find(tx, id);
        if (previous == null) throw const AppFailure(FailureCode.notFound);
        if (previous.phase == WorkoutPhase.saved) {
          // A repeated acknowledged/lost-response request is a no-op. An old request
          // cannot overwrite subsequent history corrections or a different note.
          if (previous.revision == expectedRevision + 1 &&
              previous.note == note.trim()) {
            return;
          }
          throw const AppFailure(FailureCode.conflict);
        }
        if (previous.revision != expectedRevision) {
          throw const AppFailure(FailureCode.conflict);
        }
        if (previous.phase != WorkoutPhase.finishing ||
            !previous.hasCompletedSet) {
          throw const AppFailure(
            FailureCode.validation,
            detail:
                'Prepare finish with at least one completed set before saving.',
          );
        }
        final completed = WorkoutMachine.transition(
          previous,
          SaveWorkout(note: note),
          endedAtUtc ?? DateTime.now().toUtc(),
        ).copyWith(revision: expectedRevision + 1);
        final changed = await tx.update(
          'workout_sessions',
          WorkoutMapper.sessionRow(completed),
          where: "id = ? AND revision = ? AND phase = 'finishing'",
          whereArgs: [id, expectedRevision],
        );
        if (changed != 1) throw const AppFailure(FailureCode.conflict);
      });

  @override
  Future<void> discard(String id) => _db.transaction((tx) async {
        final rows = await tx.query(
          'workout_sessions',
          columns: ['phase'],
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows.isEmpty) return;
        if (rows.single['phase'] == 'saved') {
          throw const AppFailure(FailureCode.conflict);
        }
        await tx.delete('workout_sessions', where: 'id = ?', whereArgs: [id]);
      });
}
