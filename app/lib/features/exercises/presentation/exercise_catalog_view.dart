import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/exercise_skin.dart';
import '../application/exercise_controller.dart';
import '../domain/exercise.dart';
import 'exercise_filter_chips.dart';
import 'exercise_list_tile.dart';

/// Shared query/list surface for the catalog and any picker caller.
final class ExerciseCatalogView extends ConsumerStatefulWidget {
  const ExerciseCatalogView({
    required this.provider,
    required this.onSelected,
    required this.onCreate,
    this.isPicker = false,
    this.selectedIds = const {},
    super.key,
  });
  final AsyncNotifierProvider<ExerciseController, ExerciseState> provider;
  final ValueChanged<Exercise> onSelected;
  final VoidCallback onCreate;
  final bool isPicker;
  final Set<String> selectedIds;
  @override
  ConsumerState<ExerciseCatalogView> createState() =>
      _ExerciseCatalogViewState();
}

final class _ExerciseCatalogViewState
    extends ConsumerState<ExerciseCatalogView> {
  late final TextEditingController
      searchQuery; // Flutter: TextEditingController
  @override
  void initState() {
    super.initState();
    searchQuery = TextEditingController(
      text: ref.read(widget.provider).valueOrNull?.searchQuery ?? '',
    );
  }

  @override
  void dispose() {
    searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ref.watch(widget.provider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _error(),
        data: (state) {
          final theme = AppTheme.of(context);
          // Flutter: Column, mainAxis: start, crossAxis: stretch
          // Flutter: Column, mainAxis: start, crossAxis: stretch
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filters(state),
              if (state.isLoading)
                LinearProgressIndicator(minHeight: theme.spacing.s2),
              Expanded(
                child: state.loadFailed
                    ? _error()
                    // Flutter: ListView, mainAxis: start, crossAxis: stretch
                    : ListView(
                        padding: EdgeInsets.all(theme.spacing.s16),
                        children: _items(state),
                      ),
              ),
            ],
          );
        },
      );

  Widget _filters(ExerciseState state) {
    final theme = AppTheme.of(context);
    final controller = ref.read(widget.provider.notifier);
    return ColoredBox(
      color: widget.isPicker ? theme.colors.page : theme.colors.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.s16),
        // Flutter: Column, mainAxis: start, crossAxis: stretch
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchField(state, controller),
            ExerciseFilterChips(
              options: {
                '': AppStrings.allCategories,
                ...AppStrings.exerciseCategoryLabels,
              },
              value: state.selectedCategory ?? '',
              keyPrefix: 'filter-category',
              scroll: true,
              onChanged: (value) =>
                  controller.setCategory(value.isEmpty ? null : value),
            ),
            ExerciseFilterChips(
              options: {
                '': AppStrings.allEquipment,
                ...AppStrings.exerciseEquipmentLabels,
              },
              value: state.selectedEquipment ?? '',
              keyPrefix: 'filter-equipment',
              scroll: true,
              onChanged: (value) =>
                  controller.setEquipment(value.isEmpty ? null : value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(ExerciseState state, ExerciseController controller) {
    final theme = AppTheme.of(context);
    final suffix = state.searchQuery.isEmpty
        ? null
        : IconButton(
            tooltip: AppStrings.clearSearch,
            icon: const Icon(Icons.close),
            onPressed: () {
              searchQuery.clear();
              controller.search('');
            },
          );
    final textStyle = ExerciseSkin(theme)
        .title
        .copyWith(fontWeight: theme.typography.regular);

    if (widget.isPicker) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.surface,
          borderRadius: BorderRadius.circular(theme.radii.md),
        ),
        child: TextField(
          key: const ValueKey('exercise-search'),
          controller: searchQuery,
          onChanged: controller.search,
          style: textStyle,
          decoration: ExerciseSkin(theme)
              .input(
                AppStrings.searchExercise,
                prefix: Icon(
                  Icons.search,
                  size: theme.typography.lg,
                  color: theme.colors.textSubtle,
                ),
                suffix: suffix,
              )
              .copyWith(
                contentPadding:
                    EdgeInsets.symmetric(vertical: theme.spacing.s8),
                prefixIconConstraints: BoxConstraints(
                  minWidth: theme.minTapTarget,
                  minHeight: theme.minTapTarget,
                ),
                suffixIconConstraints: BoxConstraints(
                  minWidth: theme.minTapTarget,
                  minHeight: theme.minTapTarget,
                ),
              ),
        ),
      );
    }

    return SizedBox(
      height: theme.minTapTarget,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            key: const ValueKey('exercise-search-surface'),
            decoration: BoxDecoration(
              color: theme.colors.inputSurface,
              borderRadius: BorderRadius.circular(theme.radii.md),
            ),
            child: SizedBox(
              width: double.infinity,
              height: theme.spacing.s40,
            ),
          ),
          Positioned.fill(
            child: TextField(
              key: const ValueKey('exercise-search'),
              controller: searchQuery,
              onChanged: controller.search,
              textAlignVertical: TextAlignVertical.center,
              style: textStyle,
              decoration: ExerciseSkin(theme)
                  .input(
                    AppStrings.searchExercise,
                    prefix: Padding(
                      padding: EdgeInsets.only(
                        left: theme.spacing.s14,
                        right: theme.spacing.s8,
                      ),
                      child: Icon(
                        Icons.search,
                        size: theme.typography.md,
                        color: theme.colors.textSubtle,
                      ),
                    ),
                    suffix: suffix,
                  )
                  .copyWith(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.only(right: theme.spacing.s14),
                    prefixIconConstraints: BoxConstraints.tightFor(
                      height: theme.minTapTarget,
                    ),
                    suffixIconConstraints: BoxConstraints.tightFor(
                      width: theme.minTapTarget,
                      height: theme.minTapTarget,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _items(ExerciseState state) {
    final theme = AppTheme.of(context);
    final filtered = state.searchQuery.isNotEmpty ||
        state.selectedCategory != null ||
        state.selectedEquipment != null;
    final result = <Widget>[];
    if (state.items.isEmpty) {
      result.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: theme.spacing.s40),
          // Flutter: Column, mainAxis: start, crossAxis: center
          child: Column(
            children: [
              Icon(
                Icons.fitness_center_outlined,
                size: theme.dimensions.emptyIconSize,
                color: theme.colors.textSubtle,
              ),
              // Spacer: spacing.14 -> SizedBox(height: spacing.14)
              SizedBox(height: theme.spacing.s14),
              Text(
                filtered
                    ? AppStrings.noMatchingExercises
                    : AppStrings.noExercises,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!filtered)
                Padding(
                  padding: EdgeInsets.all(theme.spacing.s12),
                  child: Text(
                    AppStrings.noExercisesHint,
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!widget.isPicker && !filtered)
                ElevatedButton(
                  onPressed: widget.onCreate,
                  child: const Text(AppStrings.createExercise),
                ),
            ],
          ),
        ),
      );
    } else {
      if (!filtered && !widget.isPicker) {
        result.add(_heading(AppStrings.recentExercises));
        if (state.recentItems.isEmpty) {
          result.add(
            Text(
              AppStrings.noRecentExercises,
              style: ExerciseSkin(theme).caption,
            ),
          );
        } else {
          result.addAll(
            state.recentItems.map((exercise) => _tile(exercise, recent: true)),
          );
        }
        result.add(
          SizedBox(
            height: theme.spacing.s20,
          ),
        ); // Spacer: spacing.20 -> SizedBox
      }
      result.add(
        _heading(
          filtered
              ? AppStrings.exerciseCount(state.items.length)
              : AppStrings.allExercises,
        ),
      );
      result.addAll(state.items.map(_tile));
    }
    if (widget.isPicker) result.add(_createTile());
    return result;
  }

  Widget _createTile() {
    final theme = AppTheme.of(context);
    final skin = ExerciseSkin(theme);
    return CustomPaint(
      foregroundPainter: ExerciseDashedBorder(theme),
      child: Material(
        color: theme.colors.page,
        child: InkWell(
          onTap: widget.onCreate,
          borderRadius: BorderRadius.circular(theme.radii.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.s12,
              vertical: theme.spacing.s10,
            ),
            // Flutter: Row, mainAxis: start, crossAxis: center
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colors.primarySurface,
                    borderRadius: BorderRadius.circular(theme.radii.sm),
                  ),
                  child: SizedBox.square(
                    dimension: ExerciseSkin.avatarSize,
                    child: Icon(
                      Icons.add,
                      color: theme.primaryAction,
                      size: theme.typography.lg,
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
                      Text(
                        AppStrings.newExercise,
                        style: skin.title.copyWith(color: theme.primaryAction),
                      ),
                      Text(AppStrings.createExerciseHint, style: skin.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: EdgeInsets.only(bottom: AppTheme.of(context).spacing.s10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
  Widget _tile(Exercise exercise, {bool recent = false}) => ExerciseListTile(
        key: ValueKey(
          '${widget.isPicker ? 'picker' : recent ? 'recent' : 'library'}-exercise-${exercise.id}',
        ),
        exercise: exercise,
        isRecent: recent,
        isPicker: widget.isPicker,
        isSelected: widget.selectedIds.contains(exercise.id),
        onTap: widget.selectedIds.contains(exercise.id)
            ? null
            : () => widget.onSelected(exercise),
      );
  Widget _error() => Center(
        // Flutter: Column, mainAxis: start, crossAxis: center
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppStrings.exerciseLoadFailed),
            TextButton(
              onPressed: ref.read(widget.provider.notifier).reload,
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      );
}
