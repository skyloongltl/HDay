import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/domain/app_failure.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/exercise_skin.dart';
import '../application/exercise_controller.dart';
import '../application/exercise_providers.dart';
import '../domain/exercise.dart';
import 'exercise_filter_chips.dart';

// PAGE: ExerciseCreateEditScreen
// ROUTE: /exercise-create | /exercise-edit/:exerciseId
// FLUTTER WIDGETS: Scaffold, AppBar, TextField, Wrap, ListView, AlertDialog
// STATE: name/notes(TextEditingController), category(ExerciseCategory), equipment(ExerciseEquipment),
// unit(WeightUnit), isEditing(bool derived), nameError(bool), showDeleteConfirm(bool), failure(AppFailure?)
// ANIMATIONS: implicit chip background 150ms easeOut; delete overlay fade/scale .7 -> 1 250ms easeOutBack
// NAVIGATION: committed save -> pop or library; confirmed committed delete -> library
final class ExerciseCreateEditScreen extends ConsumerWidget {
  const ExerciseCreateEditScreen({this.exerciseId, super.key});
  final String? exerciseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exerciseId == null) return const _ExerciseForm();
    return ref.watch(exerciseEditorSourceProvider(exerciseId!)).when(
          skipLoadingOnRefresh: false,
          data: (exercise) => exercise == null
              ? _EditorStatus(
                  message: AppStrings.exerciseDeleted,
                  onRetry: () => context.go(AppRoutes.exercises),
                )
              : _ExerciseForm(key: ValueKey(exercise.id), exercise: exercise),
          loading: () => const _EditorStatus(),
          error: (_, __) => _EditorStatus(
            message: AppStrings.exerciseLoadFailed,
            onRetry: () =>
                ref.invalidate(exerciseEditorSourceProvider(exerciseId!)),
          ),
        );
  }
}

final class _EditorStatus extends StatelessWidget {
  const _EditorStatus({this.message, this.onRetry});
  final String? message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(AppStrings.editExercise)),
        body: Center(
          child: message == null
              ? const CircularProgressIndicator()
              // Flutter: Column, mainAxis: start, crossAxis: center
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message!),
                    TextButton(
                      onPressed: onRetry,
                      child: const Text(AppStrings.retry),
                    ),
                  ],
                ),
        ),
      );
}

final class _ExerciseForm extends ConsumerStatefulWidget {
  const _ExerciseForm({this.exercise, super.key});
  final Exercise? exercise;
  @override
  ConsumerState<_ExerciseForm> createState() => _ExerciseFormState();
}

final class _ExerciseFormState extends ConsumerState<_ExerciseForm> {
  late final FocusNode nameFocus = FocusNode();
  late final name = TextEditingController(
    text: widget.exercise?.name ?? '',
  ); // Flutter: TextEditingController
  late final notes = TextEditingController(
    text: widget.exercise?.note ?? '',
  ); // Flutter: TextEditingController
  late ExerciseCategory category =
      widget.exercise?.category ?? ExerciseCategory.chest; // Flutter: setState
  late ExerciseEquipment equipment = widget.exercise?.equipment ??
      ExerciseEquipment.barbell; // Flutter: setState
  late WeightUnit unit =
      widget.exercise?.defaultUnit ?? WeightUnit.kg; // Flutter: setState
  late final String exerciseId = widget.exercise?.id ?? newExerciseId();
  bool nameError = false; // Flutter: setState
  bool showDeleteConfirm = false; // Flutter: setState
  AppFailure? failure; // Flutter: setState
  bool _retryDelete = false; // Flutter: setState
  bool get isEditing => widget.exercise != null;
  @override
  void initState() {
    super.initState();
    if (!isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          nameFocus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    nameFocus.dispose();
    name.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      setState(() => nameError = true);
      return;
    }
    setState(() {
      failure = null;
      _retryDelete = false;
    });
    final now = ref.read(clockProvider).nowUtc();
    await ref.read(exerciseControllerProvider.notifier).save(
          Exercise(
            id: exerciseId,
            name: name.text,
            category: category,
            equipment: equipment,
            defaultUnit: unit,
            note: notes.text,
            createdAt: widget.exercise?.createdAt ?? now,
            updatedAt: now,
          ),
        );
    if (!mounted) return;
    final error = ref.read(exerciseControllerProvider).valueOrNull?.failure;
    if (error != null) {
      setState(() => failure = error);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.exercises);
    }
  }

  Future<void> _delete() async {
    setState(() {
      failure = null;
      _retryDelete = true;
    });
    await ref.read(exerciseControllerProvider.notifier).delete(exerciseId);
    if (!mounted) return;
    final error = ref.read(exerciseControllerProvider).valueOrNull?.failure;
    if (error != null) {
      setState(() => failure = error);
      return;
    }
    context.go(AppRoutes.exercises);
  }

  Future<void> _confirmDelete() async {
    setState(() => showDeleteConfirm = true);
    final theme = AppTheme.of(context);
    // Animation: explicit overlay fade and scale-pop .7 -> 1, 250ms easeOutBack.
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierColor:
          theme.colors.text.withValues(alpha: theme.opacities.overlay),
      transitionDuration: ExerciseSkin.dialogDuration,
      pageBuilder: (context, _, __) => AlertDialog(
        backgroundColor: theme.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radii.xl),
        ),
        title: Text(AppStrings.deleteExerciseTitle(name.text)),
        titleTextStyle: Theme.of(context).textTheme.titleMedium,
        content: const Text(AppStrings.deleteExerciseExplanation),
        contentTextStyle: ExerciseSkin(theme).caption,
        actions: [
          TextButton(
            style: ExerciseSkin(theme).textButton,
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            style: ExerciseSkin(theme).textButton.copyWith(
                  backgroundColor: WidgetStatePropertyAll(theme.colors.danger),
                  foregroundColor: WidgetStatePropertyAll(theme.colors.onHero),
                ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.confirmDelete),
          ),
        ],
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(
            begin: ExerciseSkin.dialogStartScale,
            end: ExerciseSkin.restingScale,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
          ),
          child: child,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => showDeleteConfirm = false);
    if (confirmed ?? false) await _delete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = ExerciseSkin(theme);
    final isSaving =
        ref.watch(exerciseControllerProvider).valueOrNull?.isSaving ?? false;
    return SafeArea(
      child: Scaffold(
        key: const ValueKey('exercise-edit-screen'),
        appBar: AppBar(
          toolbarHeight: theme.appBar.height,
          centerTitle: true,
          title: Text(
            isEditing ? AppStrings.editExercise : AppStrings.newExercise,
          ),
          leading: IconButton(
            tooltip: AppStrings.back,
            icon: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.iconSurface,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.s6),
                child: Icon(Icons.chevron_left, size: theme.typography.xl),
              ),
            ),
            onPressed: isSaving
                ? null
                : () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(AppRoutes.exercises);
                    }
                  },
          ),
          actions: isEditing
              ? [
                  TextButton(
                    key: const ValueKey('exercise-save'),
                    style: skin.textButton,
                    onPressed: isSaving ? null : _save,
                    child: Text(
                      isSaving
                          ? AppStrings.saving
                          : isEditing
                              ? AppStrings.save
                              : AppStrings.add,
                    ),
                  ),
                ]
              : const [],
          shape: Border(
            bottom: BorderSide(
              color: theme.appBar.outline,
              width: theme.borders.thin,
            ),
          ),
        ),
        // Flutter: ListView, mainAxis: start, crossAxis: stretch
        body: ListView(
          padding: EdgeInsets.all(theme.spacing.s16),
          children: [
            if (failure != null) _failure(),
            _field(
              AppStrings.exerciseNameLabel,
              TextField(
                key: const ValueKey('exercise-name'),
                controller: name,
                focusNode: nameFocus,
                style: skin.title.copyWith(fontSize: theme.typography.md),
                onChanged: (_) => setState(() => nameError = false),
                decoration: skin.input(AppStrings.exerciseNameHint).copyWith(
                      contentPadding: EdgeInsets.symmetric(
                        vertical: theme.spacing.s4,
                      ),
                      errorText:
                          nameError ? AppStrings.exerciseNameRequired : null,
                    ),
              ),
              error: nameError,
            ),
            _field(
              AppStrings.categoryLabel,
              ExerciseFilterChips(
                options: AppStrings.exerciseCategoryLabels,
                value: category.code,
                keyPrefix: 'category',
                onChanged: (value) => setState(
                  () => category = ExerciseCategory.fromCode(value),
                ),
              ),
            ),
            _field(
              AppStrings.equipmentLabel,
              ExerciseFilterChips(
                options: AppStrings.exerciseEquipmentLabels,
                value: equipment.code,
                keyPrefix: 'equipment',
                onChanged: (value) => setState(
                  () => equipment = ExerciseEquipment.fromCode(value),
                ),
              ),
            ),
            _field(AppStrings.unitLabel, _units()),
            _field(
              AppStrings.notesLabel,
              TextField(
                key: const ValueKey('exercise-notes'),
                controller: notes,
                minLines: ExerciseSkin.notesLines,
                maxLines: null,
                decoration: skin.input(AppStrings.notesHint),
                style:
                    skin.title.copyWith(fontWeight: theme.typography.regular),
              ),
            ),
            _preview(),
            KeyedSubtree(
              key: isEditing ? null : const ValueKey('exercise-save'),
              child: ElevatedButton(
                key: const ValueKey('exercise-primary-save'),
                onPressed: isSaving ? null : _save,
                child: Text(
                  isEditing
                      ? AppStrings.saveChanges
                      : AppStrings.createExercise,
                ),
              ),
            ),
            if (isEditing)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.s12),
                child: TextButton(
                  key: const ValueKey('exercise-delete'),
                  onPressed: isSaving ? null : _confirmDelete,
                  style: skin.textButton.copyWith(
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(theme.radii.button),
                      ),
                    ),
                    backgroundColor:
                        WidgetStatePropertyAll(theme.colors.dangerSurface),
                    foregroundColor:
                        WidgetStatePropertyAll(theme.colors.danger),
                  ),
                  child: const Text(AppStrings.deleteExercise),
                ),
              ),
            // Spacer: spacing.16 -> SizedBox(height: spacing.16)
            SizedBox(height: theme.spacing.s16),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, Widget child, {bool error = false}) {
    final theme = AppTheme.of(context);
    final skin = ExerciseSkin(theme);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.s12),
      child: DecoratedBox(
        decoration: skin.panel(error: error),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.s12,
            vertical: theme.spacing.s8,
          ),
          // Flutter: Column, mainAxis: start, crossAxis: stretch
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: skin.label),
              // Spacer: spacing.8 -> SizedBox(height: spacing.8)
              SizedBox(height: theme.spacing.s6), child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _units() {
    final theme = AppTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.inputSurface,
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.s4,
          vertical: theme.spacing.s2,
        ),
        // Flutter: Row, mainAxis: start, crossAxis: center
        child: Row(
          children: WeightUnit.values
              .map(
                (value) => Expanded(
                  child: TextButton(
                    key: ValueKey('unit-${value.code}'),
                    onPressed: () => setState(() => unit = value),
                    style: ExerciseSkin(theme).textButton.copyWith(
                          minimumSize: WidgetStatePropertyAll(
                            Size(theme.spacing.s40, 34),
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(
                              horizontal: theme.spacing.s4,
                            ),
                          ),
                          backgroundColor: WidgetStatePropertyAll(
                            unit == value
                                ? theme.colors.surface
                                : theme.colors.inputSurface,
                          ),
                          foregroundColor: WidgetStatePropertyAll(
                            unit == value
                                ? theme.colors.text
                                : theme.colors.textMuted,
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                theme.radii.sm,
                              ),
                            ),
                          ),
                        ),
                    child: Text(AppStrings.weightUnitLabels[value.code]!),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _preview() {
    final theme = AppTheme.of(context);
    final skin = ExerciseSkin(theme);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.s20),
      child: DecoratedBox(
        decoration: skin.panel(color: theme.colors.mintSurface, compact: true),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.s14,
            vertical: theme.spacing.s10,
          ),
          // Flutter: Row, mainAxis: start, crossAxis: center
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colors.mint,
                  borderRadius: BorderRadius.circular(theme.radii.sm),
                ),
                child: SizedBox.square(
                  dimension: ExerciseSkin.avatarSize,
                  child: Center(
                    child: Text(
                      name.text.isEmpty
                          ? AppStrings.previewInitial
                          : name.text.characters.first,
                      style: skin.title.copyWith(
                        color: theme.colors.onHero,
                        fontWeight: theme.typography.heavy,
                      ),
                    ),
                  ),
                ),
              ),
              // Spacer: spacing.12 -> SizedBox(width: spacing.12)
              SizedBox(width: theme.spacing.s12),
              Expanded(
                // Flutter: Column, mainAxis: start, crossAxis: start
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.text.isEmpty
                          ? AppStrings.exercisePreview
                          : name.text,
                      style: skin.title,
                    ),
                    Text(
                      AppStrings.exerciseSubtitle(
                        category.code,
                        equipment.code,
                        unit.code,
                      ),
                      style: skin.caption,
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

  Widget _failure() {
    final theme = AppTheme.of(context);
    final message = failure!.code == FailureCode.duplicate
        ? AppStrings.duplicateExerciseName
        : _retryDelete
            ? AppStrings.exerciseDeleteFailed
            : AppStrings.exerciseWriteFailed;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.s12),
      // Flutter: Column, mainAxis: start, crossAxis: center
      child: Column(
        children: [
          Text(message, style: TextStyle(color: theme.colors.danger)),
          TextButton(
            onPressed: _retryDelete ? _confirmDelete : _save,
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}
