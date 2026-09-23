import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

final class FitnessAppBar extends StatelessWidget {
  const FitnessAppBar({
    required this.title,
    this.actions = const [],
    this.showBottomBorder = true,
    super.key,
  });

  final String title;
  final List<Widget> actions;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppBar(
      toolbarHeight: theme.appBar.height,
      backgroundColor: theme.appBar.surface,
      title: Text(title),
      actions: actions,
      shape: showBottomBorder
          ? Border(
              bottom: BorderSide(
                color: theme.appBar.outline,
                width: theme.borders.thin,
              ),
            )
          : null,
    );
  }
}

final class CircularBackButton extends StatelessWidget {
  const CircularBackButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      width: theme.minTapTarget,
      height: theme.minTapTarget,
      child: IconButton(
        onPressed: onPressed,
        tooltip: AppStrings.back,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: theme.minTapTarget,
          height: theme.minTapTarget,
        ),
        icon: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colors.iconSurface,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: theme.spacing.s32,
            child: const Icon(Icons.chevron_left),
          ),
        ),
      ),
    );
  }
}
