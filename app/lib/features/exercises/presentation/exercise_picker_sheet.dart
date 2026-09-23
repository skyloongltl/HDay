import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/exercise_skin.dart';
import '../application/exercise_providers.dart';
import '../domain/exercise.dart';
import 'exercise_catalog_view.dart';

// PAGE: ExercisePickerSheet (shared by plan/pre-workout/in-workout callers)
// ROUTE: modal
// FLUTTER WIDGETS: BottomSheet, Column, TextField, ListView
// STATE: selectedIds(Set<String>); query/category/equipment in scoped controller
// ANIMATIONS: sheet slide up 280ms easeOut; overlay fade via modal route
// NAVIGATION: single selection -> callback then pop; close -> pop; create -> /exercise-create
final class ExercisePickerSheet extends ConsumerStatefulWidget {
  const ExercisePickerSheet({
    required this.onSelected,
    this.allowMultiple = false,
    this.excludeIds = const {},
    super.key,
  });
  final ValueChanged<Exercise> onSelected;
  final bool allowMultiple;
  final Set<String> excludeIds;
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<Exercise> onSelected,
    bool allowMultiple = false,
    Set<String> excludeIds = const {},
  }) {
    final theme = AppTheme.of(context);
    ProviderScope.containerOf(context, listen: false)
        .invalidate(exercisePickerControllerProvider);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colors.page,
      barrierColor:
          theme.colors.text.withValues(alpha: theme.opacities.overlay),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.radii.xl)),
      ),
      clipBehavior: Clip.antiAlias,
      sheetAnimationStyle:
          const AnimationStyle(duration: ExerciseSkin.sheetDuration),
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: SizedBox(
              height: (constraints.maxHeight - keyboard) *
                  ExerciseSkin.sheetFraction,
              child: ExercisePickerSheet(
                onSelected: onSelected,
                allowMultiple: allowMultiple,
                excludeIds: excludeIds,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  ConsumerState<ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

final class _ExercisePickerSheetState
    extends ConsumerState<ExercisePickerSheet> {
  late final Set<String> selectedIds = {
    ...widget.excludeIds,
  }; // Flutter: setState
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // Flutter: Column, mainAxis: start, crossAxis: stretch
    // Flutter: Column, mainAxis: start, crossAxis: stretch
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: theme.spacing.s12),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.outline,
                borderRadius: BorderRadius.circular(theme.radii.full),
              ),
              child: SizedBox(
                width: ExerciseSkin.avatarSize,
                height: theme.spacing.s4,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.s16),
          // Flutter: Row, mainAxis: spaceBetween, crossAxis: center
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.pickExercise,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                tooltip: AppStrings.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ExerciseCatalogView(
            provider: exercisePickerControllerProvider,
            isPicker: true,
            selectedIds: selectedIds,
            onSelected: (exercise) {
              widget.onSelected(exercise);
              if (widget.allowMultiple) {
                setState(() => selectedIds.add(exercise.id));
              } else {
                Navigator.pop(context);
              }
            },
            onCreate: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push(AppRoutes.exerciseCreate);
            },
          ),
        ),
      ],
    );
  }
}
