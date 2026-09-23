import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/domain/app_failure.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/plan_skin.dart';
import '../../../widgets/app_bar.dart';
import '../../exercises/presentation/exercise_picker_sheet.dart';
import '../application/plan_editor_controller.dart';
import '../application/plan_providers.dart';
import '../domain/plan_day.dart';
import 'plan_form_widgets.dart';
import 'plan_set_editor_sheet.dart';

// PAGE: PlanEditScreen
// ROUTE: /plan-edit/:planId
// FLUTTER WIDGETS: Scaffold, AppBar, horizontal ListView, TextField, ReorderableListView, BottomSheet
// STATE: selectedDayIndex(int Riverpod), showPicker(bool), name(TextEditingController), isSaving(bool Riverpod)
// ANIMATIONS: tab scroll 200ms easeOut; sheet slide 280ms; explicit content fade 200ms
// NAVIGATION: back -> PlanScreen; complete -> SQLite save then PlanScreen; picker -> draft add; card -> set sheet
class PlanEditScreen extends ConsumerWidget {
  const PlanEditScreen({required this.planId, super.key});
  final String planId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(planRepositoryProvider).when(
            data: (_) => _PlanDayLoader(planId: planId),
            loading: () => const Scaffold(body: PlanStatus()),
            error: (_, __) => Scaffold(
              body: PlanStatus(
                message: AppStrings.planLoadFailed,
                onRetry: () => ref.invalidate(planRepositoryProvider),
              ),
            ),
          );
}

class _PlanDayLoader extends ConsumerWidget {
  const _PlanDayLoader({required this.planId});
  final String planId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planEditorControllerProvider(planId));
    if (state.isLoading) return const Scaffold(body: PlanStatus());
    if (state.days.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.editPlan)),
        body: PlanStatus(
          message: AppStrings.planLoadFailed,
          onRetry: () => ref
              .read(planEditorControllerProvider(planId).notifier)
              .open(planId),
        ),
      );
    }
    return _PlanDayForm(planId: planId);
  }
}

class _PlanDayForm extends ConsumerStatefulWidget {
  const _PlanDayForm({required this.planId});
  final String planId;
  @override
  ConsumerState<_PlanDayForm> createState() => _PlanDayFormState();
}

class _PlanDayFormState extends ConsumerState<_PlanDayForm> {
  late final PlanDraft initialDraft;
  @override
  void initState() {
    super.initState();
    initialDraft = draft;
  }

  late final tabs = ScrollController(
    initialScrollOffset: draft.selectedDayIndex * PlanSkin.dayTabWidth,
  ); // Flutter: ScrollController
  bool showPicker = false; // Flutter: setState
  PlanEditorController get editor =>
      ref.read(planEditorControllerProvider(widget.planId).notifier);
  PlanDraft get draft => ref.read(planEditorControllerProvider(widget.planId));
  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!await editor.save(effectiveFrom: draft.startDate)) return;
    await ref.read(planControllerProvider.notifier).load();
    if (mounted) context.go(AppRoutes.plan);
  }

  Future<void> _back() async {
    if (draft.isDirty &&
        !await confirmPlanAction(
          context,
          title: AppStrings.discardDraft,
          message: AppStrings.discardDraftHint,
          action: AppStrings.discard,
        )) {
      return;
    }
    if (!mounted) return;
    editor.restoreDraft(initialDraft);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.plan);
    }
  }

  void _select(int index) {
    editor.selectDay(index);
    if (tabs.hasClients) {
      tabs.animateTo(
        min(index * PlanSkin.dayTabWidth, tabs.position.maxScrollExtent),
        duration: PlanSkin.dayScrollDuration,
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pick() async {
    final index = draft.selectedDayIndex;
    setState(() => showPicker = true);
    await ExercisePickerSheet.show(
      context,
      onSelected: (exercise) => editor.addExercise(index, exercise),
    );
    if (mounted) setState(() => showPicker = false);
  }

  Future<void> _rest(bool value) async {
    final index = draft.selectedDayIndex;
    if (value &&
        draft.days[index].exercises.isNotEmpty &&
        !await confirmPlanAction(
          context,
          title: AppStrings.contentsClearTitle,
          message: AppStrings.restClearHint,
        )) {
      return;
    }
    editor.setDayRest(index, value);
  }

  Future<void> _duplicatePlan() async {
    final success = await ref
        .read(planControllerProvider.notifier)
        .duplicate(widget.planId);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.duplicateSavedPlanSuccess)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.exerciseWriteFailed)),
      );
    }
  }

  Future<void> _chooseDay({bool copy = false}) async {
    final source = draft.selectedDayIndex;
    final theme = AppTheme.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colors.page,
      barrierColor:
          theme.colors.text.withValues(alpha: theme.opacities.overlay),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.radii.xl)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => PlanDayPickerSheet(
        days: draft.days,
        excludeIndex: copy ? source : null,
      ),
    );
    if (selected == null || !mounted) return;
    if (copy) {
      if (!await confirmPlanAction(
        context,
        title: AppStrings.copyDay,
        message: AppStrings.copyDayHint,
      )) {
        return;
      }
      editor.copyDay(source, selected);
    }
    _select(selected);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planEditorControllerProvider(widget.planId));
    final day = state.days[state.selectedDayIndex];
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    return PopScope(
      canPop: !state.isDirty && !state.isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.isSaving) _back();
      },
      child: SafeArea(
        child: Scaffold(
          key: const ValueKey('plan-edit-screen'),
          appBar: AppBar(
            toolbarHeight: theme.appBar.height,
            centerTitle: true,
            leading: CircularBackButton(
              onPressed: state.isSaving ? null : _back,
            ),
            title:
                Text(state.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              TextButton(
                key: const Key('plan-save'),
                style: skin.textButton,
                onPressed: state.isSaving ? null : _save,
                child: Text(
                  state.isSaving ? AppStrings.saving : AppStrings.done,
                ),
              ),
            ],
          ),
          // Flutter: Column, mainAxis: start, crossAxis: stretch
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: theme.colors.surface,
                child: SizedBox(
                  height: PlanSkin.dayTabHeight,
                  // Flutter: ListView (horizontal), mainAxis: start, crossAxis: center
                  child: ListView.builder(
                    key: const Key('day-tabs'),
                    controller: tabs,
                    scrollDirection: Axis.horizontal,
                    padding:
                        EdgeInsets.symmetric(horizontal: theme.spacing.s16),
                    itemExtent: PlanSkin.dayTabWidth,
                    itemCount: state.cycleLength,
                    itemBuilder: (_, index) => Padding(
                      padding: EdgeInsets.only(
                        right: theme.spacing.s6,
                        bottom: theme.spacing.s12,
                      ),
                      child: TextButton(
                        key: ValueKey('day-tab-${index + 1}'),
                        onPressed: () => _select(index),
                        style: skin.textButton.copyWith(
                          foregroundColor: WidgetStatePropertyAll(
                            index == state.selectedDayIndex
                                ? theme.colors.onHero
                                : theme.colors.textMuted,
                          ),
                          padding:
                              const WidgetStatePropertyAll(EdgeInsets.zero),
                        ),
                        child: Container(
                          height: PlanSkin.dayTabVisualHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: index == state.selectedDayIndex
                                ? theme.primaryAction
                                : theme.colors.inputSurface,
                            borderRadius:
                                BorderRadius.circular(theme.radii.full),
                          ),
                          child: Text(
                            AppStrings.dayLabel(index + 1),
                            style: skin.caption.copyWith(
                              color: index == state.selectedDayIndex
                                  ? theme.colors.onHero
                                  : theme.colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                // Flutter: ListView, mainAxis: start, crossAxis: stretch
                child: ListView(
                  key: const Key('day-content'),
                  padding: EdgeInsets.fromLTRB(
                    theme.spacing.s16,
                    theme.spacing.s14,
                    theme.spacing.s16,
                    theme.spacing.s16,
                  ),
                  children: [
                    if (state.failure != null)
                      PlanFailureTile(
                        message: state.failure?.code == FailureCode.conflict
                            ? AppStrings.revisionConflict
                            : AppStrings.exerciseWriteFailed,
                        onRetry: _save,
                      ),
                    if (state.failure?.code == FailureCode.conflict)
                      PlanDateTile(
                        label: AppStrings.effectiveDate,
                        date: state.startDate,
                        minimum: state.previous!.effectiveFrom.addDays(1),
                        onChanged: (date) =>
                            editor.updateBasics(startDate: date),
                      ),
                    // Flutter: Row, mainAxis: spaceBetween, crossAxis: center
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            key: const Key('day-heading'),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: theme.spacing.s8,
                            children: [
                              Text(
                                day.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (day.isRest)
                                Text(
                                  AppStrings.restDay,
                                  key: const Key('day-kind-inline'),
                                  style: skin.caption,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('day-jump'),
                          tooltip: AppStrings.jumpDay,
                          onPressed: _chooseDay,
                          icon: const Icon(Icons.search),
                        ),
                        PopupMenuButton<String>(
                          key: const Key('day-menu'),
                          tooltip: AppStrings.moreActions,
                          color: theme.colors.surface,
                          surfaceTintColor: Colors.transparent,
                          shape: skin.menuShape,
                          menuPadding: skin.menuPadding,
                          constraints: skin.menuConstraints,
                          onSelected: (value) async {
                            if (value == 'copy') _chooseDay(copy: true);
                            if (value == 'edit') {
                              context.push(AppRoutes.editPlan(widget.planId));
                            }
                            if (value == 'duplicate-plan') {
                              await _duplicatePlan();
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'copy',
                              height: PlanSkin.menuItemHeight,
                              child: Text(AppStrings.copyDay),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              height: PlanSkin.menuItemHeight,
                              child: Text(AppStrings.editPlan),
                            ),
                            const PopupMenuItem(
                              value: 'duplicate-plan',
                              height: PlanSkin.menuItemHeight,
                              child: Text(AppStrings.duplicatePlan),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (!day.isRest)
                      Text(
                        AppStrings.daySummary(
                          day.exercises.length,
                          day.exercises.fold(0, (n, e) => n + e.sets.length),
                        ),
                        style: skin.caption,
                      ),
                    _DayNameField(
                      key: ValueKey(day.id),
                      day: day,
                      onChanged: (name) =>
                          editor.renameDay(state.selectedDayIndex, name),
                    ),
                    // Flutter: Row, mainAxis: spaceBetween, crossAxis: center
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            day.isRest
                                ? AppStrings.restDay
                                : AppStrings.trainingDay,
                            style: skin.title,
                          ),
                        ),
                        PlanToggle(
                          key: const Key('day-rest'),
                          value: day.isRest,
                          onChanged: _rest,
                        ),
                        if (!day.isRest)
                          TextButton(
                            key: const Key('day-add-exercise'),
                            style: skin.compactAction,
                            onPressed: showPicker ? null : _pick,
                            child: Container(
                              key: const Key('day-add-exercise-visual'),
                              height: PlanSkin.compactActionHeight,
                              decoration: skin.compactActionVisual,
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.spacing.s12,
                              ),
                              child: Center(
                                child: Text(
                                  AppStrings.createExercise,
                                  style: skin.caption.copyWith(
                                    color: theme.colors.onHero,
                                    fontWeight: theme.typography.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Spacer: spacing.14 -> SizedBox(height: spacing.14)
                    SizedBox(height: theme.spacing.s14),
                    if (day.isRest)
                      PlanCard(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(theme.spacing.s20),
                            // Flutter: Column, mainAxis: center, crossAxis: center
                            child: Column(
                              children: [
                                Icon(
                                  Icons.bedtime_outlined,
                                  size: theme.spacing.s32,
                                  color: theme.colors.textSubtle,
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: theme.spacing.s12,
                                  ),
                                  child: Text(
                                    AppStrings.restHint,
                                    style: skin.title,
                                  ),
                                ),
                                TextButton(
                                  style: skin.pill,
                                  onPressed: () => _rest(false),
                                  child: const Text(AppStrings.toTrainingDay),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      if (day.exercises.isEmpty)
                        PlanCard(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(theme.spacing.s20),
                              child: Text(
                                AppStrings.noDayExercises,
                                textAlign: TextAlign.center,
                                style: skin.title,
                              ),
                            ),
                          ],
                        ),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: day.exercises.length,
                        onReorderItem: (oldIndex, newIndex) {
                          final ids = day.exercises.map((e) => e.id).toList();
                          final id = ids.removeAt(oldIndex);
                          ids.insert(
                            newIndex,
                            id,
                          );
                          editor.reorderExercises(state.selectedDayIndex, ids);
                        },
                        itemBuilder: (_, index) =>
                            _exerciseTile(day.exercises[index], index, day),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exerciseTile(PlanExercise exercise, int index, PlanDay day) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    final dayIndex = draft.selectedDayIndex;
    final firstSet = exercise.sets.isEmpty ? null : exercise.sets.first;
    return Container(
      key: ValueKey(exercise.id), decoration: skin.panel(compact: true),
      margin: EdgeInsets.only(bottom: theme.spacing.s6),
      // Flutter: Row, mainAxis: start, crossAxis: center
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: SizedBox(
                width: theme.spacing.s40,
                height: theme.minTapTarget,
                child: Icon(
                  Icons.drag_indicator,
                  color: theme.colors.textSubtle,
                  size: theme.typography.lg,
                ),
              ),
            ),
            Container(
              width: PlanSkin.numberSize,
              height: PlanSkin.numberSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colors.mintSurface,
                borderRadius: BorderRadius.circular(theme.radii.sm),
              ),
              child: Text(
                AppStrings.ordinal(index + 1),
                style: skin.caption.copyWith(
                  color: theme.colors.mintText,
                  fontWeight: theme.typography.heavy,
                ),
              ),
            ),
            Expanded(
              child: ListTile(
                key: ValueKey('day-exercise-${exercise.id}'),
                dense: true,
                minVerticalPadding: theme.spacing.s2,
                visualDensity: const VisualDensity(vertical: -4),
                contentPadding: EdgeInsets.only(left: theme.spacing.s8),
                title: Text(exercise.nameSnapshot, style: skin.title),
                subtitle: Text(
                  firstSet == null
                      ? AppStrings.setSummary(exercise.sets.length)
                      : AppStrings.planExerciseWeightSummary(
                          exercise.sets.length,
                          firstSet.plannedWeight,
                          firstSet.unit.code,
                        ),
                  style: skin.caption,
                ),
                onTap: () => PlanSetEditorSheet.show(
                  context,
                  planId: widget.planId,
                  dayIndex: dayIndex,
                  exerciseId: exercise.id,
                ),
              ),
            ),
            PopupMenuButton<String>(
              key: ValueKey('exercise-menu-${exercise.id}'),
              tooltip: AppStrings.moreActions,
              color: theme.colors.surface,
              surfaceTintColor: Colors.transparent,
              shape: skin.menuShape,
              menuPadding: skin.menuPadding,
              constraints: skin.menuConstraints,
              onSelected: (action) async {
                if (action == 'copy') {
                  editor.copyExercise(dayIndex, exercise.id);
                }
                if (action == 'delete' &&
                    await confirmPlanAction(
                      context,
                      title: AppStrings.removeExercise,
                      message: AppStrings.removeItemHint,
                      action: AppStrings.confirmDelete,
                    )) {
                  editor.deleteExercise(dayIndex, exercise.id);
                }
                if (action == 'up' || action == 'down') {
                  final ids = day.exercises.map((e) => e.id).toList();
                  ids.removeAt(index);
                  ids.insert(
                    action == 'up' ? index - 1 : index + 1,
                    exercise.id,
                  );
                  editor.reorderExercises(dayIndex, ids);
                }
              },
              itemBuilder: (_) => [
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
                if (index < day.exercises.length - 1)
                  const PopupMenuItem(
                    value: 'down',
                    height: PlanSkin.menuItemHeight,
                    child: Text(AppStrings.moveDown),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  height: PlanSkin.menuItemHeight,
                  child: Text(AppStrings.removeExercise),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayNameField extends StatefulWidget {
  const _DayNameField({required this.day, required this.onChanged, super.key});
  final PlanDay day;
  final ValueChanged<String> onChanged;
  @override
  State<_DayNameField> createState() => _DayNameFieldState();
}

class _DayNameFieldState extends State<_DayNameField> {
  late final name = TextEditingController(
    text: widget.day.name,
  ); // Flutter: TextEditingController
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlanTextField(
        label: AppStrings.dayName,
        controller: name,
        fieldKey: const Key('day-name'),
        onChanged: widget.onChanged,
      );
}

class PlanDayPickerSheet extends StatefulWidget {
  const PlanDayPickerSheet({required this.days, this.excludeIndex, super.key});
  final List<PlanDay> days;
  final int? excludeIndex;
  @override
  State<PlanDayPickerSheet> createState() => _PlanDayPickerSheetState();
}

class _PlanDayPickerSheetState extends State<PlanDayPickerSheet> {
  String searchQuery = ''; // Flutter: setState
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    final filtered = widget.days.indexed
        .where(
          (entry) =>
              entry.$1 != widget.excludeIndex &&
              (searchQuery.isEmpty ||
                  entry.$2.dayNumber.toString() == searchQuery ||
                  entry.$2.name
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase())),
        )
        .toList();
    return FractionallySizedBox(
      heightFactor: PlanSkin.searchSheetFraction,
      child: Material(
        key: const Key('day-picker-surface'),
        color: theme.colors.page,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            theme.spacing.s16,
            theme.spacing.s12,
            theme.spacing.s16,
            MediaQuery.viewInsetsOf(context).bottom,
          ),
          // Flutter: Column, mainAxis: start, crossAxis: stretch
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.jumpDay,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: theme.spacing.s4),
              TextField(
                key: const Key('day-search'),
                onChanged: (value) => setState(() => searchQuery = value),
                style: skin.title,
                decoration: skin.input(
                  AppStrings.daySearchHint,
                  prefix: const Icon(Icons.search),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(
                    key: const Key('day-result-divider'),
                    height: theme.borders.thin,
                    thickness: theme.borders.thin,
                    color: theme.colors.outline,
                  ),
                  itemBuilder: (_, index) {
                    final entry = filtered[index];
                    return ListTile(
                      key: ValueKey('day-result-${entry.$2.dayNumber}'),
                      dense: true,
                      minVerticalPadding: theme.spacing.s2,
                      visualDensity: const VisualDensity(vertical: -3),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.s4,
                      ),
                      title: Text(
                        '${AppStrings.dayLabel(entry.$2.dayNumber)} · ${entry.$2.name}',
                        style: skin.title,
                      ),
                      subtitle: Text(
                        entry.$2.isRest
                            ? AppStrings.restDay
                            : AppStrings.trainingDay,
                        style: skin.caption,
                      ),
                      onTap: () => Navigator.pop(context, entry.$1),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
