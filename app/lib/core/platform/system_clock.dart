import '../domain/clock.dart';
import '../domain/local_date.dart';

final class SystemClock implements Clock {
  SystemClock() : _stopwatch = Stopwatch()..start();
  final Stopwatch _stopwatch;
  @override
  DateTime nowUtc() => DateTime.now().toUtc();
  @override
  Duration get monotonicElapsed => _stopwatch.elapsed;
  @override
  LocalDate today() => LocalDate.fromDateTime(DateTime.now());
}
