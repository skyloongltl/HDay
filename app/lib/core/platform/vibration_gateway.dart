abstract interface class VibrationGateway {
  Future<bool> hasVibrator();
  Future<void> pulse();
  Future<void> scheduleRest({
    required String sessionId,
    required String restId,
    required DateTime dueAtUtc,
  });
  Future<void> cancelRest(String restId);
}
