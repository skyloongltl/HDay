import '../../exercises/domain/exercise.dart';
import '../../history/domain/history_models.dart';
import '../../plans/domain/plan_day.dart';
import '../../plans/domain/plan_schedule.dart';
import '../../workout/domain/workout_session.dart';

/// A scheduled template plus its complete source. IDs are still plan IDs;
/// preparation creates new workout IDs when generating its independent draft.
final class ScheduledExercise {
  const ScheduledExercise({
    required this.source,
    required this.exercise,
    required this.category,
    required this.equipment,
  });
  final ScheduledPlanDay source;
  final PlanExercise exercise;
  final ExerciseCategory category;
  final ExerciseEquipment equipment;
}

final class TodayOverview {
  TodayOverview({
    required List<ScheduledPlanDay> scheduledDays,
    required List<ScheduledExercise> mergedExercises,
    required this.isAllRest,
    required this.savedCompletedSets,
    required this.totalPlannedSets,
    required this.unfinishedSession,
    required this.fitnessDayStats,
  })  : scheduledDays = List.unmodifiable(scheduledDays),
        mergedExercises = List.unmodifiable(mergedExercises);
  final List<ScheduledPlanDay> scheduledDays;
  final List<ScheduledExercise> mergedExercises;
  final bool isAllRest;
  final int savedCompletedSets;
  final int totalPlannedSets;
  final WorkoutSession? unfinishedSession;
  final FitnessDayStats fitnessDayStats;
}
