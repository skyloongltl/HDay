import 'package:fitness_counter/features/workout/domain/active_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 9, 15, 10);

  test('read adds only the currently running segment', () {
    final timer = ActiveTimer(
      accumulatedActiveSeconds: 12,
      runningSegmentStartedAt: start,
    );

    expect(timer.read(start.add(const Duration(seconds: 8))).seconds, 20);
    expect(
      timer
          .pause(start.add(const Duration(seconds: 8)))
          .accumulatedActiveSeconds,
      20,
    );
  });

  test('paused timer excludes later wall-clock time', () {
    final paused = ActiveTimer(
      runningSegmentStartedAt: start,
    ).pause(start.add(const Duration(seconds: 30)));

    expect(paused.read(start.add(const Duration(hours: 6))).seconds, 30);
    expect(paused.runningSegmentStartedAt, isNull);
  });

  test('clock rollback is reported without corrupting accumulated time', () {
    final timer = ActiveTimer(
      accumulatedActiveSeconds: 17,
      runningSegmentStartedAt: start,
    );

    final reading = timer.read(start.subtract(const Duration(seconds: 1)));

    expect(reading.isAnomaly, isTrue);
    expect(reading.reason, TimerAnomalyReason.clockRollback);
    expect(reading.seconds, 17);
  });

  test('a segment of exactly 24 hours is valid', () {
    final timer = ActiveTimer(runningSegmentStartedAt: start);

    final reading = timer.read(start.add(const Duration(hours: 24)));

    expect(reading.isAnomaly, isFalse);
    expect(reading.seconds, 86400);
  });

  test('a segment longer than 24 hours is reported as an anomaly', () {
    final timer = ActiveTimer(
      accumulatedActiveSeconds: 23,
      runningSegmentStartedAt: start,
    );

    final reading = timer.read(start.add(const Duration(hours: 25)));

    expect(reading.isAnomaly, isTrue);
    expect(reading.reason, TimerAnomalyReason.segmentTooLong);
    expect(reading.seconds, 23);
  });
}
