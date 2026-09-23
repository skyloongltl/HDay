import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/workout_skin.dart';
import '../application/workout_providers.dart';
import '../domain/workout_draft.dart';
import '../domain/workout_event.dart';
import '../domain/workout_session.dart';

// PAGE: WorkoutSummaryScreen
// ROUTE: /summary/:sessionId
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, GridView, Card, TextField
// STATE: noteText(String), isCompletingSave(bool), isRestoreChecked(bool)
// ANIMATIONS: completion scale pop 380ms emphasized; press 100ms easeOut
// NAVIGATION: continue -> canonical prior phase; save -> /history/:workoutDate
final class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

final class _WorkoutSummaryScreenState
    extends ConsumerState<WorkoutSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _noteController;
  late final AnimationController _completionController;
  late final Animation<double> _completionScale;
  String noteText = ''; // Flutter: setState
  bool isCompletingSave = false; // Flutter: setState
  bool isRestoreChecked = false; // Flutter: setState

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _completionController = AnimationController(
      vsync: this,
      duration: WorkoutSkin.summaryPopDuration,
    );
    _completionScale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _completionController,
        curve: WorkoutSkin.summaryPopCurve,
      ),
    );
    _completionController.forward();
    Future<void>.microtask(_ensureRestored);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(workoutControllerProvider);
    final session = viewState.session;
    if (session == null || session.id != widget.sessionId) {
      if (isCompletingSave) {
        return const Scaffold(
          key: ValueKey('summary-screen'),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (session == null && !isRestoreChecked) {
        return const Scaffold(
          key: ValueKey('summary-screen'),
          body: Center(child: Text(AppStrings.restoringWorkout)),
        );
      }
      if (session == null && viewState.failure != null) {
        return Scaffold(
          key: const ValueKey('summary-screen'),
          body: Center(
            child: TextButton(
              onPressed: _retryRestore,
              child: const Text(AppStrings.retry),
            ),
          ),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.workoutFallback);
      });
      return const Scaffold(
        key: ValueKey('summary-screen'),
        body: Center(child: Text(AppStrings.workoutUnavailable)),
      );
    }
    if (session.phase != WorkoutPhase.finishing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.forWorkoutSession(session));
      });
      return const Scaffold(
        key: ValueKey('summary-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = AppTheme.of(context);
    final controlsDisabled = viewState.isSaving || viewState.failure != null;
    final allSets = session.exercises.expand((exercise) => exercise.sets);
    final completed =
        allSets.where((set) => set.status == SetStatus.completed).length;
    final skipped =
        allSets.where((set) => set.status == SetStatus.skipped).length;
    final unfinished =
        allSets.where((set) => set.status == SetStatus.pending).length;
    final completedExercises = session.exercises
        .where(
          (exercise) =>
              exercise.sets.any((set) => set.status == SetStatus.completed),
        )
        .length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        key: ValueKey('summary-${session.id}'),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text(AppStrings.workoutSummaryTitle),
        ),
        body: ListView(
          padding: EdgeInsets.all(theme.spacing.s16),
          children: [
            ScaleTransition(
              scale: _completionScale,
              child: Center(
                child: SizedBox.square(
                  dimension: theme.spacing.s32 * 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colors.mintSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: theme.colors.mintText,
                      size: theme.spacing.s28,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.spacing.s16),
            Text(
              AppStrings.totalTrainingDuration,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            SizedBox(height: theme.spacing.s6),
            Text(
              _format(session.timer.accumulatedActiveSeconds),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colors.text,
                fontSize: theme.typography.restTimer,
                fontWeight: theme.typography.heavy,
              ),
            ),
            SizedBox(height: theme.spacing.s8),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colors.mintSurface,
                  borderRadius: BorderRadius.circular(theme.radii.full),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.s14,
                    vertical: theme.spacing.s4,
                  ),
                  child: Text(
                    AppStrings.workoutSummary,
                    style: TextStyle(
                      color: theme.colors.mintText,
                      fontWeight: theme.typography.bold,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.spacing.s24),
            _StatsGrid(
              values: [
                ('$completedExercises', AppStrings.completedExercises),
                ('$completed', AppStrings.completedSets),
                ('$skipped', AppStrings.skippedSets),
                ('$unfinished', AppStrings.unfinishedSets),
              ],
            ),
            SizedBox(height: theme.spacing.s16),
            _SummaryCard(
              title: AppStrings.workoutDetails,
              child: Column(
                children: [
                  for (final exercise in session.exercises)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: theme.spacing.s8,
                      ),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: theme.spacing.s28,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: exercise.sets.any(
                                  (set) => set.status == SetStatus.completed,
                                )
                                    ? theme.colors.mintSurface
                                    : theme.colors.inputSurface,
                                borderRadius:
                                    BorderRadius.circular(theme.radii.sm),
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
                                Text(exercise.nameSnapshot),
                                Text(
                                  AppStrings.exerciseCompletion(
                                    exercise.sets
                                        .where(
                                          (set) =>
                                              set.status == SetStatus.completed,
                                        )
                                        .length,
                                    exercise.sets.length,
                                  ),
                                  style:
                                      Theme.of(context).textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                          if (exercise.sets.every(
                            (set) => set.status == SetStatus.completed,
                          ))
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: theme.spacing.s16,
                                  color: theme.colors.mintText,
                                ),
                                SizedBox(width: theme.spacing.s2),
                                Text(
                                  AppStrings.allSetsDone,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: theme.colors.mintText,
                                        fontWeight: theme.typography.bold,
                                      ),
                                ),
                              ],
                            )
                          else
                            Text(
                              '${exercise.sets.where((set) => set.status == SetStatus.completed).length}/${exercise.sets.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: theme.colors.textSubtle,
                                    fontWeight: theme.typography.bold,
                                  ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: theme.spacing.s16),
            _SummaryCard(
              title: AppStrings.workoutNote,
              child: TextField(
                key: const ValueKey('summary-note'),
                controller: _noteController,
                enabled: !controlsDisabled,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: AppStrings.workoutNoteHint,
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => noteText = value),
              ),
            ),
            if (viewState.failure != null) ...[
              SizedBox(height: theme.spacing.s8),
              const Text(AppStrings.workoutSaveFailed),
              TextButton(
                key: const ValueKey('summary-retry'),
                onPressed: viewState.isSaving
                    ? null
                    : () => _retrySave(session.workoutDate.iso8601),
                child: const Text(AppStrings.retry),
              ),
            ],
            SizedBox(height: theme.spacing.s16),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border(top: BorderSide(color: theme.colors.outline)),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.s16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('save-summary'),
                      onPressed: controlsDisabled ? null : _save,
                      child: Text(
                        viewState.isSaving
                            ? AppStrings.saving
                            : AppStrings.saveWorkout,
                      ),
                    ),
                  ),
                  SizedBox(height: theme.spacing.s8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('continue-workout'),
                      onPressed: controlsDisabled ? null : _continueWorkout,
                      child: const Text(AppStrings.returnToWorkout),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueWorkout() async {
    try {
      await ref
          .read(workoutControllerProvider.notifier)
          .dispatch(const ContinueWorkout());
      final session = ref.read(workoutControllerProvider).session;
      if (mounted && session != null) {
        context.go(AppRoutes.forWorkoutSession(session));
      }
    } on Object {
      // Controller exposes retry and preserves noteText.
    }
  }

  Future<void> _ensureRestored() async {
    if (ref.read(workoutControllerProvider).session == null) {
      try {
        await ref.read(workoutControllerProvider.notifier).restore();
      } on Object {
        // The route renders retry from controller failure state.
      }
    }
    if (mounted) setState(() => isRestoreChecked = true);
  }

  Future<void> _retryRestore() async {
    try {
      await ref.read(workoutControllerProvider.notifier).retry();
    } on Object {
      // Keep retry visible.
    }
  }

  Future<void> _retrySave(String workoutDate) async {
    setState(() => isCompletingSave = true);
    try {
      await ref.read(workoutControllerProvider.notifier).retry();
      if (mounted) context.go('/history/$workoutDate');
    } on Object {
      if (mounted) setState(() => isCompletingSave = false);
    }
  }

  Future<void> _save() async {
    setState(() => isCompletingSave = true);
    try {
      final date = await ref
          .read(workoutControllerProvider.notifier)
          .save(note: noteText);
      if (mounted) context.go('/history/${date.iso8601}');
    } on Object {
      if (mounted) setState(() => isCompletingSave = false);
      // Controller preserves committed state, pending command, and noteText.
    }
  }
}

final class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.values});
  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: WorkoutSkin.summaryStatAspectRatio,
      mainAxisSpacing: theme.spacing.s8,
      crossAxisSpacing: theme.spacing.s8,
      children: [
        for (final value in values)
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border.all(color: theme.colors.outline),
              borderRadius: BorderRadius.circular(theme.radii.md),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.$1,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    value.$2,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.outline),
        borderRadius: BorderRadius.circular(theme.radii.lg),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: theme.spacing.s8),
            child,
          ],
        ),
      ),
    );
  }
}

String _format(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
