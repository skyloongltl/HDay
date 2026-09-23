import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

final class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.color,
    this.padding,
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? theme.appCard.surface,
        border: Border.all(
          color: theme.appCard.outline,
          width: theme.borders.thin,
        ),
        borderRadius: BorderRadius.circular(theme.appCard.radius),
        boxShadow: theme.appCard.shadow,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(theme.spacing.s16),
        child: child,
      ),
    );
  }
}
