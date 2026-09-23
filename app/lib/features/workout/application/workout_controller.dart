import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/local_date.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/active_timer.dart';
import '../domain/workout_draft.dart';
import '../domain/workout_event.dart';
import '../domain/workout_machine.dart';
import '../domain/workout_repository.dart';
import '../domain/workout_session.dart';
import 'rest_effects_controller.dart';
import 'workout_view_state.dart';

typedef WorkoutProjectionRefresh = Future<void> Function();
typedef WorkoutSessionIdFactory = String Function();

final class WorkoutController extends StateNotifier<WorkoutViewState> {
  WorkoutController({
    required WorkoutRepository repository,
    required Clock clock,
    WorkoutProjectionRefresh? refreshProjections,
    WorkoutSessionIdFactory? sessionIdFactory,
    RestEffectsController? restEffectsController,
    Future<AppSettings> Function()? restEffectsSettings,
  })  : _repository = repository,
        _clock = clock,
        _refreshProjections = refreshProjections,
        _sessionIdFactory = sessionIdFactory,
        _restEffectsController = restEffectsController,
        _restEffectsSettings = restEffectsSettings,
        super(const WorkoutViewState());

  final WorkoutRepository _repository;
  final Clock _clock;
  final WorkoutProjectionRefresh? _refreshProjections;
  final WorkoutSessionIdFactory? _sessionIdFactory;
  final RestEffectsController? _restEffectsController;
  final Future<AppSettings> Function()? _restEffectsSettings;
  final Set<String> _workoutScreenOwners = <String>{};
  Future<void> _commandTail = Future<void>.value();
  Future<void> _effectsTail = Future<void>.value();
  Future<void>? _restoreInFlight;
  Future<void> Function()? _pendingCommand;
  _PendingCommandKind? _pendingCommandKind;

  Future<String> start(WorkoutDraft draft) => _serialize(() async {
        await _recoverPendingRestoreForStart();
        _throwIfPendingFailure();
        final candidate = WorkoutMachine.start(
          id: _sessionIdFactory?.call() ?? _newSessionId(),
          draft: draft,
          nowUtc: _clock.nowUtc(),
        );
        var resolvedId = candidate.id;
        await _runPending(
          kind: _PendingCommandKind.start,
          candidate: candidate,
          command: () async {
            final current = state.session;
            final active =
                current != null && current.phase != WorkoutPhase.saved
                    ? current
                    : await _repository.findUnfinished();
            if (active != null) {
              resolvedId = active.id;
              state = WorkoutViewState(session: active);
              return;
            }
            await _createOrAcknowledge(candidate);
            final committed = await _repository.find(candidate.id);
            if (committed == null) {
              throw const AppFailure(
                FailureCode.persistence,
                detail: 'Created workout could not be read back.',
              );
            }
            state = WorkoutViewState(session: committed);
            _reconcileEffects(committed);
            await _refresh();
          },
        );
        return resolvedId;
      });

  Future<void> restore() {
    final inFlight = _restoreInFlight;
    if (inFlight != null) return inFlight;
    final restore = _restoreAndClear();
    _restoreInFlight = restore;
    return restore;
  }

  Future<void> _restoreAndClear() async {
    try {
      await _serialize(() async {
        _throwIfPendingFailure();
        late Future<void> Function() command;
        command = () async {
          final restored = await _repository.findUnfinished();
          state = WorkoutViewState(session: restored);
          _reconcileEffects(restored);
        };
        await _runPending(
          kind: _PendingCommandKind.restore,
          candidate: state.session,
          command: command,
        );
      });
    } finally {
      _restoreInFlight = null;
    }
  }

  Future<void> dispatch(WorkoutEvent event) => _serialize(() async {
        _throwIfPendingFailure();
        final committed = _requireSession();
        final candidate = _transition(committed, event, _clock.nowUtc());
        await _runPending(
          kind: _PendingCommandKind.mutation,
          candidate: candidate,
          command: () async {
            await _saveOrAcknowledge(candidate, committed.revision);
            final saved = await _repository.find(committed.id);
            if (saved == null) {
              throw const AppFailure(
                FailureCode.persistence,
                detail: 'Saved workout could not be read back.',
              );
            }
            state = WorkoutViewState(session: saved);
            _reconcileEffects(saved);
            await _refresh();
          },
        );
      });

  Future<LocalDate> save({required String note}) => _serialize(() async {
        _throwIfPendingFailure();
        final committed = _requireSession();
        final nowUtc = _clock.nowUtc();
        final candidate =
            _transition(committed, SaveWorkout(note: note), nowUtc);
        await _runPending(
          kind: _PendingCommandKind.mutation,
          candidate: candidate,
          command: () async {
            await _repository.saveCompleted(
              committed.id,
              note: note,
              expectedRevision: committed.revision,
              endedAtUtc: nowUtc,
            );
            final saved = await _repository.find(committed.id);
            if (saved == null) {
              throw const AppFailure(
                FailureCode.persistence,
                detail: 'Completed workout could not be read back.',
              );
            }
            state = const WorkoutViewState();
            _reconcileEffects(null);
            await _refresh();
          },
        );
        return committed.workoutDate;
      });

  Future<void> discard() => _serialize(() async {
        _throwIfPendingFailure();
        final committed = _requireSession();
        await _runPending(
          kind: _PendingCommandKind.mutation,
          candidate: committed,
          command: () async {
            await _repository.discard(committed.id);
            state = const WorkoutViewState();
            _reconcileEffects(null);
            await _refresh();
          },
        );
      });

  Future<void> retry() => _serialize(_retryPending);

  Future<void> _retryPending() async {
    final command = _pendingCommand;
    if (command == null) {
      throw StateError('There is no failed workout command to retry.');
    }
    state = state.copyWith(isSaving: true, failure: null);
    try {
      await command();
      _pendingCommand = null;
      _pendingCommandKind = null;
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(isSaving: false, failure: failure);
      throw failure;
    }
  }

  Future<void> _runPending({
    required _PendingCommandKind kind,
    required WorkoutSession? candidate,
    required Future<void> Function() command,
  }) async {
    _pendingCommand = command;
    _pendingCommandKind = kind;
    state = state.copyWith(
      isSaving: true,
      failure: null,
      pendingSession: candidate,
    );
    try {
      await command();
      _pendingCommand = null;
      _pendingCommandKind = null;
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(isSaving: false, failure: failure);
      throw failure;
    }
  }

  WorkoutSession _requireSession() =>
      state.session ?? (throw StateError('There is no active workout.'));

  WorkoutSession _transition(
    WorkoutSession session,
    WorkoutEvent event,
    DateTime nowUtc,
  ) {
    try {
      return WorkoutMachine.transition(session, event, nowUtc);
    } on Object catch (error) {
      final failure = _failureFrom(error);
      state = state.copyWith(isSaving: false, failure: failure);
      throw failure;
    }
  }

  void _throwIfPendingFailure() {
    if (_pendingCommand != null && state.failure != null) {
      throw state.failure!;
    }
  }

  Future<void> _recoverPendingRestoreForStart() async {
    if (_pendingCommand == null || state.failure == null) return;
    if (_pendingCommandKind != _PendingCommandKind.restore) {
      throw state.failure!;
    }
    await _retryPending();
  }

  Future<void> _refresh() async {
    final refresh = _refreshProjections;
    if (refresh != null) await refresh();
  }

  /// Presentation owns visibility; effects remain non-blocking for training.
  void setWorkoutScreenVisible(String owner, bool visible) {
    if (visible) {
      _workoutScreenOwners.add(owner);
    } else {
      _workoutScreenOwners.remove(owner);
    }
    _reconcileEffects(state.session);
  }

  /// Called after permission/settings changes and whenever the app resumes.
  Future<void> refreshRestEffects() => _reconcileEffects(state.session);

  Future<void> _reconcileEffects(WorkoutSession? session) {
    final effects = _restEffectsController;
    final loadSettings = _restEffectsSettings;
    if (effects == null || loadSettings == null) return Future<void>.value();
    final visible = _workoutScreenOwners.isNotEmpty;
    // Queue settings acquisition as well as platform work in commit order.
    _effectsTail = _effectsTail.catchError((_) {}).then((_) async {
      try {
        final persisted = await loadSettings();
        await effects.reconcile(
          session,
          persisted,
          isWorkoutVisible: visible,
        );
      } on Object {
        // Android effects cannot make a successful workout transaction fail.
      }
    });
    return _effectsTail;
  }

  Future<void> _saveOrAcknowledge(
    WorkoutSession candidate,
    int expectedRevision,
  ) async {
    try {
      await _repository.save(
        candidate,
        expectedRevision: expectedRevision,
      );
    } on AppFailure catch (failure) {
      if (failure.code != FailureCode.conflict) rethrow;
      final latest = await _repository.find(candidate.id);
      if (latest == null ||
          latest.revision != expectedRevision + 1 ||
          _sessionSignature(latest) != _sessionSignature(candidate)) {
        rethrow;
      }
    }
  }

  Future<void> _createOrAcknowledge(WorkoutSession candidate) async {
    try {
      await _repository.create(candidate);
    } on AppFailure catch (failure) {
      if (failure.code != FailureCode.conflict) rethrow;
      final existing = await _repository.find(candidate.id);
      if (existing == null ||
          existing.revision != 0 ||
          _sessionSignature(existing) != _sessionSignature(candidate)) {
        rethrow;
      }
    }
  }

  Future<T> _serialize<T>(Future<T> Function() command) {
    final completer = Completer<T>();
    _commandTail = _commandTail.then((_) async {
      try {
        completer.complete(await command());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  String _newSessionId() {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'workout-${_clock.nowUtc().microsecondsSinceEpoch}-$random';
  }

  static AppFailure _failureFrom(Object error) => error is AppFailure
      ? error
      : AppFailure(FailureCode.persistence, detail: error.toString());

  static String _sessionSignature(WorkoutSession session) => jsonEncode({
        'id': session.id,
        'date': session.workoutDate.iso8601,
        'startedAt': session.startedAt.toIso8601String(),
        'endedAt': session.endedAt?.toIso8601String(),
        'phase': session.phase.name,
        'exercises': session.exercises.map(_exerciseSignature).toList(),
        'timer': _timerSignature(session.timer),
        'setTimer': _timerSignature(session.setTimer),
        'restTimer': _timerSignature(session.restTimer),
        'activeSetId': session.activeSetId,
        'selectedSetId': session.selectedSetId,
        'restStartedAt': session.restStartedAt?.toIso8601String(),
        'restTargetSeconds': session.restTargetSeconds,
        'note': session.note,
        'anomaly': session.anomaly == null
            ? null
            : {
                'reason': session.anomaly!.reason.name,
                'detectedAt': session.anomaly!.detectedAt.toIso8601String(),
                'previousPhase': session.anomaly!.previousPhase.name,
              },
        'checkpoint': session.finishCheckpoint == null
            ? null
            : {
                'phase': session.finishCheckpoint!.phase.name,
                'exercises': session.finishCheckpoint!.exercises
                    .map(_exerciseSignature)
                    .toList(),
                'timer': _timerSignature(session.finishCheckpoint!.timer),
                'setTimer': _timerSignature(session.finishCheckpoint!.setTimer),
                'restTimer':
                    _timerSignature(session.finishCheckpoint!.restTimer),
                'activeSetId': session.finishCheckpoint!.activeSetId,
                'selectedSetId': session.finishCheckpoint!.selectedSetId,
                'restStartedAt':
                    session.finishCheckpoint!.restStartedAt?.toIso8601String(),
                'restTargetSeconds':
                    session.finishCheckpoint!.restTargetSeconds,
              },
      });

  static Map<String, Object?> _timerSignature(ActiveTimer timer) => {
        'seconds': timer.accumulatedActiveSeconds,
        'startedAt': timer.runningSegmentStartedAt?.toIso8601String(),
      };

  static Map<String, Object?> _exerciseSignature(WorkoutExercise exercise) => {
        'id': exercise.id,
        'exerciseId': exercise.exerciseId,
        'name': exercise.nameSnapshot,
        'category': exercise.categorySnapshot.name,
        'equipment': exercise.equipmentSnapshot.name,
        'unit': exercise.unitSnapshot.name,
        'sourcePlanId': exercise.sourcePlanId,
        'sourcePlanName': exercise.sourcePlanName,
        'sourceRevisionId': exercise.sourceRevisionId,
        'sourceDayNumber': exercise.sourceDayNumber,
        'sourceDayName': exercise.sourceDayName,
        'note': exercise.note,
        'targetRestSeconds': exercise.targetRestSeconds,
        'order': exercise.order,
        'temporary': exercise.temporary,
        'sets': exercise.sets
            .map(
              (set) => {
                'id': set.id,
                'order': set.order,
                'plannedWeight': set.plannedWeight,
                'plannedReps': set.plannedReps,
                'unit': set.unit.name,
                'actualWeight': set.actualWeight,
                'actualReps': set.actualReps,
                'status': set.status.name,
                'startedAt': set.startedAt?.toIso8601String(),
                'completedAt': set.completedAt?.toIso8601String(),
                'skippedAt': set.skippedAt?.toIso8601String(),
                'setDurationSeconds': set.setDurationSeconds,
                'preSetRestSeconds': set.preSetRestSeconds,
                'temporary': set.temporary,
              },
            )
            .toList(),
      };
}

enum _PendingCommandKind { start, restore, mutation }
