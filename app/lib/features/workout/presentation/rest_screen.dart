import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/workout_skin.dart';
import '../../../widgets/rest_ring.dart';
import '../../../widgets/set_row.dart';
import '../../../widgets/workout_end_button.dart';
import '../../exercises/domain/exercise.dart';
import '../application/workout_controller.dart';
import '../application/workout_providers.dart';
import '../domain/workout_draft.dart';
import '../domain/workout_event.dart';
import '../domain/workout_session.dart';
import 'early_end_sheet.dart';

// PAGE: RestScreen
// ROUTE: /rest/:sessionId
// FLUTTER WIDGETS: Scaffold, AppBar, CustomPaint, ListView, BottomSheet
// STATE: isEndSheetOpen(bool)
// ANIMATIONS: ring 1000ms linear; overtime 300ms easeOut; sheet 280ms
// NAVIGATION: start selected set -> /workout/:sessionId; back -> /home
final class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

final class _RestScreenState extends ConsumerState<RestScreen> {
  late final WorkoutController _workoutController;
  late final String _visibilityOwner;
  bool isEndSheetOpen = false; // Flutter: setState
  Timer? _ticker;
  bool isRestoreChecked = false; // Flutter: setState

  @override
  void initState() {
    super.initState();
    _workoutController = ref.read(workoutControllerProvider.notifier);
    _visibilityOwner = 'rest-${identityHashCode(this)}';
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
        key: ValueKey('rest-screen'),
        body: Center(child: Text(AppStrings.restoringWorkout)),
      );
    }
    if (session == null && state.failure != null) {
      return Scaffold(
        key: const ValueKey('rest-screen'),
        body: Center(
          child: TextButton(
            onPressed: _retryRestore,
            child: const Text(AppStrings.retry),
          ),
        ),
      );
    }
    if (session == null || session.id != widget.sessionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.workoutFallback);
      });
      return const Scaffold(
        key: ValueKey('rest-screen'),
        body: Center(child: Text(AppStrings.workoutUnavailable)),
      );
    }
    if (session.phase != WorkoutPhase.resting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.forWorkoutSession(session));
      });
      return const Scaffold(
        key: ValueKey('rest-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = AppTheme.of(context);
    final now = ref.read(clockProvider).nowUtc();
    final elapsed = session.restTimer.read(now).seconds;
    final target = session.restTargetSeconds ?? 0;
    final selected = _selectedPending(session);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        key: ValueKey('rest-${session.id}'),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: theme.minTapTarget + theme.spacing.s24,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.trainingDuration,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                _format(session.timer.read(now).seconds),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          actions: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.restMode,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                WorkoutEndButton(
                  key: const ValueKey('end-rest-workout'),
                  onPressed: state.isSaving || state.failure != null
                      ? null
                      : () => _openEndSheet(session),
                ),
              ],
            ),
            SizedBox(width: theme.spacing.s8),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.all(theme.spacing.s16),
          children: [
            Text(
              AppStrings.targetRestSummary(target),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            SizedBox(height: theme.spacing.s4),
            Center(
              child: RestRing(
                elapsedSeconds: elapsed,
                targetSeconds: target,
              ),
            ),
            SizedBox(height: theme.spacing.s20),
            if (selected != null)
              Card(
                margin: EdgeInsets.zero,
                elevation: theme.dimensions.zero,
                color: theme.colors.surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(theme.radii.lg),
                  side: BorderSide(
                    color: theme.colors.outline,
                    width: theme.borders.thin,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.s14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppStrings.nextSetLabel,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      SizedBox(height: theme.spacing.s6),
                      Text(
                        '${selected.$1.nameSnapshot} · ${AppStrings.setNumber} ${selected.$1.sets.indexOf(selected.$2) + 1}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: theme.spacing.s4),
                      Text(
                        _prescription(selected.$2),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: theme.colors.textMuted,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_followingPending(session, selected?.$2.id)
                case final following?) ...[
              SizedBox(height: theme.spacing.s10),
              Text(
                '${AppStrings.laterSetLabel}：${following.$1.nameSnapshot} · ${_prescription(following.$2)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: theme.colors.textSubtle,
                    ),
              ),
            ],
            SizedBox(height: theme.spacing.s16),
            Text(
              AppStrings.chooseAnotherSet,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: theme.spacing.s8),
            for (final exercise in session.exercises)
              for (var index = 0; index < exercise.sets.length; index++)
                if (exercise.sets[index].status == SetStatus.pending)
                  Padding(
                    padding: EdgeInsets.only(bottom: theme.spacing.s4),
                    child: SetRow(
                      key: ValueKey('rest-set-${exercise.sets[index].id}'),
                      index: index + 1,
                      set: exercise.sets[index],
                      selected:
                          exercise.sets[index].id == session.selectedSetId,
                      onSelect: state.isSaving || state.failure != null
                          ? null
                          : () => _dispatch(
                                SelectSet(exercise.sets[index].id),
                              ),
                    ),
                  ),
            if (state.failure != null)
              TextButton(
                onPressed: () =>
                    ref.read(workoutControllerProvider.notifier).retry(),
                child: const Text(AppStrings.retry),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.s16),
            child: FilledButton(
              key: const ValueKey('start-next-set'),
              onPressed:
                  selected == null || state.isSaving || state.failure != null
                      ? null
                      : () => _start(selected.$2),
              child: const Text(AppStrings.startNextSet),
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
      // The controller owns failure and retry state.
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

  Future<void> _start(WorkoutSet set) async {
    await _dispatch(StartSet(set.id));
    final session = ref.read(workoutControllerProvider).session;
    if (mounted && session?.phase == WorkoutPhase.active) {
      context.go(AppRoutes.workout(session!.id));
    }
  }

  Future<void> _openEndSheet(WorkoutSession session) async {
    setState(() => isEndSheetOpen = true);
    await EarlyEndSheet.show(context, session);
    if (mounted) setState(() => isEndSheetOpen = false);
  }
}

(WorkoutExercise, WorkoutSet)? _selectedPending(WorkoutSession session) {
  final selectedId = session.selectedSetId;
  for (final exercise in session.exercises) {
    for (final set in exercise.sets) {
      if (set.status == SetStatus.pending &&
          (set.id == selectedId || selectedId == null)) {
        return (exercise, set);
      }
    }
  }
  return null;
}

(WorkoutExercise, WorkoutSet)? _followingPending(
  WorkoutSession session,
  String? selectedId,
) {
  for (final exercise in session.exercises) {
    for (final set in exercise.sets) {
      if (set.status == SetStatus.pending && set.id != selectedId) {
        return (exercise, set);
      }
    }
  }
  return null;
}

String _prescription(WorkoutSet set) {
  final weight = set.actualWeight ?? set.plannedWeight;
  final reps = set.actualReps ?? set.plannedReps;
  final weightLabel = set.unit == WeightUnit.bodyweight
      ? AppStrings.bodyweight
      : '${AppStrings.compactNumber(weight)} ${AppStrings.weightUnitLabels[set.unit.code]}';
  return '$weightLabel ${AppStrings.multiplicationSign} ${AppStrings.setReps(reps)}';
}

String _format(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
