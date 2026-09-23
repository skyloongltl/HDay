enum TimerAnomalyReason { clockRollback, segmentTooLong }

final class TimerReading {
  const TimerReading({
    required this.seconds,
    required this.isAnomaly,
    this.reason,
  });

  final int seconds;
  final bool isAnomaly;
  final TimerAnomalyReason? reason;
}

final class ActiveTimer {
  ActiveTimer({
    this.accumulatedActiveSeconds = 0,
    this.runningSegmentStartedAt,
  }) {
    if (accumulatedActiveSeconds < 0) {
      throw ArgumentError.value(
        accumulatedActiveSeconds,
        'accumulatedActiveSeconds',
        'Must not be negative.',
      );
    }
    _requireUtc(runningSegmentStartedAt, 'runningSegmentStartedAt');
  }

  static const maxSegmentDuration = Duration(hours: 24);

  final int accumulatedActiveSeconds;
  final DateTime? runningSegmentStartedAt;

  TimerReading read(DateTime nowUtc) {
    _requireUtc(nowUtc, 'nowUtc');
    final startedAt = runningSegmentStartedAt;
    if (startedAt == null) {
      return TimerReading(
        seconds: accumulatedActiveSeconds,
        isAnomaly: false,
      );
    }
    final elapsed = nowUtc.difference(startedAt);
    if (elapsed.isNegative) {
      return TimerReading(
        seconds: accumulatedActiveSeconds,
        isAnomaly: true,
        reason: TimerAnomalyReason.clockRollback,
      );
    }
    if (elapsed > maxSegmentDuration) {
      return TimerReading(
        seconds: accumulatedActiveSeconds,
        isAnomaly: true,
        reason: TimerAnomalyReason.segmentTooLong,
      );
    }
    return TimerReading(
      seconds: accumulatedActiveSeconds + elapsed.inSeconds,
      isAnomaly: false,
    );
  }

  ActiveTimer pause(DateTime nowUtc) {
    final reading = read(nowUtc);
    if (reading.isAnomaly) {
      throw StateError('Cannot pause an anomalous timer segment.');
    }
    return ActiveTimer(accumulatedActiveSeconds: reading.seconds);
  }

  ActiveTimer resume(DateTime nowUtc) {
    _requireUtc(nowUtc, 'nowUtc');
    if (runningSegmentStartedAt != null) {
      return this;
    }
    return ActiveTimer(
      accumulatedActiveSeconds: accumulatedActiveSeconds,
      runningSegmentStartedAt: nowUtc,
    );
  }

  ActiveTimer discardRunningSegment() => ActiveTimer(
        accumulatedActiveSeconds: accumulatedActiveSeconds,
      );
}

void _requireUtc(DateTime? value, String name) {
  if (value != null && !value.isUtc) {
    throw ArgumentError.value(value, name, 'Must use UTC.');
  }
}
