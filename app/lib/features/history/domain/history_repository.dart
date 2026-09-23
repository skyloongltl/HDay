import '../../../core/domain/local_date.dart';
import '../../workout/domain/workout_session.dart';
import 'history_models.dart';

abstract interface class HistoryRepository {
  Future<List<CalendarDaySummary>> month(LocalDate monthStart);
  Future<List<WorkoutSession>> day(LocalDate date);
  Future<List<WorkoutSession>> recent({int limit = 20});

  /// weekStart uses DateTime's weekday codes (Monday=1, Sunday=7).
  Future<FitnessDayStats> stats(LocalDate today, {required int weekStart});
  Future<List<ExerciseRecord>> exerciseRecords(String exerciseId);
  Future<void> correctSet(
    String sessionId,
    String setId, {
    required double? weight,
    required int reps,
  });
  Future<void> updateNote(String sessionId, String note);
  Future<void> deleteSession(String id);
}
