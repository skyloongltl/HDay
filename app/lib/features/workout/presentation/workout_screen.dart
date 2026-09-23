import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/workout_skin.dart';
import '../../../widgets/progress_bar.dart';
import '../../../widgets/set_row.dart';
import '../../../widgets/workout_end_button.dart';
import '../application/workout_controller.dart';
import '../application/workout_providers.dart';
import '../domain/workout_draft.dart';
import '../domain/workout_event.dart';
import '../domain/workout_session.dart';
import 'early_end_sheet.dart';
import 'in_workout_adjustment_sheet.dart';

// PAGE: WorkoutScreen
// ROUTE: /workout/:sessionId
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, Card, BottomSheet
// STATE: isEndSheetOpen(bool), isRestoreChecked(bool)
// ANIMATIONS: progress 300ms easeOut; set status 200ms easeOut; press 100ms easeOut
// NAVIGATION: complete non-final set -> /rest/:sessionId; back -> /home
final class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

final class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  late final WorkoutController _workoutController;
  late final String _visibilityOwner;
  bool isEndSheetOpen = false; // Flutter: setState
  Timer? _ticker;
  bool isRestoreChecked = false; // Flutter: setState

  @override
  void initState() {
    super.initState();
    _workoutController = ref.read(workoutControllerProvider.notifier);
    _visibilityOwner = 'workout-${identityHashCode(this)}';
    _workoutController.setWorkoutScreenVisible(_visibilityOwner, true);
    _ticker = Timer.periodic(WorkoutSkin.timerTick, (_) {
      if (mounted) setState(() {});
    });
    Future<void>.microtask(_ensureRestored);
  }

  @override
  void dispose() {
    _workoutController.setWorkoutScreenVisible(_visibilityOwner, false);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutControllerProvider);
    final session = state.session;
    if (session == null && !isRestoreChecked) {
      return const Scaffold(
        key: ValueKey('workout-screen'),
        body: Center(child: Text(AppStrings.restoringWorkout)),
      );
    }
    if (session == null && state.failure != null) {
      return _RestoreFailureScaffold(onRetry: _retryRestore);
    }
    if (session == null || session.id != widget.sessionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.workoutFallback);
      });
      return const Scaffold(
        key: ValueKey('workout-screen'),
        body: Center(child: Text(AppStrings.workoutUnavailable)),
      );
    }
    if (session.phase == WorkoutPhase.timeAnomaly) {
      return _TimeAnomalyScaffold(
        isSaving: state.isSaving,
        hasFailure: state.failure != null,
        onConfirm: _confirmTime,
        onRetry: () => ref.read(workoutControllerProvider.notifier).retry(),
      );
    }
    if (session.phase != WorkoutPhase.active &&
        session.phase != WorkoutPhase.completedPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(AppRoutes.forWorkoutSession(session));
      });
      return const Scaffold(
        key: ValueKey('workout-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = AppTheme.of(context);
    final allSets = session.exercises.expand((exercise) => exercise.sets);
    final completed =
        allSets.where((set) => set.status == SetStatus.completed).length;
    final total = allSets.length;
    final selected = _selectedSet(session);
    final canFinish = session.hasCompletedSet;
    final seconds =
        session.timer.read(ref.read(clockProvider).nowUtc()).seconds;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        key: ValueKey('workout-${session.id}'),
        appBar: AppBar(
          toolbarHeight: theme.minTapTarget + theme.spacing.s24,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.trainingDuration,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                _formatDuration(seconds),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          actions: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.workoutMode,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                WorkoutEndButton(
                  key: const ValueKey('end-workout'),
                  onPressed: state.isSaving || state.failure != null
                      ? null
                      : () => _openEndSheet(session),
                ),
              ],
            ),
            SizedBox(width: theme.spacing.s8),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(theme.spacing.s48),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.s16,
                theme.spacing.s4,
                theme.spacing.s16,
                theme.spacing.s12,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppStrings.workoutProgress(completed, total)),
                      Text(
                        '${total == 0 ? 0 : (completed * 100 / total).round()}%',
                      ),
                    ],
                  ),
                  SizedBox(height: theme.spacing.s8),
                  ProgressBar(progress: total == 0 ? 0 : completed / total),
                ],
              ),
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            theme.spacing.s16,
            theme.spacing.s12,
            theme.spacing.s16,
            theme.spacing.s16,
          ),
          children: [
            for (final exercise in session.exercises)
              _ExerciseCard(
                exercise: exercise,
                selectedSetId: session.activeSetId ?? session.selectedSetId,
                disabled: state.isSaving || state.failure != null,
                onSelect: (set) => _dispatch(SelectSet(set.id)),
              ),
            if (state.failure != null)
              _FailurePanel(
                onRetry: () =>
                    ref.read(workoutControllerProvider.notifier).retry(),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canFinish || session.phase != WorkoutPhase.completedPaused)
                  Row(
                    children: [
                      _AdjustmentButton(
                        key: const ValueKey('adjust-edit'),
                        label: AppStrings.editWorkoutData,
                        onPressed: state.isSaving || state.failure != null
                            ? null
                            : () => _openAdjustment(AdjustmentTab.edit),
                      ),
                      SizedBox(width: theme.spacing.s6),
                      _AdjustmentButton(
                        key: const ValueKey('adjust-skip'),
                        label: AppStrings.skipActions,
                        onPressed: state.isSaving || state.failure != null
                            ? null
                            : () => _openAdjustment(AdjustmentTab.skip),
                      ),
                      SizedBox(width: theme.spacing.s6),
                      _AdjustmentButton(
                        key: const ValueKey('adjust-add'),
                        label: AppStrings.addDeleteActions,
                        onPressed: state.isSaving || state.failure != null
                            ? null
                            : () => _openAdjustment(AdjustmentTab.add),
                      ),
                    ],
                  ),
                if (canFinish || session.phase != WorkoutPhase.completedPaused)
                  SizedBox(height: theme.spacing.s8),
                if (session.phase == WorkoutPhase.completedPaused) ...[
                  if (selected?.status == SetStatus.pending) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('primary-set-action'),
                        onPressed: state.isSaving || state.failure != null
                            ? null
                            : () => _start(selected!),
                        child: const Text(AppStrings.startSelectedSet),
                      ),
                    ),
                    SizedBox(height: theme.spacing.s8),
                  ],
                  if (!canFinish) ...[
                    const Text(
                      AppStrings.emptyWorkoutCompletionHint,
                      key: ValueKey('empty-workout-completion-hint'),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: theme.spacing.s8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('add-training'),
                          onPressed: state.isSaving || state.failure != null
                              ? null
                              : () => _openAdjustment(AdjustmentTab.add),
                          child: const Text(AppStrings.addTraining),
                        ),
                      ),
                      SizedBox(width: theme.spacing.s8),
                      Expanded(
                        child: canFinish
                            ? FilledButton(
                                key: const ValueKey('finish-workout'),
                                onPressed:
                                    state.isSaving || state.failure != null
                                        ? null
                                        : () => _prepareFinish(session),
                                child: const Text(AppStrings.finishWorkout),
                              )
                            : TextButton(
                                key: const ValueKey(
                                  'discard-empty-workout',
                                ),
                                onPressed:
                                    state.isSaving || state.failure != null
                                        ? null
                                        : () => _openEndSheet(session),
                                child: Text(
                                  AppStrings.discardWorkout,
                                  style: TextStyle(color: theme.colors.danger),
                                ),
                              ),
                      ),
                    ],
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('primary-set-action'),
                      onPressed: selected == null ||
                              state.isSaving ||
                              state.failure != null
                          ? null
                          : () => selected.status == SetStatus.inProgress
                              ? _complete(selected)
                              : _start(selected),
                      child: Text(
                        selected?.status == SetStatus.inProgress
                            ? AppStrings.completeCurrentSet
                            : selected == null
                                ? AppStrings.allSetsCompleted
                                : AppStrings.startSelectedSet,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _dispatch(WorkoutEvent event) async {
    try {
      await ref.read(workoutControllerProvider.notifier).dispatch(event);
    } on Object {
      // Controller exposes the committed state, pending command and retry UI.
    }
  }

  Future<void> _ensureRestored() async {
    if (ref.read(workoutControllerProvider).session == null) {
      try {
        await ref.read(workoutControllerProvider.notifier).restore();
      } on Object {
        // The route renders the controller failure and retry action.
      }
    }
    if (mounted) setState(() => isRestoreChecked = true);
  }

  Future<void> _retryRestore() async {
    try {
      await ref.read(workoutControllerProvider.notifier).retry();
    } on Object {
      // Keep the retry state visible.
    }
  }

  Future<void> _start(WorkoutSet set) => _dispatch(StartSet(set.id));

  Future<void> _confirmTime() async {
    await _dispatch(
      ConfirmTime(nowUtc: ref.read(clockProvider).nowUtc()),
    );
    final session = ref.read(workoutControllerProvider).session;
    if (mounted && session != null) {
      context.go(AppRoutes.forWorkoutSession(session));
    }
  }

  Future<void> _openEndSheet(WorkoutSession session) async {
    setState(() => isEndSheetOpen = true);
    await EarlyEndSheet.show(context, session);
    if (mounted) setState(() => isEndSheetOpen = false);
  }

  Future<void> _prepareFinish(WorkoutSession session) async {
    await _dispatch(const PrepareFinish());
    final current = ref.read(workoutControllerProvider).session;
    if (mounted && current?.phase == WorkoutPhase.finishing) {
      context.go(AppRoutes.summary(session.id));
    }
  }

  Future<void> _openAdjustment(AdjustmentTab tab) =>
      InWorkoutAdjustmentSheet.show(context, initialTab: tab);

  Future<void> _complete(WorkoutSet set) async {
    final weight = set.actualWeight ?? set.plannedWeight;
    final reps = set.actualReps ?? set.plannedReps;
    await _dispatch(
      CompleteSet(set.id, actualWeight: weight, actualReps: reps),
    );
    final session = ref.read(workoutControllerProvider).session;
    if (!mounted || session == null) return;
    if (session.phase == WorkoutPhase.resting) {
      context.go(AppRoutes.rest(session.id));
    }
  }
}

final class _TimeAnomalyScaffold extends StatelessWidget {
  const _TimeAnomalyScaffold({
    required this.isSaving,
    required this.hasFailure,
    required this.onConfirm,
    required this.onRetry,
  });
  final bool isSaving;
  final bool hasFailure;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      key: const ValueKey('time-anomaly'),
      appBar: AppBar(title: const Text(AppStrings.timeAnomalyTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: theme.dimensions.emptyIconSize,
                color: theme.colors.primaryAction,
              ),
              SizedBox(height: theme.spacing.s16),
              const Text(
                AppStrings.timeAnomalyHint,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: theme.spacing.s20),
              FilledButton(
                key: const ValueKey('confirm-time'),
                onPressed: isSaving || hasFailure ? null : onConfirm,
                child: const Text(AppStrings.confirmTime),
              ),
              if (hasFailure)
                TextButton(
                  onPressed: isSaving ? null : onRetry,
                  child: const Text(AppStrings.retry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _RestoreFailureScaffold extends StatelessWidget {
  const _RestoreFailureScaffold({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(AppStrings.workoutCommandFailed),
              TextButton(
                onPressed: onRetry,
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
}

final class _AdjustmentButton extends StatelessWidget {
  const _AdjustmentButton({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Expanded(
      child: SizedBox(
        height: theme.minTapTarget,
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colors.iconSurface,
            foregroundColor: theme.colors.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(theme.radii.sm),
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

final class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.selectedSetId,
    required this.disabled,
    required this.onSelect,
  });
  final WorkoutExercise exercise;
  final String? selectedSetId;
  final bool disabled;
  final Future<void> Function(WorkoutSet) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final done =
        exercise.sets.where((set) => set.status == SetStatus.completed).length;
    return Card(
      color: theme.colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: theme.dimensions.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: theme.colors.outline,
          width: theme.borders.thin,
        ),
        borderRadius: BorderRadius.circular(theme.radii.lg),
      ),
      margin: EdgeInsets.only(bottom: theme.spacing.s12),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: theme.spacing.s32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colors.mintSurface,
                      borderRadius: BorderRadius.circular(theme.radii.sm),
                    ),
                    child: Center(
                      child: Text(
                        exercise.nameSnapshot.characters.first,
                        style: TextStyle(
                          color: theme.colors.mintText,
                          fontWeight: theme.typography.heavy,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.nameSnapshot,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        AppStrings.targetRestSummary(
                          exercise.targetRestSeconds,
                        ),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                Text('$done / ${exercise.sets.length} ${AppStrings.setNumber}'),
              ],
            ),
            SizedBox(height: theme.spacing.s8),
            Divider(height: theme.borders.thin, color: theme.colors.outline),
            SizedBox(height: theme.spacing.s8),
            for (var index = 0; index < exercise.sets.length; index++) ...[
              SetRow(
                key: ValueKey('set-row-${exercise.sets[index].id}'),
                index: index + 1,
                set: exercise.sets[index],
                selected: exercise.sets[index].id == selectedSetId,
                onSelect: disabled ||
                        exercise.sets[index].status == SetStatus.completed ||
                        exercise.sets[index].status == SetStatus.skipped
                    ? null
                    : () => onSelect(exercise.sets[index]),
              ),
              if (index != exercise.sets.length - 1)
                SizedBox(height: theme.spacing.s4),
            ],
          ],
        ),
      ),
    );
  }
}

final class _FailurePanel extends StatelessWidget {
  const _FailurePanel({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Text(AppStrings.workoutCommandFailed),
          TextButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      );
}

WorkoutSet? _selectedSet(WorkoutSession session) {
  final id = session.activeSetId ?? session.selectedSetId;
  if (id == null) return null;
  for (final set in session.exercises.expand((exercise) => exercise.sets)) {
    if (set.id == id) return set;
  }
  return null;
}

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}
