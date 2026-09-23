import '../../../core/data/app_database.dart';
import '../../../core/domain/local_date.dart';
import '../../exercises/domain/exercise.dart';
import '../../history/data/sqlite_history_repository.dart';
import '../../plans/data/sqlite_plan_schedule.dart';
import '../../settings/data/sqlite_settings_repository.dart';
import '../../settings/domain/app_settings.dart';
import '../../workout/data/workout_mapper.dart';
import '../../workout/domain/workout_draft.dart';
import '../../workout/domain/workout_session.dart';
import '../domain/today_overview.dart';
import '../domain/today_repository.dart';

final class SqliteTodayRepository implements TodayRepository {
  const SqliteTodayRepository(this._db);
  final AppDatabase _db;

  @override
  Future<TodayOverview> load(LocalDate date) => _db.transaction((tx) async {
        final scheduled = (await SqlitePlanSchedule.read(tx)).on(date);
        final exerciseIds = scheduled
            .expand((day) => day.day.exercises)
            .map((exercise) => exercise.exerciseId)
            .toSet();
        final catalogRows = exerciseIds.isEmpty
            ? const <Map<String, Object?>>[]
            : await tx.query(
                'exercises',
                columns: ['id', 'category', 'equipment'],
                where:
                    'id IN (${List.filled(exerciseIds.length, '?').join(',')})',
                whereArgs: exerciseIds.toList(),
              );
        final catalogById = {
          for (final row in catalogRows) row['id'] as String: row,
        };
        final merged = [
          for (final day in scheduled)
            if (!day.day.isRest)
              for (final exercise in day.day.exercises)
                ScheduledExercise(
                  source: day,
                  exercise: exercise,
                  category: catalogById[exercise.exerciseId] == null
                      ? ExerciseCategory.fullBody
                      : ExerciseCategory.fromCode(
                          catalogById[exercise.exerciseId]!['category']
                              as String,
                        ),
                  equipment: catalogById[exercise.exerciseId] == null
                      ? ExerciseEquipment.bodyweight
                      : ExerciseEquipment.fromCode(
                          catalogById[exercise.exerciseId]!['equipment']
                              as String,
                        ),
                ),
        ];
        final sessions = await SqliteHistoryRepository.readDay(tx, date);
        final unfinished = await tx.query(
          'workout_sessions',
          where: "phase != 'saved'",
          limit: 1,
        );
        final settings = await SqliteSettingsRepository.readFrom(tx);
        return TodayOverview(
          scheduledDays: scheduled,
          mergedExercises: merged,
          isAllRest:
              scheduled.isNotEmpty && scheduled.every((day) => day.day.isRest),
          savedCompletedSets: sessions
              .where((session) => session.phase == WorkoutPhase.saved)
              .expand((session) => session.exercises)
              .expand((exercise) => exercise.sets)
              .where((set) => set.status == SetStatus.completed)
              .length,
          totalPlannedSets: merged.fold(
            0,
            (total, item) => total + item.exercise.sets.length,
          ),
          unfinishedSession: unfinished.isEmpty
              ? null
              : await WorkoutMapper.read(tx, unfinished.single),
          fitnessDayStats: await SqliteHistoryRepository.readStats(
            tx,
            date,
            weekStart: settings.weekStart == WeekStart.monday
                ? DateTime.monday
                : DateTime.sunday,
          ),
        );
      });
}
