import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitness_counter/core/data/app_database.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/core/platform/android_notification_gateway.dart';
import 'package:fitness_counter/core/platform/android_vibration_gateway.dart';
import 'package:fitness_counter/core/platform/rest_effects_channel.dart';
import 'package:fitness_counter/core/platform/system_clock.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/application/workout_controller.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_draft.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const probeId = String.fromEnvironment('TASK14_PROCESS_PROBE_ID');
  if (probeId.isEmpty) {
    throw StateError('TASK14_PROCESS_PROBE_ID is required.');
  }

  final databaseDirectory = await getDatabasesPath();
  final filesDirectory = Directory(
    paths.join(paths.dirname(databaseDirectory), 'files'),
  );
  await filesDirectory.create(recursive: true);
  final marker = File(
    paths.join(filesDirectory.path, 'task14_workout_process_$probeId.json'),
  );
  final database = await AppDatabase.open(
    path: paths.join(
      databaseDirectory,
      'fitness_counter_task14_process_$probeId.db',
    ),
  );
  final controller = WorkoutController(
    repository: SqliteWorkoutRepository(database),
    clock: SystemClock(),
    sessionIdFactory: () => 'task14-process-$probeId',
  );
  try {
    final previous = await _readMarker(marker);
    final stage = previous['stage'] as String?;
    final next = switch (stage) {
      null => await _prepareActive(controller),
      'ACTIVE_READY' => await _restoreActiveAndPrepareRest(controller),
      'RESTING_READY' =>
        await _restoreRestAndPrepareCompletedPaused(controller, previous),
      'COMPLETED_PAUSED_READY' =>
        await _restoreCompletedPausedAndResume(controller, previous),
      'PROCESS_RECOVERY_PASS' => previous,
      _ => throw StateError('Unexpected process probe stage: $stage'),
    };
    await _writeMarker(marker, next);
    runApp(
      _ProbeApp(
        stage: next['stage']! as String,
        database: database,
        controller: controller,
      ),
    );
  } on Object catch (error, stackTrace) {
    await _writeMarker(marker, {
      'stage': 'PROCESS_RECOVERY_FAILED',
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    });
    runApp(
      _ProbeApp(
        stage: 'PROCESS_RECOVERY_FAILED: $error',
        database: database,
        controller: controller,
      ),
    );
  }
}

Future<Map<String, Object?>> _prepareActive(
  WorkoutController controller,
) async {
  final draft = WorkoutDraft(
    workoutDate: LocalDate.fromDateTime(DateTime.now()),
    exercises: [_baseExerciseA(), _baseExerciseB()],
  );
  final sessionId = await controller.start(draft);
  await controller.dispatch(AddExercise(_temporaryExercise()));
  await controller.dispatch(
    const ReorderPendingExercises(['probe-temp', 'probe-a', 'probe-b']),
  );
  await controller.dispatch(const SelectSet('probe-a-1'));
  await controller.dispatch(const StartSet('probe-a-1'));
  await controller.dispatch(
    const UpdateActual('probe-a-1', weight: 42.5, reps: 8),
  );
  _requireActiveSnapshot(controller.state.session!);
  return {'stage': 'ACTIVE_READY', 'sessionId': sessionId};
}

Future<Map<String, Object?>> _restoreActiveAndPrepareRest(
  WorkoutController controller,
) async {
  await controller.restore();
  final active = controller.state.session!;
  _requireActiveSnapshot(active);
  await controller.dispatch(
    const CompleteSet('probe-a-1', actualWeight: 42.5, actualReps: 8),
  );
  final resting = controller.state.session!;
  _require(resting.phase == WorkoutPhase.resting, 'Expected resting phase.');
  _require(resting.selectedSetId == 'probe-temp-1', 'Next set was not kept.');
  final restId = '${resting.id}${resting.restStartedAt!.toIso8601String()}';
  final dueAt = resting.restStartedAt!.add(
    Duration(seconds: resting.restTargetSeconds!),
  );
  final vibration = AndroidVibrationGateway();
  final vibrationScheduled = await vibration.hasVibrator();
  if (vibrationScheduled) {
    await vibration.scheduleRest(
      sessionId: resting.id,
      restId: restId,
      dueAtUtc: dueAt,
    );
  }
  final notification = AndroidNotificationGateway();
  final permission = await notification.permissionState();
  final notificationScheduled = permission.notificationsGranted;
  if (notificationScheduled) {
    await notification.scheduleRest(
      sessionId: resting.id,
      restId: restId,
      dueAtUtc: dueAt,
    );
  }
  return {
    'stage': 'RESTING_READY',
    'sessionId': resting.id,
    'restId': restId,
    'vibrationScheduled': vibrationScheduled,
    'notificationScheduled': notificationScheduled,
  };
}

Future<Map<String, Object?>> _restoreRestAndPrepareCompletedPaused(
  WorkoutController controller,
  Map<String, Object?> marker,
) async {
  await controller.restore();
  final resting = controller.state.session!;
  _require(
    resting.phase == WorkoutPhase.resting,
    'Rest phase was not restored.',
  );
  _require(resting.activeSetId == null, 'Rest restore started a set.');
  _require(resting.selectedSetId == 'probe-temp-1', 'Selected set was lost.');
  _require(
    resting.restTimer.runningSegmentStartedAt != null,
    'Rest timer stopped.',
  );
  _require(resting.exercises.first.temporary, 'Temporary row was lost.');
  _require(
    resting.exercises[1].sets.first.actualWeight == 42.5 &&
        resting.exercises[1].sets.first.actualReps == 8,
    'Actual values were lost.',
  );

  final restId = marker['restId']! as String;
  final nativeState =
      await RestEffectsChannel.methodChannel.invokeMapMethod<String, dynamic>(
    'debugDeliveryState',
    {RestEffectsChannel.restId: restId},
  );
  if (marker['vibrationScheduled'] == true) {
    _require(
      nativeState?['vibrationActive'] == true,
      'Vibration alarm was lost.',
    );
    await AndroidVibrationGateway().cancelRest(restId);
  }
  if (marker['notificationScheduled'] == true) {
    _require(
      nativeState?['notificationActive'] == true,
      'Notification alarm was lost.',
    );
    await AndroidNotificationGateway().cancelRest(restId);
  }

  await controller.dispatch(const StartSet('probe-temp-1'));
  await controller.dispatch(
    const CompleteSet('probe-temp-1', actualWeight: 0, actualReps: 12),
  );
  await controller.dispatch(const SkipSet('probe-a-2'));
  await controller.dispatch(const SkipSet('probe-b-1'));
  var completed = controller.state.session!;
  _require(
    completed.phase == WorkoutPhase.completedPaused,
    'Expected completedPaused after the last pending set.',
  );
  await controller.dispatch(
    AddSet(
      'probe-b',
      WorkoutSet(
        id: 'probe-resume-1',
        order: 1,
        plannedWeight: 30,
        plannedReps: 6,
        unit: WeightUnit.kg,
        temporary: true,
      ),
    ),
  );
  completed = controller.state.session!;
  _require(
    completed.phase == WorkoutPhase.completedPaused,
    'Editing resumed completedPaused timing.',
  );
  _require(
    completed.timer.runningSegmentStartedAt == null,
    'Completed timer was not frozen.',
  );
  return {
    'stage': 'COMPLETED_PAUSED_READY',
    'sessionId': completed.id,
    'frozenSeconds': completed.timer.accumulatedActiveSeconds,
    'restId': restId,
  };
}

Future<Map<String, Object?>> _restoreCompletedPausedAndResume(
  WorkoutController controller,
  Map<String, Object?> marker,
) async {
  await controller.restore();
  final completed = controller.state.session!;
  _require(
    completed.phase == WorkoutPhase.completedPaused,
    'completedPaused was not restored.',
  );
  _require(
    completed.timer.runningSegmentStartedAt == null &&
        completed.timer.accumulatedActiveSeconds == marker['frozenSeconds'],
    'Frozen active time changed across process loss.',
  );
  final resumeSet = completed.exercises
      .expand((exercise) => exercise.sets)
      .singleWhere((set) => set.id == 'probe-resume-1');
  _require(resumeSet.temporary, 'Temporary resume set was lost.');
  await controller.dispatch(const StartSet('probe-resume-1'));
  final resumed = controller.state.session!;
  _require(
    resumed.phase == WorkoutPhase.active,
    'Starting did not resume timing.',
  );
  _require(
    resumed.timer.runningSegmentStartedAt != null,
    'Resumed active timer has no running segment.',
  );
  final nativeState =
      await RestEffectsChannel.methodChannel.invokeMapMethod<String, dynamic>(
    'debugDeliveryState',
    {RestEffectsChannel.restId: marker['restId']! as String},
  );
  _require(
    nativeState?['vibrationActive'] != true &&
        nativeState?['notificationActive'] != true,
    'Obsolete rest effects remained scheduled.',
  );
  return {
    'stage': 'PROCESS_RECOVERY_PASS',
    'sessionId': resumed.id,
    'restId': marker['restId'],
    'frozenSeconds': marker['frozenSeconds'],
  };
}

void _requireActiveSnapshot(WorkoutSession session) {
  _require(session.phase == WorkoutPhase.active, 'Expected active phase.');
  _require(session.activeSetId == 'probe-a-1', 'Active set was lost.');
  _require(session.selectedSetId == 'probe-a-1', 'Selected set was lost.');
  _require(
    session.timer.runningSegmentStartedAt != null,
    'Active timer stopped.',
  );
  _require(
    session.exercises.map((item) => item.id).join(',') ==
        'probe-temp,probe-a,probe-b',
    'Exercise order was lost.',
  );
  _require(session.exercises.first.temporary, 'Temporary exercise was lost.');
  final active = session.exercises[1].sets.first;
  _require(
    active.actualWeight == 42.5 && active.actualReps == 8,
    'Active actuals were lost.',
  );
}

WorkoutExercise _baseExerciseA() => WorkoutExercise(
      id: 'probe-a',
      exerciseId: 'catalog-a',
      nameSnapshot: '进程恢复卧推',
      categorySnapshot: ExerciseCategory.chest,
      equipmentSnapshot: ExerciseEquipment.barbell,
      unitSnapshot: WeightUnit.kg,
      sourcePlanId: 'probe-plan',
      sourcePlanName: '进程恢复计划',
      sourceRevisionId: 'probe-revision',
      sourceDayNumber: 1,
      sourceDayName: '训练日',
      note: '',
      targetRestSeconds: 600,
      order: 0,
      temporary: false,
      sets: [
        _set('probe-a-1', 0, 40, 8),
        _set('probe-a-2', 1, 40, 8),
      ],
    );

WorkoutExercise _baseExerciseB() => WorkoutExercise(
      id: 'probe-b',
      exerciseId: 'catalog-b',
      nameSnapshot: '进程恢复划船',
      categorySnapshot: ExerciseCategory.back,
      equipmentSnapshot: ExerciseEquipment.cable,
      unitSnapshot: WeightUnit.kg,
      note: '',
      targetRestSeconds: 600,
      order: 1,
      temporary: false,
      sets: [_set('probe-b-1', 0, 30, 10)],
    );

WorkoutExercise _temporaryExercise() => WorkoutExercise(
      id: 'probe-temp',
      exerciseId: 'catalog-temp',
      nameSnapshot: '临时深蹲',
      categorySnapshot: ExerciseCategory.legs,
      equipmentSnapshot: ExerciseEquipment.dumbbell,
      unitSnapshot: WeightUnit.kg,
      note: '',
      targetRestSeconds: 600,
      order: 2,
      temporary: true,
      sets: [_set('probe-temp-1', 0, 0, 12, temporary: true)],
    );

WorkoutSet _set(
  String id,
  int order,
  double weight,
  int reps, {
  bool temporary = false,
}) =>
    WorkoutSet(
      id: id,
      order: order,
      plannedWeight: weight,
      plannedReps: reps,
      unit: WeightUnit.kg,
      temporary: temporary,
    );

Future<Map<String, Object?>> _readMarker(File marker) async {
  if (!await marker.exists()) return <String, Object?>{};
  return (jsonDecode(await marker.readAsString()) as Map)
      .cast<String, Object?>();
}

Future<void> _writeMarker(
  File marker,
  Map<String, Object?> value,
) async {
  await marker.writeAsString(jsonEncode(value), flush: true);
  // ignore: avoid_print
  print('TASK14_PROCESS_PROBE ${value['stage']} ${jsonEncode(value)}');
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final class _ProbeApp extends StatefulWidget {
  const _ProbeApp({
    required this.stage,
    required this.database,
    required this.controller,
  });

  final String stage;
  final AppDatabase database;
  final WorkoutController controller;

  @override
  State<_ProbeApp> createState() => _ProbeAppState();
}

final class _ProbeAppState extends State<_ProbeApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    unawaited(widget.database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(widget.stage, textDirection: TextDirection.ltr),
          ),
        ),
      );
}
