import 'package:flutter/services.dart';

abstract final class RestEffectsChannel {
  static const name = 'fitness_counter/rest_effects';
  static const sessionId = 'sessionId';
  static const restId = 'restId';
  static const dueAtUtcMillis = 'dueAtUtcMillis';
  static const enabled = 'enabled';
  static const notificationsGranted = 'notificationsGranted';
  static const exactAlarmsGranted = 'exactAlarmsGranted';
  static const MethodChannel methodChannel = MethodChannel(name);
}
