import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

final class UnavailableActionListTile extends StatelessWidget {
  const UnavailableActionListTile({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Semantics(
      enabled: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.inputSurface,
          border: Border.all(color: theme.colors.outline),
          borderRadius: BorderRadius.circular(theme.radii.button),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.spacing.s48),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.s12),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: theme.colors.textSubtle,
                ),
                SizedBox(width: theme.spacing.s8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
