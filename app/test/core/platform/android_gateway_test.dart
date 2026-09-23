import 'package:fitness_counter/core/platform/android_notification_gateway.dart';
import 'package:fitness_counter/core/platform/android_vibration_gateway.dart';
import 'package:fitness_counter/core/platform/android_wake_lock_gateway.dart';
import 'package:fitness_counter/core/platform/notification_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('fitness_counter/rest_effects');
  final calls = <MethodCall>[];

  setUp(() async {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'permissionState' => <String, bool>{
            'notificationsGranted': false,
            'exactAlarmsGranted': true,
          },
        'hasVibrator' => true,
        _ => null,
      };
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('notification permission and exact-alarm authorization are independent',
      () async {
    final gateway = AndroidNotificationGateway(channel: channel);

    expect(
      await gateway.permissionState(),
      const NotificationPermissionState(
        notificationsGranted: false,
        exactAlarmsGranted: true,
      ),
    );

    await gateway.requestNotificationPermission();
    await gateway.requestExactAlarmPermission();

    expect(calls.map((call) => call.method), [
      'permissionState',
      'requestNotificationPermission',
      'requestExactAlarmPermission',
    ]);
  });

  test('notification and vibration use stable rest identity arguments',
      () async {
    final dueAtUtc = DateTime.utc(2026, 9, 17, 8, 30);
    final notification = AndroidNotificationGateway(channel: channel);
    final vibration = AndroidVibrationGateway(channel: channel);

    await notification.scheduleRest(
      sessionId: 'session-1',
      restId: 'session-12026-09-17T08:00:00.000Z',
      dueAtUtc: dueAtUtc,
    );
    await vibration.scheduleRest(
      sessionId: 'session-1',
      restId: 'session-12026-09-17T08:00:00.000Z',
      dueAtUtc: dueAtUtc,
    );
    await notification.cancelRest('session-12026-09-17T08:00:00.000Z');
    await vibration.cancelRest('session-12026-09-17T08:00:00.000Z');

    expect(calls.map((call) => call.method), [
      'scheduleNotificationRest',
      'scheduleVibrationRest',
      'cancelNotificationRest',
      'cancelVibrationRest',
    ]);
    expect(calls.first.arguments, {
      'sessionId': 'session-1',
      'restId': 'session-12026-09-17T08:00:00.000Z',
      'dueAtUtcMillis': dueAtUtc.millisecondsSinceEpoch,
    });
  });

  test('wake lock and foreground pulse are forwarded independently', () async {
    final vibration = AndroidVibrationGateway(channel: channel);
    final wakeLock = AndroidWakeLockGateway(channel: channel);

    expect(await vibration.hasVibrator(), isTrue);
    await vibration.pulse();
    await wakeLock.setEnabled(true);
    await wakeLock.setEnabled(false);

    expect(calls.map((call) => call.method), [
      'hasVibrator',
      'pulseVibration',
      'setWakeLockEnabled',
      'setWakeLockEnabled',
    ]);
  });
}
