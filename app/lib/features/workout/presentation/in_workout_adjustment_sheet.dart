import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/workout_skin.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/presentation/exercise_picker_sheet.dart';
import '../../settings/data/sqlite_settings_repository.dart';
import '../../settings/domain/app_settings.dart';
import '../application/workout_providers.dart';
import '../domain/workout_draft.dart';
import '../domain/workout_event.dart';
import '../domain/workout_session.dart';

enum AdjustmentTab { edit, skip, add }

typedef _TemporaryExerciseDefaults = ({
  double plannedWeight,
  int plannedReps,
  int targetRestSeconds,
});

// Flutter: BottomSheet, TabBar, Column, TextField, ListView
// STATE: activeTab, showPicker, editWeight, editReps
// Animation: sheet slide 280ms; tab indicator 150ms easeOut
final class InWorkoutAdjustmentSheet extends ConsumerStatefulWidget {
  const InWorkoutAdjustmentSheet({required this.initialTab, super.key});
  final AdjustmentTab initialTab;

  static Future<void> show(
    BuildContext context, {
    required AdjustmentTab initialTab,
  }) {
    final theme = AppTheme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
      builder: (_) => InWorkoutAdjustmentSheet(initialTab: initialTab),
    );
  }

  @override
  ConsumerState<InWorkoutAdjustmentSheet> createState() =>
      _InWorkoutAdjustmentSheetState();
}

final class _InWorkoutAdjustmentSheetState
    extends ConsumerState<InWorkoutAdjustmentSheet> {
  late AdjustmentTab activeTab = widget.initialTab; // Flutter: setState
  bool showPicker = false; // Flutter: setState
  String editWeight = ''; // Flutter: setState
  String editReps = ''; // Flutter: setState
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  late final Future<AppSettings> _settings;

  @override
  void initState() {
    super.initState();
    final session = ref.read(workoutControllerProvider).session;
    final set = session == null ? null : _selectedSet(session)?.$2;
    editWeight = '${set?.actualWeight ?? set?.plannedWeight ?? ''}';
    editReps = '${set?.actualReps ?? set?.plannedReps ?? ''}';
    _weightController = TextEditingController(text: editWeight);
    _repsController = TextEditingController(text: editReps);
    _settings = _loadSettings();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final viewState = ref.watch(workoutControllerProvider);
    final session = viewState.session;
    final selected = session == null ? null : _selectedSet(session);
    final controlsDisabled = viewState.isSaving || viewState.failure != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * WorkoutSkin.sheetFraction,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: theme.spacing.s12),
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
            SizedBox(height: theme.spacing.s8),
            Row(
              children: [
                _TabButton(
                  key: const ValueKey('adjust-tab-edit'),
                  label: AppStrings.editWorkoutData,
                  selected: activeTab == AdjustmentTab.edit,
                  onPressed: controlsDisabled
                      ? null
                      : () => setState(() => activeTab = AdjustmentTab.edit),
                ),
                _TabButton(
                  key: const ValueKey('adjust-tab-skip'),
                  label: AppStrings.skipActions,
                  selected: activeTab == AdjustmentTab.skip,
                  onPressed: controlsDisabled
                      ? null
                      : () => setState(() => activeTab = AdjustmentTab.skip),
                ),
                _TabButton(
                  key: const ValueKey('adjust-tab-add'),
                  label: AppStrings.addDeleteActions,
                  selected: activeTab == AdjustmentTab.add,
                  onPressed: controlsDisabled
                      ? null
                      : () => setState(() => activeTab = AdjustmentTab.add),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(theme.spacing.s20),
                child: switch (activeTab) {
                  AdjustmentTab.edit => _editTab(selected, controlsDisabled),
                  AdjustmentTab.skip => _skipTab(selected, controlsDisabled),
                  AdjustmentTab.add =>
                    _addTab(session, selected, controlsDisabled),
                },
              ),
            ),
            if (viewState.failure != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.s20),
                child: TextButton(
                  key: const ValueKey('adjustment-retry'),
                  onPressed: viewState.isSaving
                      ? null
                      : () =>
                          ref.read(workoutControllerProvider.notifier).retry(),
                  child: const Text(AppStrings.retry),
                ),
              ),
            SizedBox(height: theme.spacing.s12),
          ],
        ),
      ),
    );
  }

  Widget _editTab((WorkoutExercise, WorkoutSet)? selected, bool disabled) {
    final theme = AppTheme.of(context);
    if (selected == null) return const Text(AppStrings.noSelectedSet);
    final setNumber = selected.$1.sets.indexOf(selected.$2) + 1;
    final weightUnit = selected.$2.unit == WeightUnit.bodyweight
        ? AppStrings.bodyweight
        : AppStrings.weightUnitLabels[selected.$2.unit.code]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.currentSetContext(selected.$1.nameSnapshot, setNumber),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: theme.spacing.s12),
        TextField(
          key: const ValueKey('edit-weight'),
          controller: _weightController,
          enabled: !disabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: AppStrings.actualWeight,
            suffixText: weightUnit,
            filled: true,
            fillColor: theme.colors.inputSurface,
          ),
          onChanged: (value) => setState(() => editWeight = value),
        ),
        SizedBox(height: theme.spacing.s12),
        TextField(
          key: const ValueKey('edit-reps'),
          controller: _repsController,
          enabled: !disabled,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: AppStrings.actualReps,
            suffixText: AppStrings.repsUnit,
            filled: true,
            fillColor: theme.colors.inputSurface,
          ),
          onChanged: (value) => setState(() => editReps = value),
        ),
        SizedBox(height: theme.spacing.s20),
        FilledButton(
          key: const ValueKey('confirm-edit'),
          onPressed: disabled ? null : () => _edit(selected.$2),
          child: const Text(AppStrings.confirmEdit),
        ),
      ],
    );
  }

  Widget _skipTab((WorkoutExercise, WorkoutSet)? selected, bool disabled) {
    final theme = AppTheme.of(context);
    if (selected == null) return const Text(AppStrings.noSelectedSet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdjustmentActionButton(
          key: const ValueKey('skip-set'),
          icon: Icons.skip_next,
          title: AppStrings.skipSelectedSet,
          description: AppStrings.skipSelectedSetHint,
          onPressed: disabled
              ? null
              : () => _run(SkipSet(selected.$2.id), close: true),
        ),
        SizedBox(height: theme.spacing.s8),
        _AdjustmentActionButton(
          key: const ValueKey('skip-exercise'),
          icon: Icons.fast_forward,
          title: AppStrings.skipSelectedExercise,
          description: AppStrings.skipSelectedExerciseHint,
          onPressed: disabled
              ? null
              : () => _run(SkipExercise(selected.$1.id), close: true),
        ),
      ],
    );
  }

  Widget _addTab(
    WorkoutSession? session,
    (WorkoutExercise, WorkoutSet)? selected,
    bool disabled,
  ) {
    final theme = AppTheme.of(context);
    if (session == null) return const SizedBox.shrink();
    final movable = session.exercises
        .where(
          (exercise) => exercise.sets.every(
            (set) =>
                set.status == SetStatus.pending ||
                set.status == SetStatus.skipped,
          ),
        )
        .toList();
    final movableIndex = selected == null
        ? -1
        : movable.indexWhere((exercise) => exercise.id == selected.$1.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdjustmentActionButton(
          key: const ValueKey('add-exercise'),
          icon: Icons.add_circle_outline,
          title: AppStrings.addTemporaryWorkoutExercise,
          description: AppStrings.addTemporaryWorkoutExerciseHint,
          emphasized: true,
          onPressed: disabled ? null : () => _pickExercise(session),
        ),
        SizedBox(height: theme.spacing.s8),
        if (selected != null)
          _AdjustmentActionButton(
            key: const ValueKey('add-set'),
            icon: Icons.playlist_add,
            title: AppStrings.addSet,
            description: AppStrings.addWorkoutSetHint,
            onPressed: disabled ? null : () => _addSet(selected.$1),
          ),
        if (selected?.$2.status == SetStatus.pending) ...[
          SizedBox(height: theme.spacing.s8),
          TextButton(
            key: const ValueKey('delete-set'),
            onPressed: disabled
                ? null
                : () => _run(DeletePendingSet(selected!.$2.id), close: true),
            child: const Text(AppStrings.deleteSelectedSet),
          ),
        ],
        if (movable.length > 1 &&
            selected != null &&
            movable.any((exercise) => exercise.id == selected.$1.id)) ...[
          SizedBox(height: theme.spacing.s8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('move-exercise-earlier'),
                  onPressed: disabled || movableIndex <= 0
                      ? null
                      : () => _reorder(movable, selected.$1, -1),
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text(AppStrings.moveExerciseEarlier),
                ),
              ),
              SizedBox(width: theme.spacing.s8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('move-exercise-later'),
                  onPressed: disabled || movableIndex >= movable.length - 1
                      ? null
                      : () => _reorder(movable, selected.$1, 1),
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text(AppStrings.moveExerciseLater),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _edit(WorkoutSet set) async {
    final weight = double.tryParse(editWeight);
    final reps = int.tryParse(editReps);
    if (weight == null ||
        !weight.isFinite ||
        weight < 0 ||
        reps == null ||
        reps < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reps == null || reps < 1
                ? AppStrings.invalidReps
                : AppStrings.invalidWeight,
          ),
        ),
      );
      return;
    }
    await _run(UpdateActual(set.id, weight: weight, reps: reps), close: true);
  }

  Future<void> _addSet(WorkoutExercise exercise) async {
    final template = exercise.sets.last;
    final suffix = ref.read(clockProvider).nowUtc().microsecondsSinceEpoch;
    await _run(
      AddSet(
        exercise.id,
        WorkoutSet(
          id: 'temporary-set-$suffix',
          order: exercise.sets.length,
          plannedWeight: template.plannedWeight,
          plannedReps: template.plannedReps,
          unit: template.unit,
          temporary: true,
        ),
      ),
      close: true,
    );
  }

  Future<void> _pickExercise(WorkoutSession session) async {
    setState(() => showPicker = true);
    await ExercisePickerSheet.show(
      context,
      excludeIds:
          session.exercises.map((exercise) => exercise.exerciseId).toSet(),
      onSelected: (exercise) => unawaited(_addExercise(session, exercise)),
    );
    if (mounted) setState(() => showPicker = false);
  }

  Future<void> _addExercise(
    WorkoutSession session,
    Exercise exercise,
  ) async {
    final settings = await _settings;
    if (!mounted) return;
    final suffix = ref.read(clockProvider).nowUtc().microsecondsSinceEpoch;
    final defaults = _temporaryExerciseDefaults(session, settings);
    await _run(
      AddExercise(
        WorkoutExercise(
          id: 'temporary-exercise-$suffix',
          exerciseId: exercise.id,
          nameSnapshot: exercise.name,
          categorySnapshot: exercise.category,
          equipmentSnapshot: exercise.equipment,
          unitSnapshot: exercise.defaultUnit,
          note: exercise.note,
          targetRestSeconds: defaults.targetRestSeconds,
          order: session.exercises.length,
          temporary: true,
          sets: [
            WorkoutSet(
              id: 'temporary-set-$suffix',
              order: 0,
              plannedWeight: defaults.plannedWeight,
              plannedReps: defaults.plannedReps,
              unit: exercise.defaultUnit,
              temporary: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<AppSettings> _loadSettings() async {
    final database = await ref.read(appDatabaseProvider.future);
    return SqliteSettingsRepository(database).read();
  }

  _TemporaryExerciseDefaults _temporaryExerciseDefaults(
    WorkoutSession session,
    AppSettings settings,
  ) {
    if (session.exercises.isEmpty) {
      return (
        plannedWeight: 0,
        plannedReps: 10,
        targetRestSeconds: settings.defaultRestSeconds,
      );
    }
    final exercise = session.exercises.last;
    final set = exercise.sets.last;
    return (
      plannedWeight: set.plannedWeight,
      plannedReps: set.plannedReps,
      targetRestSeconds: exercise.targetRestSeconds,
    );
  }

  Future<void> _reorder(
    List<WorkoutExercise> movable,
    WorkoutExercise selected,
    int delta,
  ) async {
    final ids = movable.map((exercise) => exercise.id).toList();
    final from = ids.indexOf(selected.id);
    if (from < 0) return;
    final to = (from + delta).clamp(0, ids.length - 1);
    if (from == to) return;
    final id = ids.removeAt(from);
    ids.insert(to, id);
    await _run(ReorderPendingExercises(ids));
  }

  Future<void> _run(WorkoutEvent event, {bool close = false}) async {
    try {
      await ref.read(workoutControllerProvider.notifier).dispatch(event);
      if (close && mounted) Navigator.pop(context);
    } on Object {
      // Preserve local form state and expose controller retry.
    }
  }
}

final class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Expanded(
      child: SizedBox(
        height: theme.minTapTarget,
        child: Column(
          children: [
            Expanded(
              child: TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: selected
                      ? theme.colors.primaryAction
                      : theme.colors.textMuted,
                ),
                child: Text(label),
              ),
            ),
            SizedBox(
              height: theme.spacing.s2,
              child: ColoredBox(
                color:
                    selected ? theme.colors.primaryAction : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _AdjustmentActionButton extends StatelessWidget {
  const _AdjustmentActionButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
    this.emphasized = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: emphasized
            ? theme.colors.primarySurface
            : theme.colors.inputSurface,
        foregroundColor:
            emphasized ? theme.colors.primaryAction : theme.colors.text,
        side: BorderSide(
          color: emphasized ? theme.colors.primaryAction : theme.colors.outline,
          width: theme.borders.thin,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.s14,
          vertical: theme.spacing.s10,
        ),
      ),
      child: Row(
        children: [
          Icon(icon),
          SizedBox(width: theme.spacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(
                  description,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

(WorkoutExercise, WorkoutSet)? _selectedSet(WorkoutSession session) {
  final id = session.activeSetId ?? session.selectedSetId;
  if (id == null) return null;
  for (final exercise in session.exercises) {
    for (final set in exercise.sets) {
      if (set.id == id) return (exercise, set);
    }
  }
  return null;
}
