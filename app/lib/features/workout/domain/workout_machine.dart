import 'active_timer.dart';
import 'workout_draft.dart';
import 'workout_event.dart';
import 'workout_session.dart';

abstract final class WorkoutMachine {
  static WorkoutSession start({
    required String id,
    required WorkoutDraft draft,
    required DateTime nowUtc,
  }) {
    _requireUtc(nowUtc);
    final firstSetId =
        draft.exercises.expand((exercise) => exercise.sets).firstOrNull?.id;
    return WorkoutSession(
      id: id,
      workoutDate: draft.workoutDate,
      startedAt: nowUtc,
      endedAt: null,
      phase: WorkoutPhase.active,
      exercises: draft.exercises,
      timer: ActiveTimer(runningSegmentStartedAt: nowUtc),
      setTimer: ActiveTimer(),
      restTimer: ActiveTimer(),
      activeSetId: null,
      selectedSetId: firstSetId,
      restStartedAt: null,
      restTargetSeconds: null,
      note: '',
      revision: 0,
      anomaly: null,
      finishCheckpoint: null,
    );
  }

  static WorkoutSession transition(
    WorkoutSession session,
    WorkoutEvent event,
    DateTime nowUtc,
  ) {
    _requireUtc(nowUtc);
    if (session.phase == WorkoutPhase.saved) {
      throw StateError('A saved workout cannot be changed.');
    }
    if (session.phase == WorkoutPhase.timeAnomaly) {
      if (event is! ConfirmTime) {
        throw StateError('Confirm the time anomaly before continuing.');
      }
      return _confirmTime(session, event);
    }
    if (event is ConfirmTime) {
      throw StateError('There is no time anomaly to confirm.');
    }

    final anomaly = _firstAnomaly(session, nowUtc);
    if (anomaly != null) {
      return _enterTimeAnomaly(session, anomaly, nowUtc);
    }

    if (event is SelectSet) {
      return _selectSet(session, event);
    }
    if (event is StartSet) {
      return _startSet(session, event, nowUtc);
    }
    if (event is CompleteSet) {
      return _completeSet(session, event, nowUtc);
    }
    if (event is SkipSet) {
      return _skipSet(session, event, nowUtc);
    }
    if (event is SkipExercise) {
      return _skipExercise(session, event, nowUtc);
    }
    if (event is UpdateActual) {
      return _updateActual(session, event);
    }
    if (event is AddExercise) {
      return _addExercise(session, event);
    }
    if (event is AddSet) {
      return _addSet(session, event);
    }
    if (event is DeletePendingSet) {
      return _deletePendingSet(session, event, nowUtc);
    }
    if (event is ReorderPendingExercises) {
      return _reorderPendingExercises(session, event);
    }
    if (event is PrepareFinish) {
      return _prepareFinish(session, nowUtc);
    }
    if (event is ContinueWorkout) {
      return _continueWorkout(session, nowUtc);
    }
    if (event is SaveWorkout) {
      return _saveWorkout(session, event, nowUtc);
    }
    throw StateError('Unsupported workout event.');
  }

  static WorkoutSession _selectSet(
    WorkoutSession session,
    SelectSet event,
  ) {
    _requireEditable(session);
    _locateSet(session.exercises, event.setId);
    return session.copyWith(selectedSetId: event.setId);
  }

  static WorkoutSession _startSet(
    WorkoutSession session,
    StartSet event,
    DateTime nowUtc,
  ) {
    _requirePhase(
      session,
      const {
        WorkoutPhase.active,
        WorkoutPhase.resting,
        WorkoutPhase.completedPaused,
      },
    );
    if (session.activeSetId != null) {
      throw StateError('Only one set can be in progress.');
    }
    final location = _locateSet(session.exercises, event.setId);
    final set = location.set;
    if (set.status != SetStatus.pending) {
      throw StateError('Only a pending set can be started.');
    }

    var timer = session.timer;
    var preSetRestSeconds = set.preSetRestSeconds;
    if (session.phase == WorkoutPhase.completedPaused) {
      timer = timer.resume(nowUtc);
    } else if (session.phase == WorkoutPhase.resting) {
      preSetRestSeconds += session.restTimer.read(nowUtc).seconds;
    }
    final started = set.copyWith(
      status: SetStatus.inProgress,
      startedAt: nowUtc,
      preSetRestSeconds: preSetRestSeconds,
    );
    return session.copyWith(
      phase: WorkoutPhase.active,
      exercises: _replaceSet(session.exercises, location, started),
      timer: timer,
      setTimer: ActiveTimer(
        accumulatedActiveSeconds: set.setDurationSeconds,
        runningSegmentStartedAt: nowUtc,
      ),
      restTimer: ActiveTimer(),
      activeSetId: event.setId,
      selectedSetId: event.setId,
      restStartedAt: null,
      restTargetSeconds: null,
    );
  }

  static WorkoutSession _completeSet(
    WorkoutSession session,
    CompleteSet event,
    DateTime nowUtc,
  ) {
    _requirePhase(session, const {WorkoutPhase.active});
    if (session.activeSetId != event.setId) {
      throw StateError('Only the active set can be completed.');
    }
    if (event.actualWeight != null &&
        (!event.actualWeight!.isFinite || event.actualWeight! < 0)) {
      throw ArgumentError.value(event.actualWeight, 'actualWeight');
    }
    if (event.actualReps < 1) {
      throw ArgumentError.value(event.actualReps, 'actualReps');
    }
    final location = _locateSet(session.exercises, event.setId);
    if (location.set.status != SetStatus.inProgress) {
      throw StateError('The active set must be in progress.');
    }
    final duration = session.setTimer.read(nowUtc).seconds;
    final completed = location.set.copyWith(
      status: SetStatus.completed,
      actualWeight: event.actualWeight,
      actualReps: event.actualReps,
      completedAt: nowUtc,
      setDurationSeconds: duration,
    );
    final exercises = _replaceSet(session.exercises, location, completed);
    final nextPending = _firstPendingSetId(exercises);
    if (nextPending == null) {
      return session.copyWith(
        phase: WorkoutPhase.completedPaused,
        exercises: exercises,
        timer: session.timer.pause(nowUtc),
        setTimer: ActiveTimer(),
        restTimer: ActiveTimer(),
        activeSetId: null,
        selectedSetId: event.setId,
        restStartedAt: null,
        restTargetSeconds: null,
      );
    }
    final exercise = exercises[location.exerciseIndex];
    return session.copyWith(
      phase: WorkoutPhase.resting,
      exercises: exercises,
      setTimer: ActiveTimer(),
      restTimer: ActiveTimer(runningSegmentStartedAt: nowUtc),
      activeSetId: null,
      selectedSetId: nextPending,
      restStartedAt: nowUtc,
      restTargetSeconds: exercise.targetRestSeconds,
    );
  }

  static WorkoutSession _skipSet(
    WorkoutSession session,
    SkipSet event,
    DateTime nowUtc,
  ) {
    _requireEditable(session);
    final location = _locateSet(session.exercises, event.setId);
    final isActiveSet = location.set.status == SetStatus.inProgress &&
        session.activeSetId == event.setId;
    if (location.set.status != SetStatus.pending && !isActiveSet) {
      throw StateError('Only a pending or active set can be skipped.');
    }
    final settledSetTimer =
        isActiveSet ? session.setTimer.pause(nowUtc) : session.setTimer;
    final skipped = location.set.copyWith(
      status: SetStatus.skipped,
      skippedAt: nowUtc,
      setDurationSeconds: isActiveSet
          ? settledSetTimer.accumulatedActiveSeconds
          : location.set.setDurationSeconds,
    );
    final exercises = _replaceSet(session.exercises, location, skipped);
    final settledSession = isActiveSet
        ? session.copyWith(
            setTimer: settledSetTimer,
            activeSetId: null,
          )
        : session;
    return _afterRemovingPendingWork(settledSession, exercises, nowUtc);
  }

  static WorkoutSession _skipExercise(
    WorkoutSession session,
    SkipExercise event,
    DateTime nowUtc,
  ) {
    _requireEditable(session);
    final index = session.exercises.indexWhere(
      (exercise) => exercise.id == event.exerciseId,
    );
    if (index < 0) {
      throw StateError('Workout exercise not found.');
    }
    final exercise = session.exercises[index];
    final skipsActiveSet = exercise.sets.any(
      (set) =>
          set.status == SetStatus.inProgress && set.id == session.activeSetId,
    );
    final settledSetTimer =
        skipsActiveSet ? session.setTimer.pause(nowUtc) : session.setTimer;
    final sets = exercise.sets
        .map(
          (set) => set.status == SetStatus.pending ||
                  (set.status == SetStatus.inProgress &&
                      set.id == session.activeSetId)
              ? set.copyWith(
                  status: SetStatus.skipped,
                  skippedAt: nowUtc,
                  setDurationSeconds: set.status == SetStatus.inProgress
                      ? settledSetTimer.accumulatedActiveSeconds
                      : set.setDurationSeconds,
                )
              : set,
        )
        .toList();
    final exercises = session.exercises.toList();
    exercises[index] = exercise.copyWith(sets: sets);
    final settledSession = skipsActiveSet
        ? session.copyWith(
            setTimer: settledSetTimer,
            activeSetId: null,
          )
        : session;
    return _afterRemovingPendingWork(settledSession, exercises, nowUtc);
  }

  static WorkoutSession _updateActual(
    WorkoutSession session,
    UpdateActual event,
  ) {
    _requireEditable(session);
    if (event.weight != null &&
        (!event.weight!.isFinite || event.weight! < 0)) {
      throw ArgumentError.value(event.weight, 'weight');
    }
    if (event.reps < 0) {
      throw ArgumentError.value(event.reps, 'reps');
    }
    final location = _locateSet(session.exercises, event.setId);
    if (location.set.status == SetStatus.skipped) {
      throw StateError('A skipped set cannot be edited.');
    }
    final updated = location.set.copyWith(
      actualWeight: event.weight,
      actualReps: event.reps,
    );
    return session.copyWith(
      exercises: _replaceSet(session.exercises, location, updated),
    );
  }

  static WorkoutSession _addExercise(
    WorkoutSession session,
    AddExercise event,
  ) {
    _requireEditable(session);
    if (event.exercise.sets.any((set) => set.status != SetStatus.pending)) {
      throw StateError('New workout exercises must contain pending sets.');
    }
    if (session.exercises.any((exercise) => exercise.id == event.exercise.id)) {
      throw StateError('Workout exercise id already exists.');
    }
    final existingSetIds = session.exercises
        .expand((exercise) => exercise.sets)
        .map((set) => set.id)
        .toSet();
    if (event.exercise.sets.any((set) => existingSetIds.contains(set.id))) {
      throw StateError('Workout set id already exists.');
    }
    return session.copyWith(
      exercises: [...session.exercises, event.exercise],
      selectedSetId: session.selectedSetId ?? event.exercise.sets.first.id,
    );
  }

  static WorkoutSession _addSet(
    WorkoutSession session,
    AddSet event,
  ) {
    _requireEditable(session);
    if (event.set.status != SetStatus.pending) {
      throw StateError('A new workout set must be pending.');
    }
    if (session.exercises
        .expand((exercise) => exercise.sets)
        .any((set) => set.id == event.set.id)) {
      throw StateError('Workout set id already exists.');
    }
    final index = session.exercises.indexWhere(
      (exercise) => exercise.id == event.exerciseId,
    );
    if (index < 0) {
      throw StateError('Workout exercise not found.');
    }
    final exercises = session.exercises.toList();
    exercises[index] = exercises[index].copyWith(
      sets: [...exercises[index].sets, event.set],
    );
    return session.copyWith(
      exercises: exercises,
      selectedSetId: session.selectedSetId ?? event.set.id,
    );
  }

  static WorkoutSession _deletePendingSet(
    WorkoutSession session,
    DeletePendingSet event,
    DateTime nowUtc,
  ) {
    _requireEditable(session);
    final location = _locateSet(session.exercises, event.setId);
    if (location.set.status != SetStatus.pending) {
      throw StateError('Only a pending set can be deleted.');
    }
    final exercises = session.exercises.toList();
    final exercise = exercises[location.exerciseIndex];
    final sets = exercise.sets.toList()..removeAt(location.setIndex);
    if (sets.isEmpty) {
      exercises.removeAt(location.exerciseIndex);
    } else {
      exercises[location.exerciseIndex] = exercise.copyWith(sets: sets);
    }
    return _afterRemovingPendingWork(session, exercises, nowUtc);
  }

  static WorkoutSession _reorderPendingExercises(
    WorkoutSession session,
    ReorderPendingExercises event,
  ) {
    _requireEditable(session);
    final movable = session.exercises
        .where(
          (exercise) => exercise.sets.every(
            (set) =>
                set.status == SetStatus.pending ||
                set.status == SetStatus.skipped,
          ),
        )
        .toList();
    if (event.ids.length != movable.length ||
        event.ids.toSet().length != event.ids.length ||
        !event.ids
            .toSet()
            .containsAll(movable.map((exercise) => exercise.id))) {
      throw StateError('Reorder ids must contain every movable exercise once.');
    }
    final byId = {for (final exercise in movable) exercise.id: exercise};
    final ordered = event.ids.map((id) => byId[id]!).iterator;
    final exercises = session.exercises.map((exercise) {
      if (!byId.containsKey(exercise.id)) {
        return exercise;
      }
      ordered.moveNext();
      return ordered.current;
    }).toList();
    return session.copyWith(exercises: exercises);
  }

  static WorkoutSession _prepareFinish(
    WorkoutSession session,
    DateTime nowUtc,
  ) {
    _requirePhase(
      session,
      const {
        WorkoutPhase.active,
        WorkoutPhase.resting,
        WorkoutPhase.completedPaused,
      },
    );
    if (!session.hasCompletedSet) {
      throw StateError('At least one completed set is required to finish.');
    }
    final pausedTimer = session.timer.pause(nowUtc);
    final pausedSetTimer = session.setTimer.pause(nowUtc);
    final pausedRestTimer = session.restTimer.pause(nowUtc);
    final checkpoint = WorkoutFinishCheckpoint(
      phase: session.phase,
      exercises: session.exercises,
      timer: pausedTimer,
      setTimer: pausedSetTimer,
      restTimer: pausedRestTimer,
      activeSetId: session.activeSetId,
      selectedSetId: session.selectedSetId,
      restStartedAt: session.restStartedAt,
      restTargetSeconds: session.restTargetSeconds,
    );
    final finishingExercises = session.exercises
        .map(
          (exercise) => exercise.copyWith(
            sets: exercise.sets
                .map(
                  (set) => set.status == SetStatus.pending ||
                          set.status == SetStatus.inProgress
                      ? set.copyWith(
                          status: SetStatus.skipped,
                          skippedAt: nowUtc,
                        )
                      : set,
                )
                .toList(),
          ),
        )
        .toList();
    return session.copyWith(
      phase: WorkoutPhase.finishing,
      exercises: finishingExercises,
      timer: pausedTimer,
      setTimer: pausedSetTimer,
      restTimer: pausedRestTimer,
      activeSetId: null,
      restStartedAt: null,
      restTargetSeconds: null,
      finishCheckpoint: checkpoint,
    );
  }

  static WorkoutSession _continueWorkout(
    WorkoutSession session,
    DateTime nowUtc,
  ) {
    _requirePhase(session, const {WorkoutPhase.finishing});
    final checkpoint = session.finishCheckpoint;
    if (checkpoint == null) {
      throw StateError('A finish checkpoint is required to continue.');
    }
    var timer = checkpoint.timer;
    var setTimer = checkpoint.setTimer;
    var restTimer = checkpoint.restTimer;
    if (checkpoint.phase == WorkoutPhase.active) {
      timer = timer.resume(nowUtc);
      if (checkpoint.activeSetId != null) {
        setTimer = setTimer.resume(nowUtc);
      }
    } else if (checkpoint.phase == WorkoutPhase.resting) {
      timer = timer.resume(nowUtc);
      restTimer = restTimer.resume(nowUtc);
    }
    return session.copyWith(
      phase: checkpoint.phase,
      exercises: checkpoint.exercises,
      timer: timer,
      setTimer: setTimer,
      restTimer: restTimer,
      activeSetId: checkpoint.activeSetId,
      selectedSetId: checkpoint.selectedSetId,
      restStartedAt: checkpoint.restStartedAt,
      restTargetSeconds: checkpoint.restTargetSeconds,
      finishCheckpoint: null,
    );
  }

  static WorkoutSession _saveWorkout(
    WorkoutSession session,
    SaveWorkout event,
    DateTime nowUtc,
  ) {
    _requirePhase(session, const {WorkoutPhase.finishing});
    if (!session.hasCompletedSet) {
      throw StateError('At least one completed set is required to save.');
    }
    return session.copyWith(
      endedAt: nowUtc,
      phase: WorkoutPhase.saved,
      note: event.note,
      finishCheckpoint: null,
    );
  }

  static WorkoutSession _confirmTime(
    WorkoutSession session,
    ConfirmTime event,
  ) {
    _requireUtc(event.nowUtc);
    final anomaly = session.anomaly;
    if (anomaly == null) {
      throw StateError('Time anomaly details are missing.');
    }
    var timer = session.timer;
    var setTimer = session.setTimer;
    var restTimer = session.restTimer;
    if (anomaly.previousPhase == WorkoutPhase.active) {
      timer = timer.resume(event.nowUtc);
      if (session.activeSetId != null) {
        setTimer = setTimer.resume(event.nowUtc);
      }
    } else if (anomaly.previousPhase == WorkoutPhase.resting) {
      timer = timer.resume(event.nowUtc);
      restTimer = restTimer.resume(event.nowUtc);
    }
    return session.copyWith(
      phase: anomaly.previousPhase,
      timer: timer,
      setTimer: setTimer,
      restTimer: restTimer,
      anomaly: null,
    );
  }

  static TimerAnomalyReason? _firstAnomaly(
    WorkoutSession session,
    DateTime nowUtc,
  ) {
    for (final timer in [session.timer, session.setTimer, session.restTimer]) {
      final reading = timer.read(nowUtc);
      if (reading.isAnomaly) {
        return reading.reason;
      }
    }
    return null;
  }

  static WorkoutSession _enterTimeAnomaly(
    WorkoutSession session,
    TimerAnomalyReason reason,
    DateTime nowUtc,
  ) =>
      session.copyWith(
        phase: WorkoutPhase.timeAnomaly,
        timer: session.timer.discardRunningSegment(),
        setTimer: session.setTimer.discardRunningSegment(),
        restTimer: session.restTimer.discardRunningSegment(),
        anomaly: WorkoutTimeAnomaly(
          reason: reason,
          detectedAt: nowUtc,
          previousPhase: session.phase,
        ),
      );

  static WorkoutSession _afterRemovingPendingWork(
    WorkoutSession session,
    List<WorkoutExercise> exercises,
    DateTime nowUtc,
  ) {
    final nextPending = _firstPendingSetId(exercises);
    if (nextPending != null || session.activeSetId != null) {
      return session.copyWith(
        exercises: exercises,
        selectedSetId: session.selectedSetId != null &&
                _containsPendingSet(exercises, session.selectedSetId!)
            ? session.selectedSetId
            : nextPending,
      );
    }
    return session.copyWith(
      phase: WorkoutPhase.completedPaused,
      exercises: exercises,
      timer: session.timer.pause(nowUtc),
      setTimer: ActiveTimer(),
      restTimer: ActiveTimer(),
      activeSetId: null,
      selectedSetId: null,
      restStartedAt: null,
      restTargetSeconds: null,
    );
  }

  static void _requireEditable(WorkoutSession session) {
    _requirePhase(
      session,
      const {
        WorkoutPhase.active,
        WorkoutPhase.resting,
        WorkoutPhase.completedPaused,
      },
    );
  }

  static void _requirePhase(
    WorkoutSession session,
    Set<WorkoutPhase> phases,
  ) {
    if (!phases.contains(session.phase)) {
      throw StateError('Event is not valid during ${session.phase.name}.');
    }
  }

  static _SetLocation _locateSet(
    List<WorkoutExercise> exercises,
    String setId,
  ) {
    for (var exerciseIndex = 0;
        exerciseIndex < exercises.length;
        exerciseIndex++) {
      final sets = exercises[exerciseIndex].sets;
      final setIndex = sets.indexWhere((set) => set.id == setId);
      if (setIndex >= 0) {
        return _SetLocation(
          exerciseIndex: exerciseIndex,
          setIndex: setIndex,
          set: sets[setIndex],
        );
      }
    }
    throw StateError('Workout set not found.');
  }

  static List<WorkoutExercise> _replaceSet(
    List<WorkoutExercise> exercises,
    _SetLocation location,
    WorkoutSet replacement,
  ) {
    final result = exercises.toList();
    final exercise = result[location.exerciseIndex];
    final sets = exercise.sets.toList();
    sets[location.setIndex] = replacement;
    result[location.exerciseIndex] = exercise.copyWith(sets: sets);
    return result;
  }

  static String? _firstPendingSetId(List<WorkoutExercise> exercises) =>
      exercises
          .expand((exercise) => exercise.sets)
          .where((set) => set.status == SetStatus.pending)
          .firstOrNull
          ?.id;

  static bool _containsPendingSet(
    List<WorkoutExercise> exercises,
    String setId,
  ) =>
      exercises
          .expand((exercise) => exercise.sets)
          .any((set) => set.id == setId && set.status == SetStatus.pending);

  static void _requireUtc(DateTime value) {
    if (!value.isUtc) {
      throw ArgumentError.value(value, 'nowUtc', 'Must use UTC.');
    }
  }
}

final class _SetLocation {
  const _SetLocation({
    required this.exerciseIndex,
    required this.setIndex,
    required this.set,
  });

  final int exerciseIndex;
  final int setIndex;
  final WorkoutSet set;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
