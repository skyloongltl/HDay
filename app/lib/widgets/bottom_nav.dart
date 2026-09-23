import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../theme/fitness_theme_extension.dart';

final class BottomNav extends StatelessWidget {
  const BottomNav({
    required this.selectedTabIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedTabIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.bottomNav.outline,
            width: theme.borders.thin,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            NavigationBarTheme(
              data: NavigationBarTheme.of(context).copyWith(
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    size: theme.typography.lg,
                    color: states.contains(WidgetState.selected)
                        ? theme.colors.text
                        : theme.colors.textSubtle,
                  ),
                ),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: theme.typography.xxs,
                    fontWeight: states.contains(WidgetState.selected)
                        ? theme.typography.bold
                        : theme.typography.regular,
                    color: states.contains(WidgetState.selected)
                        ? theme.colors.text
                        : theme.colors.textSubtle,
                  ),
                ),
              ),
              child: NavigationBar(
                height: theme.bottomNav.height,
                backgroundColor: theme.bottomNav.surface,
                indicatorColor: theme.bottomNav.surface,
                selectedIndex: selectedTabIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.today_outlined),
                    selectedIcon: Icon(Icons.today),
                    label: AppStrings.todayTab,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.view_list_outlined),
                    selectedIcon: Icon(Icons.view_list),
                    label: AppStrings.plansTab,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: AppStrings.calendarTab,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.fitness_center_outlined),
                    selectedIcon: Icon(Icons.fitness_center),
                    label: AppStrings.exercisesTab,
                  ),
                ],
              ),
            ),
            // Animation: top indicator slides between tabs, 250ms easeOut (Figma).
            AnimatedPositioned(
              duration: FitnessBottomNavSkin.indicatorDuration,
              curve: theme.motion.curve,
              top: theme.spacing.s6,
              left: constraints.maxWidth /
                      AppStrings.primaryTabLabels.length *
                      selectedTabIndex +
                  (constraints.maxWidth / AppStrings.primaryTabLabels.length -
                          FitnessBottomNavSkin.indicatorWidth) /
                      2,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('bottom-nav-indicator'),
                  decoration: BoxDecoration(
                    color: theme.bottomNav.indicator,
                    borderRadius: BorderRadius.circular(theme.spacing.s2),
                  ),
                  child: const SizedBox(
                    width: FitnessBottomNavSkin.indicatorWidth,
                    height: FitnessBottomNavSkin.indicatorHeight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
