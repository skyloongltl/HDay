import '../../../core/domain/app_failure.dart';
import '../domain/workout_session.dart';

final class WorkoutViewState {
  const WorkoutViewState({
    this.session,
    this.isSaving = false,
    this.failure,
    this.pendingSession,
  });

  final WorkoutSession? session;
  final bool isSaving;
  final AppFailure? failure;
  final WorkoutSession? pendingSession;

  WorkoutViewState copyWith({
    Object? session = _unset,
    bool? isSaving,
    Object? failure = _unset,
    Object? pendingSession = _unset,
  }) =>
      WorkoutViewState(
        session: identical(session, _unset)
            ? this.session
            : session as WorkoutSession?,
        isSaving: isSaving ?? this.isSaving,
        failure:
            identical(failure, _unset) ? this.failure : failure as AppFailure?,
        pendingSession: identical(pendingSession, _unset)
            ? this.pendingSession
            : pendingSession as WorkoutSession?,
      );
}

const _unset = Object();
