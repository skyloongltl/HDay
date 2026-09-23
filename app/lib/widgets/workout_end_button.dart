import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

final class WorkoutEndButton extends StatelessWidget {
  const WorkoutEndButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox.square(
      dimension: theme.minTapTarget,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(theme.radii.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.primaryAction.withValues(
                  alpha: onPressed == null ? theme.opacities.disabled : 1,
                ),
                borderRadius: BorderRadius.circular(theme.radii.sm),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.s10,
                  vertical: theme.spacing.s4,
                ),
                child: Text(
                  AppStrings.endWorkout,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: theme.colors.onHero,
                        fontWeight: theme.typography.bold,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
