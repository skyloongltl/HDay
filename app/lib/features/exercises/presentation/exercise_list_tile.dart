import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/exercise_skin.dart';
import '../../history/application/history_providers.dart';
import '../domain/exercise.dart';

final class ExerciseListTile extends StatefulWidget {
  const ExerciseListTile({
    required this.exercise,
    required this.onTap,
    this.isSelected = false,
    this.isPicker = false,
    this.isRecent = false,
    super.key,
  });
  final Exercise exercise;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isPicker;
  final bool isRecent;
  @override
  State<ExerciseListTile> createState() => _ExerciseListTileState();
}

final class _ExerciseListTileState extends State<ExerciseListTile> {
  bool pressed = false; // Flutter: setState
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = ExerciseSkin(theme);
    final exercise = widget.exercise;
    // Animation: implicit scale .98 on press, 100ms easeOut; Figma AnimatedScale.
    return AnimatedScale(
      scale: pressed ? ExerciseSkin.pressedScale : ExerciseSkin.restingScale,
      duration: theme.motion.fast,
      curve: theme.motion.curve,
      child: Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.s6),
        child: Material(
          color: theme.appCard.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radii.md),
            side: BorderSide(
              color: theme.appCard.outline,
              width: theme.borders.thin,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(theme.radii.md),
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => pressed = value),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: theme.minTapTarget),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.s12,
                  vertical: theme.spacing.s8,
                ),
                // Flutter: Row, mainAxis: start, crossAxis: center
                // Flutter: Row, mainAxis: start, crossAxis: center
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colors.mintSurface,
                        borderRadius: BorderRadius.circular(theme.radii.sm),
                      ),
                      child: SizedBox.square(
                        dimension: ExerciseSkin.avatarSize,
                        child: Center(
                          child: Icon(
                            Icons.fitness_center,
                            size: theme.typography.lg,
                            color: theme.colors.mintText,
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
                          Text(exercise.name, style: skin.title),
                          Text(
                            AppStrings.exerciseSubtitle(
                              exercise.category.code,
                              exercise.equipment.code,
                              exercise.defaultUnit.code,
                            ),
                            style: skin.caption,
                          ),
                          if (exercise.note.isNotEmpty)
                            Text(
                              exercise.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: skin.caption,
                            ),
                        ],
                      ),
                    ),
                    // Spacer: spacing.8 -> SizedBox(width: spacing.8)
                    SizedBox(width: theme.spacing.s8),
                    if (widget.isSelected)
                      Text(AppStrings.alreadyAdded, style: skin.caption)
                    else if (widget.isRecent)
                      Consumer(
                        builder: (context, WidgetRef ref, _) {
                          final summary = ref.watch(
                            exerciseHistorySummaryProvider(exercise.id),
                          );
                          final records =
                              summary.valueOrNull?.records ?? const [];
                          final latest = records.isEmpty ? null : records.first;
                          return Text(
                            latest == null
                                ? exercise.defaultUnit.code
                                : AppStrings.recentWeightValue(
                                    latest.weight,
                                    latest.unit.code,
                                  ),
                            style: skin.caption.copyWith(
                              color: theme.colors.text,
                              fontWeight: theme.typography.bold,
                            ),
                          );
                        },
                      )
                    else
                      Icon(
                        widget.isPicker ? Icons.add : Icons.chevron_right,
                        size: theme.typography.lg,
                        color: widget.isPicker
                            ? theme.primaryAction
                            : theme.colors.textMuted,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
