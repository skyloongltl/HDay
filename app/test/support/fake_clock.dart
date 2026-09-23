import 'package:fitness_counter/core/domain/clock.dart';
import 'package:fitness_counter/core/domain/local_date.dart';

final class FakeClock implements Clock {
  FakeClock(DateTime now) : _nowUtc = now.toUtc();

  DateTime _nowUtc;
  Duration _monotonicElapsed = Duration.zero;

  @override
  DateTime nowUtc() => _nowUtc;

  @override
  Duration get monotonicElapsed => _monotonicElapsed;

  @override
  LocalDate today() => LocalDate.fromDateTime(_nowUtc.toLocal());

  void advance(Duration duration) {
    _nowUtc = _nowUtc.add(duration);
    _monotonicElapsed += duration;
  }

  void setUtc(DateTime value) {
    _nowUtc = value.toUtc();
  }
}
