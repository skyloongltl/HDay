import '../domain/local_date.dart';

int? utcValue(DateTime? value) => value?.microsecondsSinceEpoch;

DateTime? readUtc(Object? value) => value == null
    ? null
    : DateTime.fromMicrosecondsSinceEpoch(value as int, isUtc: true);

LocalDate readDate(Object? value) {
  final parts = (value as String).split('-').map(int.parse).toList();
  return LocalDate(parts[0], parts[1], parts[2]);
}
