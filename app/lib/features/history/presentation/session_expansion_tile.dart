import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/history_skin.dart';
import '../../workout/domain/workout_draft.dart';
import '../../workout/domain/workout_session.dart';
import '../application/history_providers.dart';
import 'history_set_editor_sheet.dart';

final class SessionExpansionTile extends ConsumerStatefulWidget {
  const SessionExpansionTile({
    required this.session,
    required this.index,
    required this.isExpanded,
    required this.onToggle,
    required this.onDelete,
    super.key,
  });
  final WorkoutSession session;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  @override
  ConsumerState<SessionExpansionTile> createState() =>
      _SessionExpansionTileState();
}

final class _SessionExpansionTileState
    extends ConsumerState<SessionExpansionTile>
    with SingleTickerProviderStateMixin {
  late final TextEditingController noteText =
      TextEditingController(text: widget.session.note);
  late final AnimationController expansion = AnimationController(
    vsync: this,
    duration: HistorySkin.expansionDuration,
    value: widget.isExpanded ? HistorySkin.one : HistorySkin.zero,
  );
  bool isSaving = false; // Flutter: setState
  bool noteFailed = false; // Flutter: setState
  @override
  void didUpdateWidget(covariant SessionExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded != widget.isExpanded) {
      widget.isExpanded ? expansion.forward() : expansion.reverse();
    }
  }

  @override
  void dispose() {
    noteText.dispose();
    expansion.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    setState(() => isSaving = true);
    final success = await ref
        .read(historyControllerProvider.notifier)
        .updateNote(widget.session.id, noteText.text);
    if (mounted) {
      setState(() {
        isSaving = false;
        noteFailed = !success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final session = widget.session;
    final saved = session.phase == WorkoutPhase.saved;
    final sets = session.exercises.expand((e) => e.sets);
    final count = sets.where((s) => s.status == SetStatus.completed).length;
    final sources = session.exercises
        .map((e) => e.sourcePlanName)
        .whereType<String>()
        .toSet();
    final busy =
        ref.watch(historyControllerProvider).valueOrNull?.isSaving ?? false;
    return DecoratedBox(
      key: ValueKey('session-${session.id}'),
      decoration: HistorySkin.card(theme),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.s14),
        // Flutter: Column, mainAxis: start, crossAxis: stretch
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sources.isEmpty ? AppStrings.freeWorkout : sources.join(' · '),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(AppStrings.historySessionLabel(widget.index + 1)),
            Text(
              AppStrings.historyTimeSpan(session.startedAt, session.endedAt),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              '${AppStrings.historyDuration(session.timer.accumulatedActiveSeconds)} · ${AppStrings.exerciseCompletion(count, sets.length)}',
              style: TextStyle(color: theme.colors.mintText),
            ),
            if (!saved)
              Text(
                AppStrings.unfinishedWorkout,
                style: TextStyle(color: HistorySkin.unfinishedText),
              ),
            // Flutter: Row, mainAxis: start, crossAxis: center
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: ValueKey('expand-session-${session.id}'),
                    style: HistorySkin.button(theme).copyWith(
                      backgroundColor: WidgetStatePropertyAll(
                        theme.colors.inputSurface,
                      ),
                    ),
                    onPressed: widget.onToggle,
                    // Flutter: Row, mainAxis: center, crossAxis: center
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            widget.isExpanded
                                ? AppStrings.collapseHistory
                                : AppStrings.expandHistory,
                          ),
                        ),
                        // Animation: explicit arrow rotation 200ms easeOut.
                        RotationTransition(
                          turns: Tween<double>(
                            begin: HistorySkin.zero,
                            end: HistorySkin.halfTurn,
                          ).animate(
                            CurvedAnimation(
                              parent: expansion,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: const Icon(Icons.expand_more),
                        ),
                      ],
                    ),
                  ),
                ),
                if (saved)
                  IconButton(
                    key: ValueKey('delete-session-${session.id}'),
                    tooltip: AppStrings.deleteHistory,
                    color: theme.colors.danger,
                    onPressed: busy ? null : widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            // Animation: explicit height expansion 200ms easeOut.
            SizeTransition(
              sizeFactor:
                  CurvedAnimation(parent: expansion, curve: Curves.easeOut),
              // Flutter: Column, mainAxis: start, crossAxis: stretch
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final exercise in session.exercises)
                    _exercise(exercise, saved),
                  if (saved) ...[
                    TextField(
                      key: ValueKey('history-note-${session.id}'),
                      controller: noteText,
                      enabled: !isSaving,
                      minLines: HistorySkin.noteLines,
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: AppStrings.workoutNote,
                      ),
                    ),
                    if (noteFailed)
                      Text(
                        AppStrings.historyWriteFailed,
                        style: TextStyle(color: theme.colors.danger),
                      ),
                    TextButton(
                      key: ValueKey('save-note-${session.id}'),
                      style: HistorySkin.button(theme),
                      onPressed: busy ? null : _saveNote,
                      child: Text(
                        isSaving
                            ? AppStrings.saving
                            : noteFailed
                                ? AppStrings.retry
                                : AppStrings.saveChanges,
                      ),
                    ),
                  ] else ...[
                    if (session.note.isNotEmpty) Text(session.note),
                    TextButton(
                      style: HistorySkin.button(theme),
                      onPressed: () =>
                          context.go(AppRoutes.forWorkoutSession(session)),
                      child: const Text(AppStrings.resumeWorkout),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exercise(WorkoutExercise exercise, bool saved) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.s8),
      // Flutter: Column, mainAxis: start, crossAxis: stretch
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: theme.colors.inputSurface,
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.s8),
              child: Text(
                exercise.nameSnapshot,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Text(
            exercise.sourcePlanId == null
                ? AppStrings.sourceTemporary
                : AppStrings.preparationSource(
                    exercise.sourcePlanName!,
                    exercise.sourceRevisionId!,
                    exercise.sourceDayNumber!,
                    exercise.sourceDayName!,
                  ),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (exercise.temporary) const Text(AppStrings.sourceTemporary),
          Text(
            AppStrings.exerciseSubtitle(
              exercise.categorySnapshot.code,
              exercise.equipmentSnapshot.code,
              exercise.unitSnapshot.code,
            ),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(
            AppStrings.targetRestSummary(exercise.targetRestSeconds),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          if (exercise.note.isNotEmpty) Text(exercise.note),
          for (final entry in exercise.sets.indexed)
            _set(entry.$2, entry.$1 + 1, saved),
        ],
      ),
    );
  }

  Widget _set(WorkoutSet set, int index, bool saved) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.s6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colors.outline,
              width: theme.borders.thin,
            ),
          ),
        ),
        // Flutter: Column, mainAxis: start, crossAxis: stretch
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Flutter: Row, mainAxis: start, crossAxis: center
            Row(
              children: [
                Icon(
                  set.status == SetStatus.completed
                      ? Icons.check_circle
                      : set.status == SetStatus.skipped
                          ? Icons.cancel_outlined
                          : Icons.radio_button_unchecked,
                  color: set.status == SetStatus.completed
                      ? theme.colors.mintText
                      : theme.colors.textSubtle,
                  size: theme.spacing.s16,
                ),
                // Spacer: spacing.6 -> SizedBox(width: spacing.6)
                SizedBox(width: theme.spacing.s6),
                Expanded(
                  child: Text(
                    '${AppStrings.setSummary(index)} · ${AppStrings.historySetState(set.status.name)}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (saved)
                  IconButton(
                    key: ValueKey('correct-${widget.session.id}-${set.id}'),
                    tooltip: AppStrings.correctHistorySet,
                    onPressed: () => HistorySetEditorSheet.show(
                      context,
                      sessionId: widget.session.id,
                      set: set,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            Text(
              '${AppStrings.plannedValues}  ${AppStrings.historyValue(set.plannedWeight, set.plannedReps, set.unit.code)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${AppStrings.actualValues}  ${AppStrings.historyValue(set.actualWeight, set.actualReps, set.unit.code)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              AppStrings.historyTimeSpan(
                set.startedAt,
                set.completedAt ?? set.skippedAt,
              ),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              AppStrings.historySetTiming(
                set.setDurationSeconds,
                set.preSetRestSeconds,
              ),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              set.temporary ? AppStrings.temporarySet : AppStrings.originalSet,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
