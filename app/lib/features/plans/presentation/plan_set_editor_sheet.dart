import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/plan_skin.dart';
import '../../exercises/domain/exercise.dart';
import '../application/plan_providers.dart';
import '../domain/plan_day.dart';
import 'plan_form_widgets.dart';

// Flutter: modal BottomSheet; edits are explicit Riverpod draft commands.
// Animation: platform sheet slide-up 280ms easeOut; no autosave.
class PlanSetEditorSheet extends ConsumerStatefulWidget {
  const PlanSetEditorSheet({
    required this.planId,
    required this.dayIndex,
    required this.exerciseId,
    super.key,
  });
  final String planId, exerciseId;
  final int dayIndex;
  static Future<void> show(
    BuildContext context, {
    required String planId,
    required int dayIndex,
    required String exerciseId,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppTheme.of(context).colors.page,
        builder: (_) => PlanSetEditorSheet(
          planId: planId,
          dayIndex: dayIndex,
          exerciseId: exerciseId,
        ),
      );
  @override
  ConsumerState<PlanSetEditorSheet> createState() => _PlanSetEditorSheetState();
}

class _PlanSetEditorSheetState extends ConsumerState<PlanSetEditorSheet> {
  late final initial = ref
      .read(planEditorControllerProvider(widget.planId))
      .days[widget.dayIndex]
      .exercises
      .firstWhere((e) => e.id == widget.exerciseId);
  late final note = TextEditingController(
    text: initial.note,
  ); // Flutter: TextEditingController
  late final targetRest = TextEditingController(
    text: initial.targetRestSeconds.toString(),
  ); // Flutter: TextEditingController
  bool restError = false; // Flutter: setState
  @override
  void dispose() {
    note.dispose();
    targetRest.dispose();
    super.dispose();
  }

  void _updateNote() {
    final rest = int.tryParse(targetRest.text);
    setState(() => restError = rest == null || rest < 0);
    if (!restError) {
      ref
          .read(planEditorControllerProvider(widget.planId).notifier)
          .updateExercise(
            widget.dayIndex,
            widget.exerciseId,
            note: note.text,
            targetRestSeconds: rest!,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    final editor =
        ref.read(planEditorControllerProvider(widget.planId).notifier);
    final exercise = ref
        .watch(planEditorControllerProvider(widget.planId))
        .days[widget.dayIndex]
        .exercises
        .firstWhere((e) => e.id == widget.exerciseId);
    return FractionallySizedBox(
      heightFactor: PlanSkin.searchSheetFraction,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        // Flutter: Column, mainAxis: start, crossAxis: stretch
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              dense: true,
              minVerticalPadding: theme.spacing.s2,
              visualDensity: const VisualDensity(vertical: -3),
              contentPadding: EdgeInsets.symmetric(
                horizontal: theme.spacing.s16,
              ),
              title: Text(
                exercise.nameSnapshot,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: const Text(AppStrings.editSets),
              trailing: TextButton(
                style: skin.textButton,
                onPressed: restError ? null : () => Navigator.pop(context),
                child: const Text(AppStrings.done),
              ),
            ),
            Expanded(
              // Flutter: ListView, mainAxis: start, crossAxis: stretch
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.s12),
                children: [
                  PlanTextField(
                    label: AppStrings.exerciseNote,
                    controller: note,
                    fieldKey: const Key('plan-exercise-note'),
                    onChanged: (_) => _updateNote(),
                    lines: PlanSkin.notesLines,
                  ),
                  PlanTextField(
                    label: AppStrings.targetRest,
                    controller: targetRest,
                    fieldKey: const Key('plan-exercise-rest'),
                    number: true,
                    onChanged: (_) => _updateNote(),
                    error: restError ? AppStrings.invalidNumber : null,
                  ),
                  if (exercise.sets.isEmpty)
                    Text(AppStrings.noSetsHint, style: skin.caption),
                  for (final (index, set) in exercise.sets.indexed)
                    Container(
                      key: ValueKey('plan-set-${set.id}'),
                      decoration: skin.panel(compact: true),
                      margin: EdgeInsets.only(bottom: theme.spacing.s6),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          dense: true,
                          minVerticalPadding: theme.spacing.s2,
                          visualDensity: const VisualDensity(vertical: -4),
                          contentPadding:
                              EdgeInsets.only(left: theme.spacing.s10),
                          onTap: () => _editSet(set: set),
                          title: Text(
                            AppStrings.setRow(
                              index + 1,
                              set.plannedWeight,
                              set.unit.code,
                              set.plannedReps,
                            ),
                            style: skin.title,
                          ),
                          trailing: PopupMenuButton<String>(
                            key: ValueKey('set-menu-${set.id}'),
                            tooltip: AppStrings.moreActions,
                            color: theme.colors.surface,
                            surfaceTintColor: Colors.transparent,
                            shape: skin.menuShape,
                            menuPadding: skin.menuPadding,
                            constraints: skin.menuConstraints,
                            onSelected: (action) async {
                              if (action == 'edit') _editSet(set: set);
                              if (action == 'copy') {
                                editor.copySet(
                                  widget.dayIndex,
                                  widget.exerciseId,
                                  set.id,
                                );
                              }
                              if (action == 'delete' &&
                                  await confirmPlanAction(
                                    context,
                                    title: AppStrings.removeSet,
                                    message: AppStrings.removeItemHint,
                                    action: AppStrings.confirmDelete,
                                  )) {
                                editor.deleteSet(
                                  widget.dayIndex,
                                  widget.exerciseId,
                                  set.id,
                                );
                              }
                              if (action == 'up' || action == 'down') {
                                final ids =
                                    exercise.sets.map((s) => s.id).toList();
                                final next =
                                    action == 'up' ? index - 1 : index + 1;
                                ids.removeAt(index);
                                ids.insert(next, set.id);
                                editor.reorderSets(
                                  widget.dayIndex,
                                  widget.exerciseId,
                                  ids,
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                height: PlanSkin.menuItemHeight,
                                child: Text(AppStrings.edit),
                              ),
                              const PopupMenuItem(
                                value: 'copy',
                                height: PlanSkin.menuItemHeight,
                                child: Text(AppStrings.duplicate),
                              ),
                              if (index > 0)
                                const PopupMenuItem(
                                  value: 'up',
                                  height: PlanSkin.menuItemHeight,
                                  child: Text(AppStrings.moveUp),
                                ),
                              if (index < exercise.sets.length - 1)
                                const PopupMenuItem(
                                  value: 'down',
                                  height: PlanSkin.menuItemHeight,
                                  child: Text(AppStrings.moveDown),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                height: PlanSkin.menuItemHeight,
                                child: Text(AppStrings.removeSet),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.s12),
                    child: ElevatedButton(
                      key: const Key('plan-batch-sets'),
                      onPressed: () => _editSet(),
                      child: const Text(AppStrings.batchAddSets),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSet({PlanSet? set}) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppTheme.of(context).colors.page,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _PlanSetForm(
          planId: widget.planId,
          dayIndex: widget.dayIndex,
          exerciseId: widget.exerciseId,
          set: set,
        ),
      );
}

class _PlanSetForm extends ConsumerStatefulWidget {
  const _PlanSetForm({
    required this.planId,
    required this.dayIndex,
    required this.exerciseId,
    this.set,
  });
  final String planId, exerciseId;
  final int dayIndex;
  final PlanSet? set;
  @override
  ConsumerState<_PlanSetForm> createState() => _PlanSetFormState();
}

class _PlanSetFormState extends ConsumerState<_PlanSetForm> {
  late final weight = TextEditingController(
    text: (widget.set?.plannedWeight ?? 0).toString(),
  ); // Flutter: TextEditingController
  late final reps = TextEditingController(
    text: (widget.set?.plannedReps ?? 8).toString(),
  ); // Flutter: TextEditingController
  final count =
      TextEditingController(text: '1'); // Flutter: TextEditingController
  late WeightUnit unit = widget.set?.unit ?? WeightUnit.kg; // Flutter: setState
  bool invalid = false; // Flutter: setState
  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
    count.dispose();
    super.dispose();
  }

  void _save() {
    final w = double.tryParse(weight.text);
    final r = int.tryParse(reps.text);
    final c = int.tryParse(count.text);
    setState(
      () => invalid = w == null ||
          !w.isFinite ||
          w < 0 ||
          r == null ||
          r < 1 ||
          c == null ||
          c < 1,
    );
    if (invalid) return;
    final editor =
        ref.read(planEditorControllerProvider(widget.planId).notifier);
    if (widget.set == null) {
      editor.batchAddSets(
        widget.dayIndex,
        widget.exerciseId,
        count: c!,
        weight: w,
        unit: unit,
        reps: r!,
      );
    } else {
      editor.updateSet(
        widget.dayIndex,
        widget.exerciseId,
        widget.set!.id,
        weight: w,
        unit: unit,
        reps: r!,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.s16,
        theme.spacing.s16,
        theme.spacing.s16,
        MediaQuery.viewInsetsOf(context).bottom + theme.spacing.s16,
      ),
      child: SingleChildScrollView(
        // Flutter: Column, mainAxis: start, crossAxis: stretch
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.set == null
                  ? AppStrings.batchAddSets
                  : AppStrings.editSets,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // Spacer: spacing.16 -> SizedBox(height: spacing.16)
            SizedBox(height: theme.spacing.s16),
            if (widget.set == null)
              PlanTextField(
                label: AppStrings.setCount,
                controller: count,
                fieldKey: const Key('set-count'),
                number: true,
              ),
            PlanTextField(
              label: AppStrings.weight,
              controller: weight,
              fieldKey: const Key('set-weight'),
              number: true,
            ),
            DropdownButtonFormField<WeightUnit>(
              initialValue: unit,
              isExpanded: true,
              decoration: skin.input(AppStrings.unitLabel),
              items: [
                for (final u in WeightUnit.values)
                  DropdownMenuItem(
                    value: u,
                    child: Text(
                      AppStrings.weightUnitLabels[u.code]!,
                      style: skin.title,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => unit = value!),
            ),
            PlanTextField(
              label: AppStrings.reps,
              controller: reps,
              fieldKey: const Key('set-reps'),
              number: true,
            ),
            if (invalid)
              Text(
                AppStrings.invalidNumber,
                style: skin.caption.copyWith(color: theme.colors.danger),
              ),
            ElevatedButton(
              key: const Key('set-save'),
              onPressed: _save,
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }
}
