import 'package:fitness_counter/core/platform/notification_gateway.dart';
import 'package:fitness_counter/core/platform/vibration_gateway.dart';
import 'package:fitness_counter/core/platform/wake_lock_gateway.dart';
import 'package:fitness_counter/features/workout/application/rest_effects_controller.dart';

final class EffectHarness {
  final notification = TestNotification();
  final vibration = TestVibration();
  final wake = TestWake();
  late final effects = RestEffectsController(
    notificationGateway: notification,
    vibrationGateway: vibration,
    wakeLockGateway: wake,
  );
}

final class TestNotification implements NotificationGateway {
  final active = <String>{};
  final events = <String>[];
  bool failQuery = false;
  bool granted = true;
  bool exact = true;
  bool failRequest = false;
  int requestNotificationCount = 0;
  int requestExactCount = 0;
  @override
  Future<NotificationPermissionState> permissionState() async {
    if (failQuery) throw StateError('query failed');
    return NotificationPermissionState(
      notificationsGranted: granted,
      exactAlarmsGranted: exact,
    );
  }

  @override
  Future<void> scheduleRest({
    required String sessionId,
    required String restId,
    required DateTime dueAtUtc,
  }) async {
    events.add('schedule');
    active.add(restId);
  }

  @override
  Future<void> cancelRest(String restId) async {
    events.add('cancel');
    active.remove(restId);
  }

  @override
  Future<void> requestExactAlarmPermission() async {
    requestExactCount++;
    if (failRequest) throw StateError('request exact failed');
  }

  @override
  Future<void> requestNotificationPermission() async {
    requestNotificationCount++;
    if (failRequest) throw StateError('request notification failed');
  }
}

final class TestVibration implements VibrationGateway {
  final active = <String>{};
  final events = <String>[];
  @override
  Future<bool> hasVibrator() async => true;
  @override
  Future<void> pulse() async {
    throw StateError('Rest delivery must be keyed');
  }

  @override
  Future<void> scheduleRest({
    required String sessionId,
    required String restId,
    required DateTime dueAtUtc,
  }) async {
    events.add('schedule');
    active.add(restId);
  }

  @override
  Future<void> cancelRest(String restId) async {
    events.add('cancel');
    active.remove(restId);
  }
}

final class TestWake implements WakeLockGateway {
  final values = <bool>[];
  @override
  Future<void> setEnabled(bool enabled) async {
    values.add(enabled);
  }
}
