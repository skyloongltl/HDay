import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../domain/workout_draft.dart';

typedef UpdateDraftSet = void Function(String setId, double? weight, int? reps);

final class WorkoutDraftCard extends StatelessWidget {
  const WorkoutDraftCard({
    required this.exercise,
    required this.onRemove,
    required this.onAddSet,
    required this.onDeleteSet,
    required this.onUpdateSet,
    required this.canMoveExerciseUp,
    required this.canMoveExerciseDown,
    required this.onMoveExerciseUp,
    required this.onMoveExerciseDown,
    required this.onMoveSetUp,
    required this.onMoveSetDown,
    super.key,
  });
  final WorkoutExercise exercise;
  final VoidCallback onRemove;
  final VoidCallback onAddSet;
  final ValueChanged<String> onDeleteSet;
  final UpdateDraftSet onUpdateSet;
  final bool canMoveExerciseUp;
  final bool canMoveExerciseDown;
  final VoidCallback onMoveExerciseUp;
  final VoidCallback onMoveExerciseDown;
  final ValueChanged<String> onMoveSetUp;
  final ValueChanged<String> onMoveSetDown;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppCard(
      padding: EdgeInsets.all(theme.spacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.nameSnapshot,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                constraints: BoxConstraints.tightFor(
                  width: theme.spacing.s48,
                  height: theme.spacing.s48,
                ),
                tooltip: AppStrings.moveExerciseUp,
                onPressed: canMoveExerciseUp ? onMoveExerciseUp : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                constraints: BoxConstraints.tightFor(
                  width: theme.spacing.s48,
                  height: theme.spacing.s48,
                ),
                tooltip: AppStrings.moveExerciseDown,
                onPressed: canMoveExerciseDown ? onMoveExerciseDown : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                constraints: BoxConstraints.tightFor(
                  width: theme.spacing.s48,
                  height: theme.spacing.s48,
                ),
                tooltip: AppStrings.removeExerciseAction,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Text(
            exercise.sourcePlanName == null
                ? AppStrings.sourceTemporary
                : AppStrings.preparationSource(
                    exercise.sourcePlanName!,
                    exercise.sourceRevisionId!,
                    exercise.sourceDayNumber!,
                    exercise.sourceDayName!,
                  ),
          ),
          Text(
            '${AppStrings.plannedRest} ${exercise.targetRestSeconds}${AppStrings.secondsSuffix}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          SizedBox(height: theme.spacing.s8),
          for (var index = 0; index < exercise.sets.length; index++)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.s4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('${index + 1}'),
                      SizedBox(width: theme.spacing.s8),
                      Expanded(
                        child: TextFormField(
                          key:
                              ValueKey('set-weight-${exercise.sets[index].id}'),
                          initialValue: '${exercise.sets[index].plannedWeight}',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppStrings.weight,
                            suffixText: exercise.sets[index].unit.code,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            final parsed = double.tryParse(value ?? '');
                            return parsed != null &&
                                    parsed.isFinite &&
                                    parsed >= 0
                                ? null
                                : AppStrings.invalidWeight;
                          },
                          onChanged: (value) {
                            final parsed = double.tryParse(value);
                            if (parsed != null &&
                                parsed.isFinite &&
                                parsed >= 0) {
                              onUpdateSet(
                                exercise.sets[index].id,
                                parsed,
                                null,
                              );
                            }
                          },
                        ),
                      ),
                      SizedBox(width: theme.spacing.s8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('set-reps-${exercise.sets[index].id}'),
                          initialValue: '${exercise.sets[index].plannedReps}',
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: AppStrings.reps),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            final parsed = int.tryParse(value ?? '');
                            return parsed != null && parsed > 0
                                ? null
                                : AppStrings.invalidReps;
                          },
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null && parsed > 0) {
                              onUpdateSet(
                                exercise.sets[index].id,
                                null,
                                parsed,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        constraints: BoxConstraints.tightFor(
                          width: theme.spacing.s48,
                          height: theme.spacing.s48,
                        ),
                        tooltip: AppStrings.moveSetUp,
                        onPressed: index == 0
                            ? null
                            : () => onMoveSetUp(exercise.sets[index].id),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      IconButton(
                        constraints: BoxConstraints.tightFor(
                          width: theme.spacing.s48,
                          height: theme.spacing.s48,
                        ),
                        tooltip: AppStrings.moveSetDown,
                        onPressed: index == exercise.sets.length - 1
                            ? null
                            : () => onMoveSetDown(exercise.sets[index].id),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      IconButton(
                        constraints: BoxConstraints.tightFor(
                          width: theme.spacing.s48,
                          height: theme.spacing.s48,
                        ),
                        tooltip: AppStrings.removeSetAction,
                        onPressed: exercise.sets.length == 1
                            ? null
                            : () => onDeleteSet(exercise.sets[index].id),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: Size.fromHeight(theme.spacing.s48),
            ),
            onPressed: onAddSet,
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.addSet),
          ),
        ],
      ),
    );
  }
}
