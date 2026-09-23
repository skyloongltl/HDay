import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/workout_skin.dart';
import '../application/workout_providers.dart';
import '../domain/workout_draft.dart';
import '../domain/workout_event.dart';
import '../domain/workout_session.dart';

// Flutter: BottomSheet, Column, FilledButton, AlertDialog
// Animation: sheet slide 280ms; overlay fade 200ms easeOut
final class EarlyEndSheet extends ConsumerStatefulWidget {
  const EarlyEndSheet({required this.session, super.key});
  final WorkoutSession session;

  static Future<void> show(BuildContext context, WorkoutSession session) {
    final theme = AppTheme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      barrierColor:
          theme.colors.text.withValues(alpha: theme.opacities.overlay),
      backgroundColor: theme.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.radii.xl)),
      ),
      sheetAnimationStyle: const AnimationStyle(
        duration: WorkoutSkin.sheetDuration,
        curve: WorkoutSkin.sheetCurve,
      ),
      builder: (_) => EarlyEndSheet(session: session),
    );
  }

  @override
  ConsumerState<EarlyEndSheet> createState() => _EarlyEndSheetState();
}

final class _EarlyEndSheetState extends ConsumerState<EarlyEndSheet> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(WorkoutSkin.timerTick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final viewState = ref.watch(workoutControllerProvider);
    final sets =
        widget.session.exercises.expand((exercise) => exercise.sets).toList();
    final completed =
        sets.where((set) => set.status == SetStatus.completed).length;
    final remaining = sets.length - completed;
    final duration =
        widget.session.timer.read(ref.read(clockProvider).nowUtc()).seconds;
    final controlsDisabled = viewState.isSaving || viewState.failure != null;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * WorkoutSkin.sheetFraction,
      ),
      child: SingleChildScrollView(
        key: const ValueKey('early-end-sheet'),
        padding: EdgeInsets.fromLTRB(
          theme.spacing.s20,
          theme.spacing.s12,
          theme.spacing.s20,
          theme.spacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SizedBox(
                width: theme.spacing.s40,
                height: theme.spacing.s4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colors.outline,
                    borderRadius: BorderRadius.circular(theme.radii.full),
                  ),
                ),
              ),
            ),
            SizedBox(height: theme.spacing.s16),
            Text(
              AppStrings.earlyEndTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: theme.spacing.s8),
            Text(AppStrings.earlyEndConsequence(remaining)),
            SizedBox(height: theme.spacing.s16),
            Row(
              children: [
                Expanded(
                  child: _EarlyEndStat(
                    key: const ValueKey('early-end-duration'),
                    value: _formatDuration(duration),
                    label: AppStrings.trainingDuration,
                  ),
                ),
                Expanded(
                  child: _EarlyEndStat(
                    key: const ValueKey('early-end-completed'),
                    value: '$completed',
                    label: AppStrings.completedSets,
                  ),
                ),
                Expanded(
                  child: _EarlyEndStat(
                    key: const ValueKey('early-end-remaining'),
                    value: '$remaining',
                    label: AppStrings.unfinishedSets,
                  ),
                ),
              ],
            ),
            if (!widget.session.hasCompletedSet) ...[
              SizedBox(height: theme.spacing.s8),
              const Text(AppStrings.cannotSaveEmptyWorkout),
            ],
            SizedBox(height: theme.spacing.s20),
            if (widget.session.hasCompletedSet) ...[
              FilledButton(
                key: const ValueKey('end-and-save'),
                onPressed: controlsDisabled
                    ? null
                    : () => _prepareFinish(context, ref),
                child: const Text(AppStrings.endAndSave),
              ),
              SizedBox(height: theme.spacing.s8),
            ],
            OutlinedButton(
              key: const ValueKey('continue-training'),
              onPressed: controlsDisabled ? null : () => Navigator.pop(context),
              child: const Text(AppStrings.continueTraining),
            ),
            SizedBox(height: theme.spacing.s8),
            TextButton(
              key: const ValueKey('discard-workout'),
              onPressed:
                  controlsDisabled ? null : () => _confirmDiscard(context, ref),
              child: Text(
                AppStrings.discardWorkout,
                style: TextStyle(color: theme.colors.danger),
              ),
            ),
            if (viewState.failure != null)
              TextButton(
                key: const ValueKey('early-end-retry'),
                onPressed: () =>
                    ref.read(workoutControllerProvider.notifier).retry(),
                child: const Text(AppStrings.retry),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _prepareFinish(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(workoutControllerProvider.notifier)
          .dispatch(const PrepareFinish());
      if (!context.mounted) return;
      Navigator.pop(context);
      context.go(AppRoutes.summary(widget.session.id));
    } on Object {
      // Controller retains committed state and exposes retry.
    }
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final theme = AppTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.discardWorkoutTitle),
        content: const Text(AppStrings.discardWorkoutHint),
        actions: [
          TextButton(
            key: const ValueKey('cancel-discard'),
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              minimumSize: Size(theme.minTapTarget, theme.minTapTarget),
            ),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            key: const ValueKey('confirm-discard'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              minimumSize: Size(theme.minTapTarget, theme.minTapTarget),
            ),
            child: Text(
              AppStrings.confirmDiscardWorkout,
              style: TextStyle(color: theme.colors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(workoutControllerProvider.notifier).discard();
      if (!context.mounted) return;
      Navigator.pop(context);
      context.go(AppRoutes.home);
    } on Object {
      // Controller retains committed state and exposes retry.
    }
  }
}

final class _EarlyEndStat extends StatelessWidget {
  const _EarlyEndStat({
    required this.value,
    required this.label,
    super.key,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: theme.spacing.s4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

String _formatDuration(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
