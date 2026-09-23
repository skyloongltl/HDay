import '../../../core/domain/local_date.dart';
import 'active_timer.dart';
import 'workout_draft.dart';

enum WorkoutPhase {
  active,
  resting,
  completedPaused,
  finishing,
  saved,
  timeAnomaly
}

final class WorkoutTimeAnomaly {
  const WorkoutTimeAnomaly({
    required this.reason,
    required this.detectedAt,
    required this.previousPhase,
  });

  final TimerAnomalyReason reason;
  final DateTime detectedAt;
  final WorkoutPhase previousPhase;
}

final class WorkoutFinishCheckpoint {
  WorkoutFinishCheckpoint({
    required this.phase,
    required List<WorkoutExercise> exercises,
    required this.timer,
    required this.setTimer,
    required this.restTimer,
    required this.activeSetId,
    required this.selectedSetId,
    required this.restStartedAt,
    required this.restTargetSeconds,
  }) : exercises = List.unmodifiable(exercises) {
    if (phase == WorkoutPhase.finishing ||
        phase == WorkoutPhase.saved ||
        phase == WorkoutPhase.timeAnomaly) {
      throw ArgumentError.value(phase, 'phase', 'Must be a resumable phase.');
    }
    _requireUtc(restStartedAt, 'restStartedAt');
  }

  final WorkoutPhase phase;
  final List<WorkoutExercise> exercises;
  final ActiveTimer timer;
  final ActiveTimer setTimer;
  final ActiveTimer restTimer;
  final String? activeSetId;
  final String? selectedSetId;
  final DateTime? restStartedAt;
  final int? restTargetSeconds;
}

final class WorkoutSession {
  WorkoutSession({
    required this.id,
    required this.workoutDate,
    required this.startedAt,
    required this.endedAt,
    required this.phase,
    required List<WorkoutExercise> exercises,
    required this.timer,
    ActiveTimer? setTimer,
    ActiveTimer? restTimer,
    required this.activeSetId,
    required this.selectedSetId,
    required this.restStartedAt,
    required this.restTargetSeconds,
    required String note,
    required this.revision,
    required this.anomaly,
    required this.finishCheckpoint,
  })  : exercises = List.unmodifiable(exercises),
        setTimer = setTimer ?? ActiveTimer(),
        restTimer = restTimer ?? ActiveTimer(),
        note = note.trim() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (revision < 0) {
      throw ArgumentError.value(revision, 'revision', 'Must not be negative.');
    }
    _requireUtc(startedAt, 'startedAt');
    _requireUtc(endedAt, 'endedAt');
    _requireUtc(restStartedAt, 'restStartedAt');
    if (anomaly != null) {
      _requireUtc(anomaly!.detectedAt, 'anomaly.detectedAt');
    }
  }

  final String id;
  final LocalDate workoutDate;
  final DateTime startedAt;
  final DateTime? endedAt;
  final WorkoutPhase phase;
  final List<WorkoutExercise> exercises;
  final ActiveTimer timer;
  final ActiveTimer setTimer;
  final ActiveTimer restTimer;
  final String? activeSetId;
  final String? selectedSetId;
  final DateTime? restStartedAt;
  final int? restTargetSeconds;
  final String note;
  final int revision;
  final WorkoutTimeAnomaly? anomaly;
  final WorkoutFinishCheckpoint? finishCheckpoint;

  bool get hasCompletedSet => exercises
      .expand((exercise) => exercise.sets)
      .any((set) => set.status == SetStatus.completed);

  WorkoutSession copyWith({
    Object? endedAt = _unset,
    WorkoutPhase? phase,
    List<WorkoutExercise>? exercises,
    ActiveTimer? timer,
    ActiveTimer? setTimer,
    ActiveTimer? restTimer,
    Object? activeSetId = _unset,
    Object? selectedSetId = _unset,
    Object? restStartedAt = _unset,
    Object? restTargetSeconds = _unset,
    String? note,
    int? revision,
    Object? anomaly = _unset,
    Object? finishCheckpoint = _unset,
  }) =>
      WorkoutSession(
        id: id,
        workoutDate: workoutDate,
        startedAt: startedAt,
        endedAt:
            identical(endedAt, _unset) ? this.endedAt : endedAt as DateTime?,
        phase: phase ?? this.phase,
        exercises: exercises ?? this.exercises,
        timer: timer ?? this.timer,
        setTimer: setTimer ?? this.setTimer,
        restTimer: restTimer ?? this.restTimer,
        activeSetId: identical(activeSetId, _unset)
            ? this.activeSetId
            : activeSetId as String?,
        selectedSetId: identical(selectedSetId, _unset)
            ? this.selectedSetId
            : selectedSetId as String?,
        restStartedAt: identical(restStartedAt, _unset)
            ? this.restStartedAt
            : restStartedAt as DateTime?,
        restTargetSeconds: identical(restTargetSeconds, _unset)
            ? this.restTargetSeconds
            : restTargetSeconds as int?,
        note: note ?? this.note,
        revision: revision ?? this.revision,
        anomaly: identical(anomaly, _unset)
            ? this.anomaly
            : anomaly as WorkoutTimeAnomaly?,
        finishCheckpoint: identical(finishCheckpoint, _unset)
            ? this.finishCheckpoint
            : finishCheckpoint as WorkoutFinishCheckpoint?,
      );
}

const _unset = Object();

void _requireUtc(DateTime? value, String name) {
  if (value != null && !value.isUtc) {
    throw ArgumentError.value(value, name, 'Must use UTC.');
  }
}
