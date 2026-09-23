import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/app_scaffold.dart';
import '../application/exercise_providers.dart';
import 'exercise_catalog_view.dart';

// PAGE: ExerciseLibraryScreen
// ROUTE: /exercises
// FLUTTER WIDGETS: Scaffold, AppBar, TextField, ListView, BottomNavigationBar
// STATE: searchQuery(String), selectedCategory(String?), selectedEquipment(String?) in controller
// ANIMATIONS: chip background 150ms easeOut; tile press scale .98 100ms easeOut
// NAVIGATION: add -> /exercise-create; exercise -> /exercise-detail/:exerciseId
final class ExerciseLibraryScreen extends StatelessWidget {
  const ExerciseLibraryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppScaffold(
      selectedTabIndex: 3,
      onDestinationSelected: (index) => context.go(AppRoutes.primary[index]),
      appBar: FitnessAppBar(
        title: AppStrings.exercisesTitle,
        showBottomBorder: false,
        actions: [
          IconButton(
            tooltip: AppStrings.createExercise,
            onPressed: () => context.push(AppRoutes.exerciseCreate),
            icon: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.primaryAction,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.s6),
                child: Icon(
                  Icons.add,
                  color: theme.colors.onHero,
                  size: theme.typography.xl,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ExerciseCatalogView(
        key: const ValueKey('exercises-screen'),
        provider: exerciseControllerProvider,
        onSelected: (exercise) =>
            context.push(AppRoutes.exerciseDetail(exercise.id)),
        onCreate: () => context.push(AppRoutes.exerciseCreate),
      ),
    );
  }
}
