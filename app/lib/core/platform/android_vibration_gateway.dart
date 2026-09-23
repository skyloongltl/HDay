import 'package:flutter/services.dart';

import 'rest_effects_channel.dart';
import 'vibration_gateway.dart';

final class AndroidVibrationGateway implements VibrationGateway {
  AndroidVibrationGateway({MethodChannel? channel})
      : _channel = channel ?? RestEffectsChannel.methodChannel;

  final MethodChannel _channel;

  @override
  Future<bool> hasVibrator() async =>
      await _channel.invokeMethod<bool>('hasVibrator') ?? false;

  @override
  Future<void> pulse() => _channel.invokeMethod<void>('pulseVibration');

  @override
  Future<void> scheduleRest({
    required String sessionId,
    required String restId,
    required DateTime dueAtUtc,
  }) =>
      _channel.invokeMethod<void>('scheduleVibrationRest', {
        RestEffectsChannel.sessionId: sessionId,
        RestEffectsChannel.restId: restId,
        RestEffectsChannel.dueAtUtcMillis:
            dueAtUtc.toUtc().millisecondsSinceEpoch,
      });

  @override
  Future<void> cancelRest(String restId) => _channel.invokeMethod<void>(
        'cancelVibrationRest',
        {RestEffectsChannel.restId: restId},
      );
}
