import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/domain/app_failure.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/plan_skin.dart';
import '../application/plan_editor_controller.dart';
import '../application/plan_providers.dart';
import '../domain/plan_revision.dart';
import 'plan_form_widgets.dart';

// PAGE: CreateEditPlanScreen
// ROUTE: /create-plan | /edit-plan/:planId
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, Card, TextField, SegmentedButton, Switch, DatePicker
// STATE: name/cycleLength/loopCount/priority(TextEditingController), execMode(PlanMode), enabled(bool),
// startDate/endDate(LocalDate in Riverpod), nameError(bool), effectiveDateChosen(bool), isSaving(bool)
// ANIMATIONS: conditional fields fade 200ms easeOut via explicit TweenAnimationBuilder
// NAVIGATION: committed save -> PlanScreen; cycle configuration -> save then PlanEditScreen; cancel -> pop
class CreateEditPlanScreen extends ConsumerWidget {
  const CreateEditPlanScreen({this.planId, super.key});
  final String? planId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(planRepositoryProvider).when(
            data: (_) => _PlanEditorLoader(planId: planId),
            loading: () => const Scaffold(body: PlanStatus()),
            error: (_, __) => Scaffold(
              body: PlanStatus(
                message: AppStrings.planLoadFailed,
                onRetry: () => ref.invalidate(planRepositoryProvider),
              ),
            ),
          );
}

class _PlanEditorLoader extends ConsumerWidget {
  const _PlanEditorLoader({this.planId});
  final String? planId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(planEditorControllerProvider(planId));
    if (draft.isLoading) return const Scaffold(body: PlanStatus());
    if (draft.days.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.editPlan)),
        body: PlanStatus(
          message: draft.failure?.code == FailureCode.notFound
              ? AppStrings.planMissing
              : AppStrings.planLoadFailed,
          onRetry: () => ref
              .read(planEditorControllerProvider(planId).notifier)
              .open(planId),
        ),
      );
    }
    return _PlanForm(planId: planId, initial: draft);
  }
}

class _PlanForm extends ConsumerStatefulWidget {
  const _PlanForm({required this.planId, required this.initial});
  final String? planId;
  final PlanDraft initial;
  @override
  ConsumerState<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<_PlanForm> {
  late PlanDraft initialDraft;
  @override
  void initState() {
    super.initState();
    initialDraft = widget.initial;
  }

  late final name = TextEditingController(
    text: widget.initial.name,
  ); // Flutter: TextEditingController
  late final cycleLength = TextEditingController(
    text: widget.initial.cycleLength.toString(),
  ); // Flutter: TextEditingController
  late final loopCount = TextEditingController(
    text: widget.initial.loopCount.toString(),
  ); // Flutter: TextEditingController
  late final priority = TextEditingController(
    text: widget.initial.priority.toString(),
  ); // Flutter: TextEditingController
  bool nameError = false; // Flutter: setState
  bool numberError = false; // Flutter: setState
  bool effectiveDateChosen = false; // Flutter: setState
  bool localDirty = false; // Flutter: setState
  bool retryDelete = false; // Flutter: setState
  String? formError; // Flutter: setState
  PlanEditorController get editor =>
      ref.read(planEditorControllerProvider(widget.planId).notifier);
  PlanDraft get draft => ref.read(planEditorControllerProvider(widget.planId));
  @override
  void dispose() {
    name.dispose();
    cycleLength.dispose();
    loopCount.dispose();
    priority.dispose();
    super.dispose();
  }

  Future<bool> _save({bool navigate = true}) async {
    final length = int.tryParse(cycleLength.text);
    final count = int.tryParse(loopCount.text);
    final rank = int.tryParse(priority.text);
    setState(() {
      retryDelete = false;
      nameError = name.text.trim().isEmpty;
      numberError = length == null ||
          length < 1 ||
          length > 365 ||
          rank == null ||
          (draft.execMode == PlanMode.cycles && (count == null || count < 1));
      formError = null;
    });
    if (nameError || numberError) return false;
    if (draft.previous != null &&
        length != draft.previous!.cycleDays &&
        !effectiveDateChosen) {
      setState(() => formError = AppStrings.chooseEffectiveDate);
      return false;
    }
    if (length! < draft.days.length &&
        draft.days.skip(length).any(
              (d) =>
                  d.exercises.isNotEmpty ||
                  d.name != AppStrings.dayLabel(d.dayNumber),
            )) {
      if (!await confirmPlanAction(
        context,
        title: AppStrings.contentsClearTitle,
        message: AppStrings.cycleShrinkHint,
      )) {
        return false;
      }
    }
    editor.updateBasics(
      name: name.text,
      cycleLength: length,
      loopCount: count != null && count > 0 ? count : null,
      priority: rank,
    );
    if (!await editor.save(effectiveFrom: draft.startDate)) return false;
    if (!mounted) return false;
    await ref.read(planControllerProvider.notifier).load();
    if (!mounted) return false;
    setState(() {
      localDirty = false;
      initialDraft = draft;
    });
    if (navigate) context.go(AppRoutes.plan);
    return true;
  }

  Future<void> _cancel() async {
    if ((draft.isDirty || localDirty) &&
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

  Future<void> _delete() async {
    if (!await confirmPlanAction(
      context,
      title: AppStrings.deletePlanTitle(name.text),
      message: AppStrings.deletePlanHint,
      action: AppStrings.confirmDelete,
    )) {
      return;
    }
    await _commitDelete();
  }

  Future<void> _commitDelete() async {
    setState(() {
      retryDelete = true;
      formError = null;
    });
    final success =
        await ref.read(planControllerProvider.notifier).delete(widget.planId!);
    if (!mounted) return;
    if (success) {
      context.go(AppRoutes.plan);
    } else {
      setState(() => formError = AppStrings.exerciseWriteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planEditorControllerProvider(widget.planId));
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    final changedLength = state.previous != null &&
        int.tryParse(cycleLength.text) != state.previous!.cycleDays;
    return PopScope(
      canPop: !state.isSaving && !state.isDirty && !localDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.isSaving) _cancel();
      },
      child: SafeArea(
        child: Scaffold(
          key: const ValueKey('create-plan-screen'),
          appBar: AppBar(
            toolbarHeight: theme.appBar.height,
            centerTitle: true,
            leadingWidth: theme.minTapTarget + theme.spacing.s16,
            leading: TextButton(
              style: skin.textButton,
              onPressed: state.isSaving ? null : _cancel,
              child: const Text(AppStrings.cancel),
            ),
            title: Text(
              widget.planId == null ? AppStrings.newPlan : AppStrings.editPlan,
            ),
            actions: [
              TextButton(
                key: const Key('plan-save'),
                style: skin.textButton,
                onPressed: state.isSaving ? null : _save,
                child:
                    Text(state.isSaving ? AppStrings.saving : AppStrings.save),
              ),
            ],
            shape: Border(
              bottom: BorderSide(
                color: theme.colors.outline,
                width: theme.borders.thin,
              ),
            ),
          ),
          // Flutter: Column, mainAxis: start, crossAxis: stretch
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                // Flutter: ListView, mainAxis: start, crossAxis: stretch
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacing.s16,
                    theme.spacing.s20,
                    theme.spacing.s16,
                    theme.spacing.s16,
                  ),
                  children: [
                    if (formError != null || state.failure != null)
                      PlanFailureTile(
                        message: formError ??
                            (state.failure?.code == FailureCode.conflict
                                ? AppStrings.revisionConflict
                                : state.failure?.code == FailureCode.validation
                                    ? AppStrings.invalidEffectiveDate
                                    : AppStrings.exerciseWriteFailed),
                        onRetry: retryDelete ? _commitDelete : _save,
                      ),
                    PlanCard(
                      key: const Key('plan-basic-card'),
                      padding: EdgeInsets.fromLTRB(
                        theme.spacing.s16,
                        theme.spacing.s16,
                        theme.spacing.s16,
                        theme.spacing.s8,
                      ),
                      title: AppStrings.basicInfo,
                      children: [
                        PlanTextField(
                          label: AppStrings.planName,
                          controller: name,
                          fieldKey: const Key('plan-name'),
                          hint: AppStrings.planNameHint,
                          error: nameError ? AppStrings.planNameRequired : null,
                          onChanged: (value) {
                            editor.updateBasics(name: value);
                            setState(() => nameError = false);
                          },
                        ),
                        PlanTextField(
                          label: AppStrings.cycleLength,
                          controller: cycleLength,
                          fieldKey: const Key('plan-cycle-length'),
                          number: true,
                          error:
                              numberError ? AppStrings.cycleLengthError : null,
                          onChanged: (_) => setState(() {
                            localDirty = true;
                            effectiveDateChosen = false;
                          }),
                        ),
                        Text(
                          AppStrings.generatedDays(
                            int.tryParse(cycleLength.text) ?? state.cycleLength,
                          ),
                          style: skin.caption,
                        ),
                        ListTile(
                          dense: true,
                          minVerticalPadding: theme.spacing.s2,
                          contentPadding: EdgeInsets.zero,
                          title: Text(AppStrings.enablePlan, style: skin.title),
                          subtitle: Text(
                            AppStrings.enablePlanHint,
                            style: skin.caption,
                          ),
                          trailing: PlanToggle(
                            value: state.enabled,
                            onChanged: (value) =>
                                editor.updateBasics(enabled: value),
                          ),
                        ),
                      ],
                    ),
                    PlanCard(
                      key: const Key('plan-execution-card'),
                      padding: EdgeInsets.all(theme.spacing.s12),
                      title: AppStrings.executionMode,
                      children: [
                        _modes(state),
                        PlanDateTile(
                          label: widget.planId == null
                              ? AppStrings.startDate
                              : AppStrings.effectiveDate,
                          date: state.startDate,
                          minimum: state.previous?.effectiveFrom,
                          fieldKey: const Key('plan-effective-date'),
                          onChanged: (date) {
                            editor.updateBasics(startDate: date);
                            setState(() => effectiveDateChosen = true);
                          },
                        ),
                        if (widget.planId != null)
                          Padding(
                            padding: EdgeInsets.only(bottom: theme.spacing.s12),
                            child: Text(
                              changedLength
                                  ? AppStrings.cycleResetHint
                                  : AppStrings.cycleKeepHint,
                              style: skin.caption.copyWith(
                                color: changedLength
                                    ? theme.primaryAction
                                    : theme.colors.textMuted,
                              ),
                            ),
                          ),
                        _modeFields(state),
                      ],
                    ),
                    PlanCard(
                      children: [
                        PlanTextField(
                          label: AppStrings.priority,
                          controller: priority,
                          fieldKey: const Key('plan-priority'),
                          number: true,
                          onChanged: (_) => setState(() => localDirty = true),
                        ),
                        Text(AppStrings.priorityHint, style: skin.caption),
                      ],
                    ),
                    if (widget.planId != null)
                      PlanCard(
                        title: AppStrings.cycleConfig,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              AppStrings.generatedDays(state.cycleLength),
                              style: skin.title,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              if (await _save(navigate: false) &&
                                  context.mounted) {
                                context
                                    .push(AppRoutes.planEdit(widget.planId!));
                              }
                            },
                          ),
                          // Flutter: Wrap, mainAxis: start, crossAxis: center
                          Wrap(
                            spacing: theme.spacing.s6,
                            children: [
                              for (var i = 0;
                                  i < state.cycleLength &&
                                      i < PlanSkin.previewDayLimit;
                                  i++)
                                Chip(
                                  label: Text(
                                    AppStrings.dayLabel(i + 1),
                                    style: skin.caption,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colors.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colors.outline,
                      width: theme.borders.thin,
                    ),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.s16,
                  theme.spacing.s12,
                  theme.spacing.s16,
                  theme.spacing.s20,
                ),
                // Flutter: Column, mainAxis: start, crossAxis: stretch
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      key: const Key('plan-primary-save'),
                      onPressed: state.isSaving ? null : _save,
                      child: Text(
                        widget.planId == null
                            ? AppStrings.createPlanShort
                            : AppStrings.saveChanges,
                      ),
                    ),
                    if (widget.planId != null)
                      TextButton(
                        style: skin.textButton.copyWith(
                          foregroundColor:
                              WidgetStatePropertyAll(theme.colors.danger),
                        ),
                        onPressed: state.isSaving ? null : _delete,
                        child: const Text(AppStrings.deletePlan),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modes(PlanDraft state) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.inputSurface,
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      padding: EdgeInsets.all(theme.spacing.s4),
      // Flutter: Row, mainAxis: start, crossAxis: center
      child: Row(
        children: [
          for (final mode in PlanMode.values)
            Expanded(
              child: TextButton(
                key: ValueKey('plan-mode-${mode.name}'),
                style: skin.textButton.copyWith(
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                  backgroundColor: WidgetStatePropertyAll(
                    state.execMode == mode
                        ? theme.colors.surface
                        : theme.colors.inputSurface,
                  ),
                  foregroundColor: WidgetStatePropertyAll(
                    state.execMode == mode
                        ? theme.colors.text
                        : theme.colors.textMuted,
                  ),
                  textStyle: WidgetStatePropertyAll(skin.caption),
                ),
                onPressed: () => editor.updateBasics(execMode: mode),
                child: Text(
                  switch (mode) {
                    PlanMode.infinite => AppStrings.infiniteMode,
                    PlanMode.cycles => AppStrings.cyclesMode,
                    PlanMode.dateRange => AppStrings.rangeMode
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeFields(PlanDraft state) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    final length = int.tryParse(cycleLength.text);
    final count = int.tryParse(loopCount.text);
    final preview = state.copyWith(
      cycleLength: length != null && length > 0 && length <= 365
          ? length
          : state.cycleLength,
      loopCount: count != null && count > 0 ? count : state.loopCount,
    );
    // Animation: explicit fade 0 -> 1, 200ms easeOut on conditional controls.
    return TweenAnimationBuilder<double>(
      key: ValueKey(state.execMode),
      tween: Tween(begin: PlanSkin.collapsed, end: PlanSkin.expanded),
      duration: PlanSkin.fieldFadeDuration,
      curve: Curves.easeOut,
      builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
      child: switch (state.execMode) {
        PlanMode.infinite => _summaryPanel(
            key: const Key('plan-infinite-summary'),
            children: [Text(AppStrings.infiniteHint, style: skin.caption)],
          ),
        // Flutter: Column, mainAxis: start, crossAxis: stretch
        PlanMode.cycles => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlanTextField(
                label: AppStrings.loopCount,
                controller: loopCount,
                fieldKey: const Key('plan-loop-count'),
                number: true,
                onChanged: (_) => setState(() => localDirty = true),
              ),
              _summaryPanel(
                key: const Key('plan-cycles-summary'),
                children: [
                  _summaryRow(
                    label: AppStrings.computedEnd,
                    value: preview.computedEndDate!.iso8601,
                  ),
                ],
              ),
            ],
          ),
        // Flutter: Column, mainAxis: start, crossAxis: stretch
        PlanMode.dateRange => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlanDateTile(
                label: AppStrings.endDate,
                date: state.endDate,
                minimum: state.startDate,
                fieldKey: const Key('plan-end-date'),
                onChanged: (date) => editor.updateBasics(endDate: date),
              ),
              _summaryPanel(
                key: const Key('plan-range-summary'),
                children: [
                  _summaryRow(
                    label: AppStrings.completeCycles,
                    value: AppStrings.cycleCountValue(
                      preview.rangeSummary.$1,
                    ),
                  ),
                  // Spacer: spacing.4 -> SizedBox(height: spacing.4)
                  SizedBox(height: theme.spacing.s4),
                  _summaryRow(
                    label: AppStrings.remainingDays,
                    value: AppStrings.dayCountValue(
                      preview.rangeSummary.$2,
                    ),
                  ),
                ],
              ),
            ],
          ),
      },
    );
  }

  Widget _summaryPanel({required Key key, required List<Widget> children}) {
    final theme = AppTheme.of(context);
    return Container(
      key: key,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.s14,
        vertical: theme.spacing.s10,
      ),
      decoration: PlanSkin(theme).summaryPanel,
      // Flutter: Column, mainAxis: start, crossAxis: stretch
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _summaryRow({required String label, required String value}) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    // Flutter: Row, mainAxis: spaceBetween, crossAxis: center
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: skin.caption)),
        // Spacer: spacing.12 -> SizedBox(width: spacing.12)
        SizedBox(width: theme.spacing.s12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: skin.title.copyWith(fontWeight: theme.typography.semibold),
          ),
        ),
      ],
    );
  }
}
