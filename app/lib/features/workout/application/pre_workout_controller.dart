import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/local_date.dart';
import '../../exercises/domain/exercise.dart';
import '../../today/domain/today_overview.dart';
import '../../today/domain/today_repository.dart';
import '../domain/workout_draft.dart';

/// Edits an independent preparation snapshot. It intentionally owns no
/// WorkoutRepository because Task 8 is the first point that creates a session.
final class PreWorkoutController extends StateNotifier<WorkoutDraft?> {
  PreWorkoutController({required TodayRepository todayRepository})
      : _todayRepository = todayRepository,
        super(null);

  final TodayRepository _todayRepository;

  WorkoutDraft get draft =>
      state ?? (throw StateError('Prepare a draft first.'));

  Future<void> prepare({
    required LocalDate date,
    required bool freeWorkout,
  }) async {
    if (freeWorkout) {
      state = WorkoutDraft(workoutDate: date, exercises: const []);
      return;
    }
    final overview = await _todayRepository.load(date);
    state = WorkoutDraft(
      workoutDate: date,
      exercises: _fromOverview(overview),
    );
  }

  void addExercise(Exercise exercise) {
    final current = draft;
    final id = _nextId(exercise.id, current.exercises.map((item) => item.id));
    final setId = _nextId(
      '$id-set-1',
      current.exercises.expand((item) => item.sets).map((set) => set.id),
    );
    _replace(
      current.exercises.followedBy([
        WorkoutExercise(
          id: id,
          exerciseId: exercise.id,
          nameSnapshot: exercise.name,
          categorySnapshot: exercise.category,
          equipmentSnapshot: exercise.equipment,
          unitSnapshot: exercise.defaultUnit,
          note: exercise.note,
          targetRestSeconds: 90,
          order: current.exercises.length,
          temporary: true,
          sets: [
            WorkoutSet(
              id: setId,
              order: 0,
              plannedWeight: 0,
              plannedReps: 10,
              unit: exercise.defaultUnit,
              temporary: true,
            ),
          ],
        ),
      ]).toList(),
    );
  }

  void removeExercise(String exerciseId) {
    _replace(
      draft.exercises.where((exercise) => exercise.id != exerciseId).toList(),
    );
  }

  void reorderExercises(List<String> exerciseIds) {
    final current = draft;
    _requireSameIds(exerciseIds, current.exercises.map((item) => item.id));
    final byId = {
      for (final exercise in current.exercises) exercise.id: exercise,
    };
    _replace([
      for (var index = 0; index < exerciseIds.length; index++)
        _copyExercise(byId[exerciseIds[index]]!, order: index),
    ]);
  }

  void addSet(String exerciseId) {
    final current = draft;
    final exercise = _exercise(exerciseId);
    final last = exercise.sets.last;
    final id = _nextId(
      '$exerciseId-set-${exercise.sets.length + 1}',
      current.exercises.expand((item) => item.sets).map((set) => set.id),
    );
    _replace(
      current.exercises.map((item) {
        if (item.id != exerciseId) return item;
        return _copyExercise(
          item,
          sets: [
            ...item.sets,
            WorkoutSet(
              id: id,
              order: item.sets.length,
              plannedWeight: last.plannedWeight,
              plannedReps: last.plannedReps,
              unit: last.unit,
              temporary: true,
            ),
          ],
        );
      }).toList(),
    );
  }

  void deleteSet(String setId) {
    final current = draft;
    _replace(
      current.exercises.map((exercise) {
        if (!exercise.sets.any((set) => set.id == setId) ||
            exercise.sets.length == 1) {
          return exercise;
        }
        return _copyExercise(
          exercise,
          sets: [
            for (final entry
                in exercise.sets.where((set) => set.id != setId).indexed)
              entry.$2.copyWith(order: entry.$1),
          ],
        );
      }).toList(),
    );
  }

  void updateSet(String setId, {double? weight, int? reps}) {
    if (weight == null && reps == null) return;
    if (weight != null && (!weight.isFinite || weight < 0)) return;
    if (reps != null && reps < 1) return;
    _replace(
      draft.exercises
          .map(
            (exercise) => _copyExercise(
              exercise,
              sets: exercise.sets
                  .map(
                    (set) => set.id == setId
                        ? set.copyWith(plannedWeight: weight, plannedReps: reps)
                        : set,
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  void reorderSets(String exerciseId, List<String> setIds) {
    final exercise = _exercise(exerciseId);
    _requireSameIds(setIds, exercise.sets.map((item) => item.id));
    final byId = {for (final set in exercise.sets) set.id: set};
    _replace(
      draft.exercises.map((item) {
        if (item.id != exerciseId) return item;
        return _copyExercise(
          item,
          sets: [
            for (var index = 0; index < setIds.length; index++)
              byId[setIds[index]]!.copyWith(order: index),
          ],
        );
      }).toList(),
    );
  }

  WorkoutDraft takeDraft() => WorkoutDraft(
        workoutDate: draft.workoutDate,
        exercises: [
          for (final exercise in draft.exercises) _copyExercise(exercise),
        ],
      );

  List<WorkoutExercise> _fromOverview(TodayOverview overview) {
    final seenExerciseIds = <String>{};
    final seenSetIds = <String>{};
    return [
      for (var index = 0; index < overview.mergedExercises.length; index++)
        if (overview.mergedExercises[index].exercise.sets.isNotEmpty)
          () {
            final scheduled = overview.mergedExercises[index];
            final source = scheduled.source;
            final sourceExercise = scheduled.exercise;
            final exerciseId = _nextId(sourceExercise.id, seenExerciseIds);
            seenExerciseIds.add(exerciseId);
            return WorkoutExercise(
              id: exerciseId,
              exerciseId: sourceExercise.exerciseId,
              nameSnapshot: sourceExercise.nameSnapshot,
              categorySnapshot: scheduled.category,
              equipmentSnapshot: scheduled.equipment,
              unitSnapshot: sourceExercise.sets.first.unit,
              sourcePlanId: source.plan.id,
              sourcePlanName: source.plan.name,
              sourceRevisionId: source.revision.id,
              sourceDayNumber: source.day.dayNumber,
              sourceDayName: source.day.name,
              note: sourceExercise.note,
              targetRestSeconds: sourceExercise.targetRestSeconds,
              order: index,
              temporary: false,
              sets: [
                for (var setIndex = 0;
                    setIndex < sourceExercise.sets.length;
                    setIndex++)
                  () {
                    final sourceSet = sourceExercise.sets[setIndex];
                    final setId = _nextId(sourceSet.id, seenSetIds);
                    seenSetIds.add(setId);
                    return WorkoutSet(
                      id: setId,
                      order: setIndex,
                      plannedWeight: sourceSet.plannedWeight,
                      plannedReps: sourceSet.plannedReps,
                      unit: sourceSet.unit,
                      temporary: false,
                    );
                  }(),
              ],
            );
          }(),
    ];
  }

  WorkoutExercise _exercise(String id) => draft.exercises.firstWhere(
        (exercise) => exercise.id == id,
        orElse: () => throw StateError('Workout exercise not found.'),
      );

  void _replace(List<WorkoutExercise> exercises) {
    state = WorkoutDraft(
      workoutDate: draft.workoutDate,
      exercises: [
        for (var index = 0; index < exercises.length; index++)
          _copyExercise(exercises[index], order: index),
      ],
    );
  }

  WorkoutExercise _copyExercise(
    WorkoutExercise exercise, {
    int? order,
    List<WorkoutSet>? sets,
  }) =>
      WorkoutExercise(
        id: exercise.id,
        exerciseId: exercise.exerciseId,
        nameSnapshot: exercise.nameSnapshot,
        categorySnapshot: exercise.categorySnapshot,
        equipmentSnapshot: exercise.equipmentSnapshot,
        unitSnapshot: exercise.unitSnapshot,
        sourcePlanId: exercise.sourcePlanId,
        sourcePlanName: exercise.sourcePlanName,
        sourceRevisionId: exercise.sourceRevisionId,
        sourceDayNumber: exercise.sourceDayNumber,
        sourceDayName: exercise.sourceDayName,
        note: exercise.note,
        targetRestSeconds: exercise.targetRestSeconds,
        order: order ?? exercise.order,
        temporary: exercise.temporary,
        sets: [
          for (final set in sets ?? exercise.sets)
            WorkoutSet(
              id: set.id,
              order: set.order,
              plannedWeight: set.plannedWeight,
              plannedReps: set.plannedReps,
              unit: set.unit,
              actualWeight: set.actualWeight,
              actualReps: set.actualReps,
              status: set.status,
              startedAt: set.startedAt,
              completedAt: set.completedAt,
              skippedAt: set.skippedAt,
              setDurationSeconds: set.setDurationSeconds,
              preSetRestSeconds: set.preSetRestSeconds,
              temporary: set.temporary,
            ),
        ],
      );

  static String _nextId(String base, Iterable<String> existing) {
    final ids = existing.toSet();
    if (!ids.contains(base)) return base;
    var suffix = 2;
    while (ids.contains('$base-$suffix')) {
      suffix += 1;
    }
    return '$base-$suffix';
  }

  static void _requireSameIds(Iterable<String> next, Iterable<String> current) {
    final requested = next.toList();
    final existing = current.toList();
    if (requested.length != existing.length ||
        requested.toSet().length != requested.length ||
        !requested.toSet().containsAll(existing)) {
      throw StateError('Reorder ids must contain every item once.');
    }
  }
}
