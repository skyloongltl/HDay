import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/exercise_skin.dart';

final class ExerciseFilterChips extends StatelessWidget {
  const ExerciseFilterChips({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.keyPrefix,
    this.scroll = false,
    super.key,
  });
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;
  final String keyPrefix;
  final bool scroll;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final chips = options.entries
        .map(
          (option) => Semantics(
            selected: value == option.key,
            child: TextButton(
              key: ValueKey('$keyPrefix-${option.key}'),
              onPressed: () => onChanged(option.key),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size(
                  40,
                  scroll ? theme.minTapTarget : 40,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              // Animation: implicit background/color 150ms easeOut, as Figma chip group.
              child: AnimatedContainer(
                duration: ExerciseSkin.chipDuration,
                curve: theme.motion.curve,
                constraints: const BoxConstraints.tightFor(
                  height: ExerciseSkin.chipHeight,
                ),
                padding: EdgeInsets.symmetric(horizontal: theme.spacing.s12),
                decoration: BoxDecoration(
                  color: value == option.key
                      ? theme.colors.text
                      : theme.colors.inputSurface,
                  borderRadius: BorderRadius.circular(theme.radii.full),
                  border: Border.all(
                    color: value == option.key
                        ? theme.colors.text
                        : theme.colors.outline,
                    width: theme.borders.thin,
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    option.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      height: 1,
                      fontSize: theme.typography.xs,
                      color: value == option.key
                          ? theme.colors.onHero
                          : theme.colors.textMuted,
                      fontWeight: value == option.key
                          ? theme.typography.bold
                          : theme.typography.regular,
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .toList();
    if (scroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Flutter: Row, mainAxis: start, crossAxis: center
        child: Row(spacing: theme.spacing.s6, children: chips),
      );
    }
    // Flutter: Wrap, mainAxis: start, crossAxis: center
    return Wrap(
      spacing: theme.spacing.s6,
      runSpacing: theme.spacing.s2,
      children: chips,
    );
  }
}
