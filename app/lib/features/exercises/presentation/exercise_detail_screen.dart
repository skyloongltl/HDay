import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/exercise_skin.dart';
import '../../../theme/history_skin.dart';
import '../../../widgets/app_bar.dart';
import '../../history/application/history_providers.dart';
import '../../history/domain/history_models.dart';
import '../application/exercise_providers.dart';
import '../domain/exercise.dart';

// PAGE: ExerciseDetailScreen
// ROUTE: /exercise-detail/:exerciseId
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, Card, Wrap
// STATE: exercise/history repository projections
// ANIMATIONS: none
// NAVIGATION: edit -> existing /exercise-edit/:exerciseId; log -> /history/:date
final class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({required this.exerciseId, super.key});
  final String exerciseId;
  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

final class _ExerciseDetailScreenState
    extends ConsumerState<ExerciseDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.invalidate(exerciseHistorySummaryProvider(widget.exerciseId));
      ref.invalidate(exerciseByIdProvider(widget.exerciseId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final exercise = ref.watch(exerciseByIdProvider(widget.exerciseId));
    final history =
        ref.watch(exerciseHistorySummaryProvider(widget.exerciseId));
    return SafeArea(
      child: Scaffold(
        key: const ValueKey('exercise-detail-screen'),
        appBar: AppBar(
          centerTitle: true,
          title: const Text(AppStrings.exerciseDetail),
          leading: CircularBackButton(
            key: const ValueKey('exercise-detail-back'),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.exercises),
          ),
          actions: [
            if (exercise.valueOrNull != null)
              Padding(
                padding: EdgeInsets.only(right: theme.spacing.s16),
                child: TextButton(
                  key: const ValueKey('exercise-edit-action'),
                  style: HistorySkin.button(theme).copyWith(
                    minimumSize: WidgetStatePropertyAll(
                      Size(theme.minTapTarget, theme.minTapTarget),
                    ),
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                    foregroundColor:
                        WidgetStatePropertyAll(theme.colors.textMuted),
                    textStyle: WidgetStatePropertyAll(
                      TextStyle(
                        fontSize: theme.typography.xxs,
                        fontWeight: theme.typography.medium,
                      ),
                    ),
                  ),
                  onPressed: () =>
                      context.push(AppRoutes.exerciseEdit(widget.exerciseId)),
                  child: DecoratedBox(
                    key: const ValueKey('exercise-edit-action-surface'),
                    decoration: BoxDecoration(
                      color: theme.colors.iconSurface,
                      borderRadius: BorderRadius.circular(theme.radii.sm),
                    ),
                    child: SizedBox(
                      height: theme.spacing.s28,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: theme.spacing.s10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: theme.typography.sm,
                            ),
                            SizedBox(width: theme.spacing.s4),
                            const Text(AppStrings.edit),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: exercise.isLoading || history.isLoading
            ? const Center(child: CircularProgressIndicator())
            : exercise.hasError || history.hasError
                ? Center(
                    child: TextButton(
                      onPressed: () {
                        ref.invalidate(exerciseByIdProvider(widget.exerciseId));
                        ref.invalidate(
                          exerciseHistorySummaryProvider(widget.exerciseId),
                        );
                      },
                      child: const Text(AppStrings.retry),
                    ),
                  )
                // Flutter: ListView, mainAxis: start, crossAxis: stretch
                : ListView(
                    padding: EdgeInsets.all(theme.spacing.s16),
                    children: [
                      _header(exercise.valueOrNull),
                      // Spacer: spacing.14 -> SizedBox(height: spacing.14)
                      SizedBox(height: theme.spacing.s14),
                      if (history.requireValue.records.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(theme.spacing.s24),
                          child: const Text(
                            AppStrings.noExerciseHistory,
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        _performance(history.requireValue),
                    ],
                  ),
      ),
    );
  }

  Widget _header(Exercise? exercise) {
    final theme = AppTheme.of(context);
    return DecoratedBox(
      decoration: HistorySkin.card(theme),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.s18,
          vertical: theme.spacing.s16,
        ),
        // Flutter: Row, mainAxis: start, crossAxis: center
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.mintSurface,
                borderRadius: BorderRadius.circular(theme.radii.md),
              ),
              child: SizedBox.square(
                dimension: HistorySkin.iconSize,
                child: Center(
                  child: exercise == null
                      ? Icon(
                          Icons.fitness_center,
                          color: theme.colors.mintText,
                        )
                      : Text(
                          exercise.name.characters.first,
                          style: TextStyle(
                            fontSize: theme.typography.xl,
                            color: theme.colors.mintText,
                            fontWeight: theme.typography.heavy,
                          ),
                        ),
                ),
              ),
            ),
            // Spacer: spacing.14 -> SizedBox(width: spacing.14)
            SizedBox(width: theme.spacing.s14),
            Expanded(
              // Flutter: Column, mainAxis: start, crossAxis: start
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise?.name ?? AppStrings.exerciseDeleted,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (exercise != null)
                    Padding(
                      padding: EdgeInsets.only(top: theme.spacing.s6),
                      child: Wrap(
                        spacing: theme.spacing.s4,
                        runSpacing: theme.spacing.s4,
                        children: [
                          _tag(
                            AppStrings.exerciseCategoryLabels[
                                exercise.category.code]!,
                          ),
                          _tag(
                            AppStrings.exerciseEquipmentLabels[
                                exercise.equipment.code]!,
                          ),
                          _tag(
                            AppStrings
                                .weightUnitLabels[exercise.defaultUnit.code]!,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) {
    final theme = AppTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.inputSurface,
        borderRadius: BorderRadius.circular(theme.radii.full),
        border: Border.all(color: theme.colors.outline),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.s8,
          vertical: theme.spacing.s2,
        ),
        child: Text(text, style: ExerciseSkin(theme).caption),
      ),
    );
  }

  Widget _performance(ExerciseHistorySummary summary) {
    final theme = AppTheme.of(context);
    final units = WeightUnit.values
        .where((unit) => summary.records.any((r) => r.unit == unit))
        .toList();
    final unit = units.first;
    final best = summary.bestByUnit[unit];
    final records = summary.records.take(10).toList();
    // Flutter: Column, mainAxis: start, crossAxis: stretch
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          key: const ValueKey('exercise-personal-best'),
          decoration: HistorySkin.card(theme, hero: true),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.s18),
            // Flutter: Row, mainAxis: start, crossAxis: center
            child: Row(
              children: [
                Expanded(
                  // Flutter: Column, mainAxis: start, crossAxis: start
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.personalBest,
                        style: TextStyle(
                          color: theme.colors.onHeroMuted,
                          fontSize: theme.typography.xxs,
                        ),
                      ),
                      SizedBox(height: theme.spacing.s4),
                      Text(
                        best == null
                            ? AppStrings.noValue
                            : AppStrings.historyValue(
                                best.weight,
                                best.reps,
                                best.unit.code,
                              ),
                        style: TextStyle(
                          color: theme.colors.onHero,
                          fontSize: theme.typography.xl,
                          fontWeight: theme.typography.heavy,
                        ),
                      ),
                      if (best != null)
                        Padding(
                          padding: EdgeInsets.only(top: theme.spacing.s4),
                          child: Text(
                            best.date.iso8601,
                            style: TextStyle(
                              color: theme.colors.onHeroMuted,
                              fontSize: theme.typography.xxs,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Text('🏆', style: TextStyle(fontSize: 30)),
              ],
            ),
          ),
        ),
        // Spacer: spacing.14 -> SizedBox(height: spacing.14)
        SizedBox(height: theme.spacing.s14),
        _chart(summary.trend(unit), unit),
        // Spacer: spacing.14 -> SizedBox(height: spacing.14)
        SizedBox(height: theme.spacing.s14),
        DecoratedBox(
          decoration: HistorySkin.card(theme),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.s14),
            // Flutter: Column, mainAxis: start, crossAxis: stretch
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.historyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final entry in records.indexed) ...[
                  Material(
                    color: theme.colors.surface,
                    child: InkWell(
                      key: ValueKey(
                        'exercise-log-${entry.$2.sessionId}-${entry.$2.setId}',
                      ),
                      onTap: () => context.push(
                        '/history/${entry.$2.date.iso8601}?session=${Uri.encodeQueryComponent(entry.$2.sessionId)}',
                      ),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: theme.spacing.s10),
                        child: Row(
                          children: [
                            Expanded(child: Text(entry.$2.date.iso8601)),
                            Text(
                              AppStrings.historyValue(
                                entry.$2.weight,
                                entry.$2.reps,
                                entry.$2.unit.code,
                              ),
                              style: TextStyle(
                                fontWeight: theme.typography.bold,
                              ),
                            ),
                            if (entry.$1 == 0) ...[
                              SizedBox(width: theme.spacing.s6),
                              _tag(AppStrings.recentRecord),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (entry.$1 < records.length - 1)
                    Divider(height: 1, color: theme.colors.outline),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chart(List<ExerciseRecord> records, WeightUnit unit) {
    final theme = AppTheme.of(context);
    records = records.take(6).toList();
    final weighted = unit == WeightUnit.kg || unit == WeightUnit.lb;
    final values = records
        .map((r) => weighted ? r.weight ?? HistorySkin.zero : r.reps.toDouble())
        .toList();
    final maximum = values.fold(HistorySkin.one, (a, b) => a > b ? a : b);
    return DecoratedBox(
      key: const ValueKey('exercise-trend'),
      decoration: HistorySkin.card(theme),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.s16),
        // Flutter: Column, mainAxis: start, crossAxis: stretch
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              weighted ? AppStrings.weightTrend : AppStrings.repsTrend,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // Spacer: spacing.14 -> SizedBox(height: spacing.14)
            SizedBox(height: theme.spacing.s14),
            SizedBox(
              height: HistorySkin.chartHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 6.0;
                  final barWidth = records.length == 1
                      ? constraints.maxWidth.clamp(0.0, 48.0)
                      : ((constraints.maxWidth - gap * (records.length - 1)) /
                              records.length)
                          .clamp(0.0, 48.0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final entry in records.indexed) ...[
                        if (entry.$1 > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: barWidth,
                          child: Semantics(
                            label:
                                '${entry.$2.date.iso8601} ${AppStrings.historyValue(entry.$2.weight, entry.$2.reps, unit.code)}',
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: HistorySkin.chartMinimum +
                                      values[entry.$1] /
                                          maximum *
                                          HistorySkin.chartMaximum,
                                  width: double.infinity,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: entry.$1 == records.length - 1
                                          ? theme.primaryAction
                                          : theme.colors.outlineStrong,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(
                                          theme.radii.xs,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${entry.$2.date.month}/${entry.$2.date.day}',
                                  style: TextStyle(
                                    fontSize: theme.typography.xxs,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
