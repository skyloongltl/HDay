import 'package:flutter/foundation.dart';

import '../../../core/platform/notification_gateway.dart';
import '../../../core/platform/vibration_gateway.dart';
import '../../../core/platform/wake_lock_gateway.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/workout_session.dart';

/// Live system projection, never persisted as a user preference.
final class RestEffectsStatus {
  const RestEffectsStatus({
    this.permission,
    this.notificationScheduled = false,
    this.vibrationScheduled = false,
    this.isTimingDegraded = false,
    this.hasFailure = false,
  });
  final NotificationPermissionState? permission;
  final bool notificationScheduled;
  final bool vibrationScheduled;
  final bool isTimingDegraded;
  final bool hasFailure;

  RestEffectsStatus copyWith({
    NotificationPermissionState? permission,
    bool clearPermission = false,
    bool? notificationScheduled,
    bool? vibrationScheduled,
    bool? isTimingDegraded,
    bool? hasFailure,
  }) =>
      RestEffectsStatus(
        permission: clearPermission ? null : permission ?? this.permission,
        notificationScheduled:
            notificationScheduled ?? this.notificationScheduled,
        vibrationScheduled: vibrationScheduled ?? this.vibrationScheduled,
        isTimingDegraded: isTimingDegraded ?? this.isTimingDegraded,
        hasFailure: hasFailure ?? this.hasFailure,
      );
}

/// Effects are independent and serialized in invocation order.
final class RestEffectsController {
  RestEffectsController({
    required NotificationGateway notificationGateway,
    required VibrationGateway vibrationGateway,
    required WakeLockGateway wakeLockGateway,
  })  : _notificationGateway = notificationGateway,
        _vibrationGateway = vibrationGateway,
        _wakeLockGateway = wakeLockGateway;

  final NotificationGateway _notificationGateway;
  final VibrationGateway _vibrationGateway;
  final WakeLockGateway _wakeLockGateway;
  final status = ValueNotifier(const RestEffectsStatus());
  String? _notificationRestId;
  String? _vibrationRestId;
  bool? _notificationExact;
  bool? _vibrationExact;
  bool _wakeLockEnabled = false;
  bool _hasFailure = false;
  bool _disposed = false;
  Future<void> _tail = Future<void>.value();

  Future<void> reconcile(
    WorkoutSession? session,
    AppSettings settings, {
    bool isWorkoutVisible = false,
  }) {
    if (_disposed) return Future<void>.value();
    _tail = _tail
        .catchError((_) {})
        .then((_) => _reconcile(session, settings, isWorkoutVisible));
    return _tail;
  }

  Future<NotificationPermissionState> permissionState() =>
      _notificationGateway.permissionState();

  Future<void> refreshPermission() async {
    try {
      status.value = status.value.copyWith(
        permission: await permissionState(),
        hasFailure: false,
      );
    } on Object {
      status.value = status.value.copyWith(hasFailure: true);
    }
  }

  Future<void> requestNotificationPermission() =>
      _notificationGateway.requestNotificationPermission();

  Future<void> requestExactAlarmPermission() =>
      _notificationGateway.requestExactAlarmPermission();

  Future<void> _reconcile(
    WorkoutSession? session,
    AppSettings settings,
    bool visible,
  ) async {
    _hasFailure = false;
    NotificationPermissionState? permission;
    await _attempt(() async {
      permission = await permissionState();
    });
    final exact = permission?.exactAlarmsGranted;
    final isResting = session?.phase == WorkoutPhase.resting &&
        session?.restStartedAt != null &&
        session?.restTargetSeconds != null;
    final restId = isResting
        ? '${session!.id}${session.restStartedAt!.toIso8601String()}'
        : null;
    final due = isResting
        ? session!.restStartedAt!
            .add(Duration(seconds: session.restTargetSeconds!))
        : null;
    _notificationRestId = await _reconcileAlarm(
      _notificationRestId,
      settings.restReminder && permission?.notificationsGranted == true
          ? restId
          : null,
      _notificationExact != exact,
      _notificationGateway.cancelRest,
      (id) async {
        await _notificationGateway.scheduleRest(
          sessionId: session!.id,
          restId: id,
          dueAtUtc: due!,
        );
        _notificationExact = exact;
      },
    );
    var canVibrate = false;
    if (isResting && settings.vibration) {
      await _attempt(() async {
        canVibrate = await _vibrationGateway.hasVibrator();
      });
    }
    _vibrationRestId = await _reconcileAlarm(
      _vibrationRestId,
      canVibrate ? restId : null,
      _vibrationExact != exact,
      _vibrationGateway.cancelRest,
      (id) async {
        await _vibrationGateway.scheduleRest(
          sessionId: session!.id,
          restId: id,
          dueAtUtc: due!,
        );
        _vibrationExact = exact;
      },
    );
    final awake = settings.screenAwake &&
        visible &&
        (session?.phase == WorkoutPhase.active || isResting);
    if (awake != _wakeLockEnabled &&
        await _attempt(() => _wakeLockGateway.setEnabled(awake))) {
      _wakeLockEnabled = awake;
    }
    status.value = RestEffectsStatus(
      permission: permission,
      notificationScheduled: _notificationRestId != null,
      vibrationScheduled: _vibrationRestId != null,
      isTimingDegraded:
          (_notificationRestId != null && _notificationExact != true) ||
              (_vibrationRestId != null && _vibrationExact != true),
      hasFailure: _hasFailure,
    );
  }

  Future<String?> _reconcileAlarm(
    String? current,
    String? desired,
    bool timingChanged,
    Future<void> Function(String) cancel,
    Future<void> Function(String) schedule,
  ) async {
    if (current == desired && !timingChanged) return current;
    if (current != null) {
      final previous = current;
      if (!await _attempt(() => cancel(previous))) return current;
      current = null;
    }
    if (desired != null && await _attempt(() => schedule(desired))) {
      return desired;
    }
    return current;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _tail.catchError((_) {});
    if (_notificationRestId case final id?) {
      await _attempt(() => _notificationGateway.cancelRest(id));
    }
    if (_vibrationRestId case final id?) {
      await _attempt(() => _vibrationGateway.cancelRest(id));
    }
    if (_wakeLockEnabled) {
      await _attempt(() => _wakeLockGateway.setEnabled(false));
    }
    status.dispose();
  }

  Future<bool> _attempt(Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } on Object {
      _hasFailure = true;
      return false;
    }
  }
}
