import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/domain/local_date.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../exercises/presentation/exercise_picker_sheet.dart';
import '../../today/application/today_providers.dart';
import '../application/pre_workout_controller.dart';
import '../application/pre_workout_providers.dart';
import '../application/workout_providers.dart';
import '../domain/workout_draft.dart';
import 'workout_draft_card.dart';

// PAGE: PreWorkoutScreen
// ROUTE: /pre-workout?free=true|false&date=YYYY-MM-DD
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, BottomAppBar
// STATE: draft(WorkoutDraft?), isPreparing(bool), isStarting(bool), startError(Object?)
// ANIMATIONS: picker sheet (280ms, easeOut)
// NAVIGATION: back -> Home; start -> Task 8 workout start action
final class PreWorkoutScreen extends ConsumerStatefulWidget {
  const PreWorkoutScreen({
    required this.date,
    required this.freeWorkout,
    super.key,
  });
  final LocalDate date;
  final bool freeWorkout;
  @override
  ConsumerState<PreWorkoutScreen> createState() => _PreWorkoutScreenState();
}

final class _PreWorkoutScreenState extends ConsumerState<PreWorkoutScreen> {
  bool isPreparing = true; // Flutter: setState / ValueNotifier
  Object? preparationError; // Flutter: setState / ValueNotifier
  bool isStarting = false; // Flutter: setState / ValueNotifier
  Object? startError; // Flutter: setState / ValueNotifier
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  Future<void> _prepare() async {
    setState(() {
      isPreparing = true;
      preparationError = null;
    });
    try {
      await ref.read(todayRepositoryProvider.future);
      await ref
          .read(
            preWorkoutControllerProvider(
              (date: widget.date.iso8601, freeWorkout: widget.freeWorkout),
            ).notifier,
          )
          .prepare(date: widget.date, freeWorkout: widget.freeWorkout);
    } on Object catch (error) {
      preparationError = error;
    } finally {
      if (mounted) setState(() => isPreparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final request =
        (date: widget.date.iso8601, freeWorkout: widget.freeWorkout);
    final draft = ref.watch(preWorkoutControllerProvider(request));
    final controller = ref.read(preWorkoutControllerProvider(request).notifier);
    return Scaffold(
      key: const ValueKey('pre-workout-screen'),
      appBar: AppBar(
        centerTitle: true,
        leading: CircularBackButton(
          key: const ValueKey('pre-workout-back'),
          onPressed: () => context.go(AppRoutes.home),
        ),
        actions: [SizedBox(width: theme.minTapTarget)],
        title: Text(
          widget.freeWorkout
              ? AppStrings.freeWorkout
              : AppStrings.trainingPreparation,
        ),
      ),
      body: isPreparing
          ? const Center(child: CircularProgressIndicator())
          : preparationError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(AppStrings.preparationLoadFailed),
                      SizedBox(height: theme.spacing.s12),
                      ElevatedButton(
                        onPressed: _prepare,
                        child: const Text(AppStrings.retry),
                      ),
                    ],
                  ),
                )
              : draft == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.all(theme.spacing.s16),
                            children: [
                              Text(
                                widget.freeWorkout
                                    ? AppStrings.freeWorkoutHint
                                    : AppStrings.preparationHint,
                              ),
                              SizedBox(height: theme.spacing.s12),
                              if (draft.exercises.isEmpty)
                                Center(
                                  child: Column(
                                    children: [
                                      Text(AppStrings.noPreparedExercises),
                                      Text(AppStrings.noPreparedExercisesHint),
                                    ],
                                  ),
                                ),
                              for (var exerciseIndex = 0;
                                  exerciseIndex < draft.exercises.length;
                                  exerciseIndex++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    bottom: theme.spacing.s8,
                                  ),
                                  child: WorkoutDraftCard(
                                    exercise: draft.exercises[exerciseIndex],
                                    canMoveExerciseUp: exerciseIndex > 0,
                                    canMoveExerciseDown: exerciseIndex <
                                        draft.exercises.length - 1,
                                    onMoveExerciseUp: () => _moveExercise(
                                      controller,
                                      draft,
                                      exerciseIndex,
                                      -1,
                                    ),
                                    onMoveExerciseDown: () => _moveExercise(
                                      controller,
                                      draft,
                                      exerciseIndex,
                                      1,
                                    ),
                                    onRemove: () => controller.removeExercise(
                                      draft.exercises[exerciseIndex].id,
                                    ),
                                    onAddSet: () => controller.addSet(
                                      draft.exercises[exerciseIndex].id,
                                    ),
                                    onDeleteSet: controller.deleteSet,
                                    onUpdateSet: (id, weight, reps) =>
                                        controller.updateSet(
                                      id,
                                      weight: weight,
                                      reps: reps,
                                    ),
                                    onMoveSetUp: (id) => _moveSet(
                                      controller,
                                      draft.exercises[exerciseIndex],
                                      id,
                                      -1,
                                    ),
                                    onMoveSetDown: (id) => _moveSet(
                                      controller,
                                      draft.exercises[exerciseIndex],
                                      id,
                                      1,
                                    ),
                                  ),
                                ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize:
                                      Size.fromHeight(theme.spacing.s48),
                                ),
                                onPressed: () => ExercisePickerSheet.show(
                                  context,
                                  excludeIds: draft.exercises
                                      .map((item) => item.exerciseId)
                                      .toSet(),
                                  onSelected: controller.addExercise,
                                ),
                                icon: const Icon(Icons.add),
                                label: Text(
                                  widget.freeWorkout
                                      ? AppStrings.addExercise
                                      : AppStrings.addTemporaryExercise,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.all(theme.spacing.s16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (startError != null) ...[
                                  const Text(AppStrings.workoutStartFailed),
                                  SizedBox(height: theme.spacing.s8),
                                ],
                                FilledButton(
                                  key: const ValueKey('start-workout'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: Size.fromHeight(
                                      theme.dimensions.primaryButtonHeight,
                                    ),
                                  ),
                                  onPressed:
                                      draft.exercises.isEmpty || isStarting
                                          ? null
                                          : startError == null
                                              ? () => _start(controller)
                                              : _retryStart,
                                  child: Text(
                                    isStarting
                                        ? AppStrings.startingWorkout
                                        : startError == null
                                            ? AppStrings.startTimer
                                            : AppStrings.retryWorkoutStart,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Future<void> _start(PreWorkoutController controller) async {
    if (isStarting) return;
    final snapshot = controller.takeDraft();
    setState(() {
      isStarting = true;
      startError = null;
    });
    try {
      final workout = ref.read(workoutControllerProvider.notifier);
      final sessionId = await workout.start(snapshot);
      if (mounted) context.go(AppRoutes.workout(sessionId));
    } on Object catch (error) {
      if (mounted) setState(() => startError = error);
    } finally {
      if (mounted) setState(() => isStarting = false);
    }
  }

  Future<void> _retryStart() async {
    if (isStarting) return;
    setState(() => isStarting = true);
    try {
      final workout = ref.read(workoutControllerProvider.notifier);
      await workout.retry();
      final sessionId = ref.read(workoutControllerProvider).session?.id;
      if (sessionId == null) {
        throw StateError('Workout retry completed without an active session.');
      }
      if (mounted) context.go(AppRoutes.workout(sessionId));
    } on Object catch (error) {
      if (mounted) setState(() => startError = error);
    } finally {
      if (mounted) setState(() => isStarting = false);
    }
  }

  void _moveExercise(
    PreWorkoutController controller,
    WorkoutDraft draft,
    int index,
    int delta,
  ) {
    final ids = draft.exercises.map((item) => item.id).toList();
    final item = ids.removeAt(index);
    ids.insert(index + delta, item);
    controller.reorderExercises(ids);
  }

  void _moveSet(
    PreWorkoutController controller,
    WorkoutExercise exercise,
    String id,
    int delta,
  ) {
    final ids = exercise.sets.map((item) => item.id).toList();
    final index = ids.indexOf(id);
    final item = ids.removeAt(index);
    ids.insert(index + delta, item);
    controller.reorderSets(exercise.id, ids);
  }
}
