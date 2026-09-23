import '../../../core/domain/local_date.dart';
import '../../exercises/domain/exercise.dart';

final class CalendarDaySummary {
  const CalendarDaySummary({
    required this.date,
    required this.hasSavedWorkout,
    required this.hasUnfinishedWorkout,
    required this.hasPlan,
    required this.isAllRest,
  });
  final LocalDate date;
  final bool hasSavedWorkout;
  final bool hasUnfinishedWorkout;
  final bool hasPlan;
  final bool isAllRest;
}

final class FitnessDayStats {
  const FitnessDayStats({
    required this.total,
    required this.week,
    required this.month,
    required this.lastWorkoutAt,
  });
  final int total;
  final int week;
  final int month;
  final DateTime? lastWorkoutAt;
}

final class ExerciseRecord {
  const ExerciseRecord({
    required this.sessionId,
    required this.setId,
    required this.exerciseId,
    required this.date,
    required this.completedAt,
    required this.unit,
    required this.weight,
    required this.reps,
  });
  final String sessionId;
  final String setId;
  final String exerciseId;
  final LocalDate date;
  final DateTime completedAt;
  final WeightUnit unit;
  final double? weight;
  final int reps;
}

/// Records have already been restricted to completed sets in saved sessions by
/// the repository. Units remain independent; null weight is not a zero-weight PB.
final class ExerciseHistorySummary {
  ExerciseHistorySummary._(this.records, this.bestByUnit);

  factory ExerciseHistorySummary.fromRecords(List<ExerciseRecord> records) {
    final ordered = [...records]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final best = <WeightUnit, ExerciseRecord>{};
    for (final record in ordered) {
      final weighted =
          record.unit == WeightUnit.kg || record.unit == WeightUnit.lb;
      if (weighted && record.weight == null) continue;
      final previous = best[record.unit];
      if (previous == null || _compare(record, previous, weighted) > 0) {
        best[record.unit] = record;
      }
    }
    return ExerciseHistorySummary._(
      List.unmodifiable(ordered),
      Map.unmodifiable(best),
    );
  }

  final List<ExerciseRecord> records;
  final Map<WeightUnit, ExerciseRecord> bestByUnit;
  List<ExerciseRecord> trend(WeightUnit unit, {int limit = 8}) {
    final weighted = unit == WeightUnit.kg || unit == WeightUnit.lb;
    final daily = <LocalDate, ExerciseRecord>{};
    for (final record in records.where((record) => record.unit == unit)) {
      final current = daily[record.date];
      if (current == null || _compare(record, current, weighted) > 0) {
        daily[record.date] = record;
      }
    }
    final chronological = daily.values.take(limit).toList().reversed;
    return List.unmodifiable(chronological);
  }
  static int _compare(ExerciseRecord a, ExerciseRecord b, bool weighted) {
    if (weighted) {
      final comparison = a.weight!.compareTo(b.weight!);
      if (comparison != 0) return comparison;
    }
    final reps = a.reps.compareTo(b.reps);
    return reps != 0 ? reps : a.completedAt.compareTo(b.completedAt);
  }
}
