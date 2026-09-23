import 'package:flutter/services.dart';

import 'notification_gateway.dart';
import 'rest_effects_channel.dart';

final class AndroidNotificationGateway implements NotificationGateway {
  AndroidNotificationGateway({MethodChannel? channel})
      : _channel = channel ?? RestEffectsChannel.methodChannel;

  final MethodChannel _channel;

  @override
  Future<NotificationPermissionState> permissionState() async {
    final state = await _channel.invokeMapMethod<String, dynamic>(
      'permissionState',
    );
    return NotificationPermissionState(
      notificationsGranted:
          state?[RestEffectsChannel.notificationsGranted] == true,
      exactAlarmsGranted: state?[RestEffectsChannel.exactAlarmsGranted] == true,
    );
  }

  @override
  Future<void> requestNotificationPermission() =>
      _channel.invokeMethod<void>('requestNotificationPermission');

  @override
  Future<void> requestExactAlarmPermission() =>
      _channel.invokeMethod<void>('requestExactAlarmPermission');

  @override
  Future<void> scheduleRest({
    required String sessionId,
    required String restId,
    required DateTime dueAtUtc,
  }) =>
      _channel.invokeMethod<void>(
        'scheduleNotificationRest',
        _arguments(
          sessionId: sessionId,
          restId: restId,
          dueAtUtc: dueAtUtc,
        ),
      );

  @override
  Future<void> cancelRest(String restId) => _channel.invokeMethod<void>(
        'cancelNotificationRest',
        {RestEffectsChannel.restId: restId},
      );
}

Map<String, Object> _arguments({
  required String sessionId,
  required String restId,
  required DateTime dueAtUtc,
}) =>
    {
      RestEffectsChannel.sessionId: sessionId,
      RestEffectsChannel.restId: restId,
      RestEffectsChannel.dueAtUtcMillis:
          dueAtUtc.toUtc().millisecondsSinceEpoch,
    };
