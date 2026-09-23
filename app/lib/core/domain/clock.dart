import 'local_date.dart';

abstract interface class Clock {
  DateTime nowUtc();

  Duration get monotonicElapsed;

  LocalDate today();
}
