import 'package:fitness_counter/core/platform/notification_gateway.dart';
import 'package:fitness_counter/core/platform/vibration_gateway.dart';
import 'package:fitness_counter/core/platform/wake_lock_gateway.dart';
import 'package:fitness_counter/features/settings/domain/app_settings.dart';
import 'package:fitness_counter/features/workout/application/rest_effects_controller.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/workout_fixtures.dart';

void main() {
  test('publishes degraded exact-denied state and refreshes to granted',
      () async {
    final notification = _RecordingNotificationGateway()..exactGranted = false;
    final effects = RestEffectsController(
      notificationGateway: notification,
      vibrationGateway: _RecordingVibrationGateway(),
      wakeLockGateway: _RecordingWakeLockGateway(),
    );
    await effects.reconcile(_restingSession(), AppSettings());
    expect(effects.status.value.permission?.exactAlarmsGranted, isFalse);
    expect(effects.status.value.isTimingDegraded, isTrue);
    notification.exactGranted = true;
    await effects.reconcile(_restingSession(), AppSettings());
    expect(effects.status.value.permission?.exactAlarmsGranted, isTrue);
    expect(effects.status.value.isTimingDegraded, isFalse);
    expect(notification.scheduled, hasLength(2));
  });
  test('failed notification schedule retries while vibration and wake continue',
      () async {
    final notification = _RecordingNotificationGateway()..failSchedule = true;
    final vibration = _RecordingVibrationGateway();
    final wake = _RecordingWakeLockGateway();
    final effects = RestEffectsController(
      notificationGateway: notification,
      vibrationGateway: vibration,
      wakeLockGateway: wake,
    );
    await effects.reconcile(
      _restingSession(),
      AppSettings(),
      isWorkoutVisible: true,
    );
    expect(vibration.scheduled, hasLength(1));
    expect(wake.values, [true]);
    notification.failSchedule = false;
    await effects.reconcile(
      _restingSession(),
      AppSettings(),
      isWorkoutVisible: true,
    );
    expect(notification.scheduled, hasLength(1));
  });

  test('failed cancellation retries without blocking vibration or wake release',
      () async {
    final notification = _RecordingNotificationGateway();
    final vibration = _RecordingVibrationGateway();
    final wake = _RecordingWakeLockGateway();
    final effects = RestEffectsController(
      notificationGateway: notification,
      vibrationGateway: vibration,
      wakeLockGateway: wake,
    );
    await effects.reconcile(
      _restingSession(),
      AppSettings(),
      isWorkoutVisible: true,
    );
    notification.failCancel = true;
    await effects.reconcile(null, AppSettings());
    expect(vibration.cancelled, hasLength(1));
    expect(wake.values, [true, false]);
    notification.failCancel = false;
    await effects.reconcile(null, AppSettings());
    expect(notification.cancelled, hasLength(1));
  });

  test('dispose releases wake even when notification cancellation fails',
      () async {
    final notification = _RecordingNotificationGateway();
    final vibration = _RecordingVibrationGateway();
    final wake = _RecordingWakeLockGateway();
    final effects = RestEffectsController(
      notificationGateway: notification,
      vibrationGateway: vibration,
      wakeLockGateway: wake,
    );
    await effects.reconcile(
      _restingSession(),
      AppSettings(),
      isWorkoutVisible: true,
    );
    notification.failCancel = true;
    await effects.dispose();
    expect(vibration.cancelled, hasLength(1));
    expect(wake.values, [true, false]);
  });

  test('failed wake enable retries on the next reconcile', () async {
    final wake = _RecordingWakeLockGateway()..fail = true;
    final effects = RestEffectsController(
      notificationGateway: _RecordingNotificationGateway(),
      vibrationGateway: _RecordingVibrationGateway(),
      wakeLockGateway: wake,
    );
    await effects.reconcile(
      _restingSession(),
      AppSettings(),
      isWorkoutVisible: true,
    );
    wake.fail = false;
    await effects.reconcile(
      _restingSession(),
      AppSettings(),
      isWorkoutVisible: true,
    );
    expect(wake.values, [true]);
  });

  test(
      'permission query failure does not block independent effects or future grant',
      () async {
    final notification = _RecordingNotificationGateway()..failQuery = true;
    final vibration = _RecordingVibrationGateway();
    final effects = RestEffectsController(
      notificationGateway: notification,
      vibrationGateway: vibration,
      wakeLockGateway: _RecordingWakeLockGateway(),
    );
    await effects.reconcile(_restingSession(), AppSettings());
    expect(vibration.scheduled, hasLength(1));
    notification.failQuery = false;
    notification.notificationsGranted = false;
    await effects.reconcile(_restingSession(), AppSettings());
    expect(notification.scheduled, isEmpty);
    notification.notificationsGranted = true;
    await effects.reconcile(_restingSession(), AppSettings());
    expect(notification.scheduled, hasLength(1));
  });

  test('reconciles every reminder and vibration settings combination once',
      () async {
    for (final combination in <(bool, bool)>[
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    ]) {
      final notification = _RecordingNotificationGateway();
      final vibration = _RecordingVibrationGateway();
      final controller = RestEffectsController(
        notificationGateway: notification,
        vibrationGateway: vibration,
        wakeLockGateway: _RecordingWakeLockGateway(),
      );
      final session = _restingSession();
      final settings = AppSettings(
        restReminder: combination.$1,
        vibration: combination.$2,
      );

      await controller.reconcile(session, settings);
      await controller.reconcile(session, settings);

      expect(
        notification.scheduled.length,
        combination.$1 ? 1 : 0,
        reason: 'notification=$combination',
      );
      expect(
        vibration.scheduled.length,
        combination.$2 ? 1 : 0,
        reason: 'vibration=$combination',
      );
    }
  });

  test('cancels both effects when rest exits, session saves, or is discarded',
      () async {
    final notification = _RecordingNotificationGateway();
    final vibration = _RecordingVibrationGateway();
    final controller = RestEffectsController(
      notificationGateway: notification,
      vibrationGateway: vibration,
      wakeLockGateway: _RecordingWakeLockGateway(),
    );
    final settings = AppSettings();

    await controller.reconcile(_restingSession(), settings);
    await controller.reconcile(null, settings);

    expect(notification.cancelled, hasLength(1));
    expect(vibration.cancelled, hasLength(1));
  });

  test(
      'removes notification after permission is revoked without stopping vibration',
      () async {
    final notification = _RecordingNotificationGateway();
    final vibration = _RecordingVibrationGateway();
    final controller = RestEffectsController(
      notificationGateway: notification,
      vibrationGateway: vibration,
      wakeLockGateway: _RecordingWakeLockGateway(),
    );
    final session = _restingSession();

    await controller.reconcile(session, AppSettings());
    notification.notificationsGranted = false;
    await controller.reconcile(session, AppSettings());

    expect(notification.cancelled, [notification.scheduled.single]);
    expect(vibration.cancelled, isEmpty);
  });

  test('does not turn a reached rest target into StartSet', () async {
    final notification = _RecordingNotificationGateway();
    final controller = RestEffectsController(
      notificationGateway: notification,
      vibrationGateway: _RecordingVibrationGateway(),
      wakeLockGateway: _RecordingWakeLockGateway(),
    );
    final session = _restingSession().copyWith(
      restStartedAt: DateTime.parse(_start).toUtc(),
      restTargetSeconds: 0,
    );

    await controller.reconcile(session, AppSettings());

    expect(notification.scheduled, hasLength(1));
    expect(session.phase, WorkoutPhase.resting);
    expect(session.activeSetId, isNull);
  });

  test('holds screen awake only for visible active or resting workout pages',
      () async {
    final wakeLock = _RecordingWakeLockGateway();
    final controller = RestEffectsController(
      notificationGateway: _RecordingNotificationGateway(),
      vibrationGateway: _RecordingVibrationGateway(),
      wakeLockGateway: wakeLock,
    );
    final settings = AppSettings(screenAwake: true);

    await controller.reconcile(
      _restingSession(),
      settings,
      isWorkoutVisible: true,
    );
    await controller.reconcile(
      _restingSession(),
      settings,
      isWorkoutVisible: false,
    );
    await controller.dispose();

    expect(wakeLock.values, [true, false]);
  });
}

WorkoutSession _restingSession() {
  final now = DateTime.parse(_start).toUtc();
  final active = WorkoutMachine.start(
    id: 'session-1',
    draft: twoSetDraft(),
    nowUtc: now,
  );
  final inProgress = WorkoutMachine.transition(
    active,
    const StartSet('s1'),
    now,
  );
  return WorkoutMachine.transition(
    inProgress,
    const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    now,
  );
}

const _start = '2026-09-17T08:00:00.000Z';

final class _RecordingNotificationGateway implements NotificationGateway {
  final scheduled = <String>[];
  final cancelled = <String>[];
  bool notificationsGranted = true;
  bool exactGranted = true;
  bool failSchedule = false;
  bool failCancel = false;
  bool failQuery = false;

  @override
  Future<void> cancelRest(String restId) async {
    if (failCancel) throw StateError('cancel failed');
    cancelled.add(restId);
  }

  @override
  Future<NotificationPermissionState> permissionState() async {
    if (failQuery) throw StateError('query failed');
    return NotificationPermissionState(
      notificationsGranted: notificationsGranted,
      exactAlarmsGranted: exactGranted,
    );
  }

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> requestNotificationPermission() async {}

  @override
  Future<void> scheduleRest({
    required String sessionId,
    required String restId,
    required DateTime dueAtUtc,
  }) async {
    if (failSchedule) throw StateError('schedule failed');
    scheduled.add(restId);
  }
}

final class _RecordingVibrationGateway implements VibrationGateway {
  final scheduled = <String>[];
  final cancelled = <String>[];

  @override
  Future<void> cancelRest(String restId) async => cancelled.add(restId);

  @override
  Future<bool> hasVibrator() async => true;

  @override
  Future<void> pulse() async {}

  @override
  Future<void> scheduleRest({
    required String sessionId,
    required String restId,
    required DateTime dueAtUtc,
  }) async =>
      scheduled.add(restId);
}

final class _RecordingWakeLockGateway implements WakeLockGateway {
  final values = <bool>[];
  bool fail = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    if (fail) throw StateError('wake failed');
    values.add(enabled);
  }
}
