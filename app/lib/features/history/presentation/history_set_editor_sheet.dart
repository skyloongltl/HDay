import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/history_skin.dart';
import '../../exercises/domain/exercise.dart';
import '../../workout/domain/workout_draft.dart';
import '../application/history_providers.dart';

final class HistorySetEditorSheet extends ConsumerStatefulWidget {
  const HistorySetEditorSheet({
    required this.sessionId,
    required this.set,
    super.key,
  });
  final String sessionId;
  final WorkoutSet set;
  static Future<void> show(
    BuildContext context, {
    required String sessionId,
    required WorkoutSet set,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppTheme.of(context).colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.of(context).radii.xl),
          ),
        ),
        isScrollControlled: true,
        useSafeArea: true,
        sheetAnimationStyle:
            const AnimationStyle(duration: HistorySkin.sheetDuration),
        builder: (_) => HistorySetEditorSheet(sessionId: sessionId, set: set),
      );
  @override
  ConsumerState<HistorySetEditorSheet> createState() =>
      _HistorySetEditorSheetState();
}

final class _HistorySetEditorSheetState
    extends ConsumerState<HistorySetEditorSheet> {
  late final weight = TextEditingController(
    text: widget.set.actualWeight == null
        ? ''
        : AppStrings.compactNumber(widget.set.actualWeight!),
  );
  late final reps =
      TextEditingController(text: widget.set.actualReps?.toString() ?? '');
  bool isSaving = false; // Flutter: setState
  bool hasFailed = false; // Flutter: setState
  bool isInvalid = false; // Flutter: setState
  bool get weighted =>
      widget.set.unit == WeightUnit.kg || widget.set.unit == WeightUnit.lb;
  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final enteredWeight =
        weight.text.trim().isEmpty ? null : double.tryParse(weight.text);
    final enteredReps = int.tryParse(reps.text);
    if (enteredReps == null ||
        enteredReps < 0 ||
        (weighted &&
            weight.text.trim().isNotEmpty &&
            (enteredWeight == null ||
                !enteredWeight.isFinite ||
                enteredWeight < 0))) {
      setState(() => isInvalid = true);
      return;
    }
    setState(() {
      isSaving = true;
      isInvalid = false;
    });
    final saved = await ref.read(historyControllerProvider.notifier).correctSet(
          widget.sessionId,
          widget.set.id,
          weight: weighted ? enteredWeight : widget.set.actualWeight,
          reps: enteredReps,
        );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        isSaving = false;
        hasFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // Animation: sheet translate from bottom 280ms; route controls animation.
    return PopScope(
      canPop: !isSaving,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(theme.spacing.s20),
          // Flutter: Column, mainAxis: start, crossAxis: stretch
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.correctHistorySet,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(AppStrings.correctionHint),
              // Spacer: spacing.16 -> SizedBox(height: spacing.16)
              SizedBox(height: theme.spacing.s16),
              Text(
                AppStrings.historyValue(
                  widget.set.plannedWeight,
                  widget.set.plannedReps,
                  widget.set.unit.code,
                ),
              ),
              if (weighted)
                TextField(
                  key: const ValueKey('history-actual-weight'),
                  controller: weight,
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppStrings.actualWeight,
                    suffixText:
                        AppStrings.weightUnitLabels[widget.set.unit.code],
                  ),
                ),
              TextField(
                key: const ValueKey('history-actual-reps'),
                controller: reps,
                enabled: !isSaving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: AppStrings.actualReps,
                ),
              ),
              if (isInvalid)
                Text(
                  AppStrings.invalidActualValues,
                  style: TextStyle(color: theme.colors.danger),
                ),
              if (hasFailed)
                Text(
                  AppStrings.historyWriteFailed,
                  style: TextStyle(color: theme.colors.danger),
                ),
              // Spacer: spacing.20 -> SizedBox(height: spacing.20)
              SizedBox(height: theme.spacing.s20),
              ElevatedButton(
                key: const ValueKey('history-correction-save'),
                onPressed: isSaving ? null : _save,
                child: Text(
                  isSaving
                      ? AppStrings.saving
                      : hasFailed
                          ? AppStrings.retry
                          : AppStrings.confirmEdit,
                ),
              ),
              TextButton(
                style: HistorySkin.button(theme),
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text(AppStrings.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
