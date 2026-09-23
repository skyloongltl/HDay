final class NotificationPermissionState {
  const NotificationPermissionState({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
  });

  final bool notificationsGranted;
  final bool exactAlarmsGranted;

  @override
  bool operator ==(Object other) =>
      other is NotificationPermissionState &&
      other.notificationsGranted == notificationsGranted &&
      other.exactAlarmsGranted == exactAlarmsGranted;

  @override
  int get hashCode => Object.hash(notificationsGranted, exactAlarmsGranted);
}

abstract interface class NotificationGateway {
  Future<NotificationPermissionState> permissionState();
  Future<void> requestNotificationPermission();
  Future<void> requestExactAlarmPermission();
  Future<void> scheduleRest({
    required String sessionId,
    required String restId,
    required DateTime dueAtUtc,
  });
  Future<void> cancelRest(String restId);
}
