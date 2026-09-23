final class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.year, this.month, this.day) {
    final normalized = DateTime.utc(year, month, day);
    if (normalized.year != year ||
        normalized.month != month ||
        normalized.day != day) {
      throw ArgumentError.value(iso8601, 'date', 'Must be a calendar date.');
    }
  }

  factory LocalDate.fromDateTime(DateTime value) =>
      LocalDate(value.year, value.month, value.day);

  final int year;
  final int month;
  final int day;

  String get iso8601 => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  LocalDate addDays(int days) {
    final result = DateTime.utc(year, month, day).add(Duration(days: days));
    return LocalDate(result.year, result.month, result.day);
  }

  @override
  int compareTo(LocalDate other) => _scalar.compareTo(other._scalar);

  int get _scalar => year * 10000 + month * 100 + day;

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso8601;
}

int calendarDayDifference(LocalDate from, LocalDate to) => DateTime.utc(
      to.year,
      to.month,
      to.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
