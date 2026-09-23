import 'package:flutter/services.dart';

import 'rest_effects_channel.dart';
import 'wake_lock_gateway.dart';

final class AndroidWakeLockGateway implements WakeLockGateway {
  AndroidWakeLockGateway({MethodChannel? channel})
      : _channel = channel ?? RestEffectsChannel.methodChannel;

  final MethodChannel _channel;

  @override
  Future<void> setEnabled(bool enabled) => _channel.invokeMethod<void>(
        'setWakeLockEnabled',
        {RestEffectsChannel.enabled: enabled},
      );
}
