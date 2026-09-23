import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/domain/local_date.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/unavailable_action_list_tile.dart';
import '../application/today_providers.dart';
import '../domain/today_overview.dart';

// PAGE: HomeScreen
// ROUTE: /home
// FLUTTER WIDGETS: ListView, Card, ElevatedButton
// STATE: todayOverview(AsyncValue<TodayOverview>)
// ANIMATIONS: primary action press (100ms, easeOut)
// NAVIGATION: preparation actions -> /pre-workout; recovery -> workout phase route
final class HomeScreen extends ConsumerWidget {
  const HomeScreen({this.showWorkoutUnavailable = false, super.key});
  final bool showWorkoutUnavailable;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(todayOverviewProvider).when(
            loading: () => _LoadingHome(
              showWorkoutUnavailable: showWorkoutUnavailable,
            ),
            error: (_, __) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(AppStrings.todayLoadFailed),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(todayOverviewProvider),
                    child: const Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
            data: (overview) => _HomeContent(
              overview: overview,
              showWorkoutUnavailable: showWorkoutUnavailable,
            ),
          );
}

final class _LoadingHome extends ConsumerWidget {
  const _LoadingHome({required this.showWorkoutUnavailable});
  final bool showWorkoutUnavailable;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    return ListView(
      key: const ValueKey('home-screen'),
      padding: EdgeInsets.all(theme.spacing.s16),
      children: [
        if (showWorkoutUnavailable) ...[
          const Text(AppStrings.workoutUnavailable),
          SizedBox(height: theme.spacing.s12),
        ],
        Text(
          AppStrings.todaysTraining,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        SizedBox(height: theme.spacing.s12),
        AppCard(
          padding: EdgeInsets.all(theme.spacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: theme.spacing.s24,
                    child: const CircularProgressIndicator(value: 0.25),
                  ),
                  SizedBox(width: theme.spacing.s12),
                  Expanded(
                    child: Text(
                      AppStrings.todayLoading,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.s8),
              Text(AppStrings.todayLoading),
              SizedBox(height: theme.spacing.s16),
            ],
          ),
        ),
      ],
    );
  }
}

final class _HomeContent extends ConsumerWidget {
  const _HomeContent({
    required this.overview,
    required this.showWorkoutUnavailable,
  });
  final TodayOverview overview;
  final bool showWorkoutUnavailable;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppTheme.of(context);
    final date = ref.read(clockProvider).today();
    final active = overview.unfinishedSession != null;
    final planned = overview.mergedExercises.isNotEmpty;
    // Flutter: ListView, mainAxis: start, crossAxis: stretch
    return ListView(
      key: const ValueKey('home-screen'),
      padding: EdgeInsets.all(theme.spacing.s16),
      children: [
        if (showWorkoutUnavailable) ...[
          const Text(AppStrings.workoutUnavailable),
          SizedBox(height: theme.spacing.s12),
        ],
        Text(
          active
              ? AppStrings.currentWorkout
              : overview.isAllRest
                  ? AppStrings.todayRestTitle
                  : planned
                      ? AppStrings.todayTraining
                      : AppStrings.todaysTraining,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        SizedBox(height: theme.spacing.s12),
        if (active)
          _HeroCard(
            label: AppStrings.workoutPhaseLabel(
              overview.unfinishedSession!.phase.name,
            ),
            action: AppStrings.resumeWorkout,
            onPressed: () => context.go(
              AppRoutes.forWorkoutSession(overview.unfinishedSession!),
            ),
          )
        else if (overview.isAllRest)
          _HeroCard(
            label: AppStrings.todayRestHint,
            action: AppStrings.startFreeWorkout,
            onPressed: () => _prepare(context, date, true),
          )
        else if (planned) ...[
          _PlannedHeroCard(
            overview: overview,
            onPressed: () => _prepare(context, date, false),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(theme.spacing.s48),
            ),
            onPressed: () => _prepare(context, date, true),
            child: const Text(AppStrings.startFreeWorkout),
          ),
        ] else
          _EmptyCard(onPressed: () => _prepare(context, date, true)),
        SizedBox(height: theme.spacing.s12),
        _StatsRow(overview: overview),
        if (planned) ...[
          SizedBox(height: theme.spacing.s16),
          Text(
            AppStrings.plannedExercises,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: theme.spacing.s8),
          for (final item in overview.mergedExercises)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.s6),
              child: AppCard(
                padding: EdgeInsets.all(theme.spacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.exercise.nameSnapshot,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: theme.spacing.s2),
                    Text(
                      AppStrings.preparationSource(
                        item.source.plan.name,
                        item.source.revision.id,
                        item.source.day.dayNumber,
                        item.source.day.name,
                      ),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    SizedBox(height: theme.spacing.s4),
                    Text(
                      item.exercise.sets.isEmpty
                          ? AppStrings.setSummary(0)
                          : AppStrings.plannedExerciseSummary(
                              item.exercise.sets.length,
                              item.exercise.sets.first.plannedWeight,
                              item.exercise.sets.first.unit.code,
                            ),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  void _prepare(BuildContext context, LocalDate date, bool freeWorkout) =>
      context.go(AppRoutes.preWorkout(date: date, freeWorkout: freeWorkout));
}

final class _PlannedHeroCard extends StatelessWidget {
  const _PlannedHeroCard({required this.overview, required this.onPressed});
  final TodayOverview overview;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final source = overview.mergedExercises.first.source;
    final sourceCount = overview.mergedExercises
        .map(
          (item) => (
            item.source.plan.id,
            item.source.revision.id,
            item.source.day.dayNumber,
          ),
        )
        .toSet()
        .length;
    final hasMergedSources = sourceCount > 1;
    return AppCard(
      color: theme.hero,
      padding: EdgeInsets.all(theme.spacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasMergedSources
                ? AppStrings.mergedPlanSources(sourceCount)
                : AppStrings.plannedSource(
                    source.plan.name,
                    source.day.dayNumber,
                  ),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: theme.colors.onHeroMuted),
          ),
          SizedBox(height: theme.spacing.s8),
          Text(
            hasMergedSources ? AppStrings.mergedTrainingTitle : source.day.name,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: theme.colors.onHero),
          ),
          SizedBox(height: theme.spacing.s4),
          Text(
            AppStrings.plannedSummary(
              overview.mergedExercises.length,
              overview.totalPlannedSets,
            ),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: theme.colors.onHeroMuted),
          ),
          SizedBox(height: theme.spacing.s12),
          ElevatedButton(
            key: const ValueKey('today-primary-action'),
            onPressed: onPressed,
            child: const Text(AppStrings.startTodayWorkout),
          ),
        ],
      ),
    );
  }
}

final class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.label,
    required this.action,
    required this.onPressed,
  });
  final String label;
  final String action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppCard(
      color: theme.hero,
      padding: EdgeInsets.all(theme.spacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: theme.colors.onHero),
          ),
          SizedBox(height: theme.spacing.s12),
          if (onPressed == null)
            UnavailableActionListTile(
              key: const ValueKey('unavailable-recovery'),
              label: action,
            )
          else
            ElevatedButton(
              key: const ValueKey('today-primary-action'),
              onPressed: onPressed,
              child: Text(action),
            ),
        ],
      ),
    );
  }
}

final class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppCard(
      padding: EdgeInsets.all(theme.spacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.noExercisesToday,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: theme.spacing.s8),
          Text(AppStrings.noPlanActionHint),
          SizedBox(height: theme.spacing.s16),
          ElevatedButton(
            key: const ValueKey('today-primary-action'),
            onPressed: onPressed,
            child: const Text(AppStrings.startFreeWorkout),
          ),
        ],
      ),
    );
  }
}

final class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.overview});
  final TodayOverview overview;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final values = [
      (overview.fitnessDayStats.total, AppStrings.totalWorkouts),
      (overview.fitnessDayStats.week, AppStrings.weeklyWorkouts),
      (overview.fitnessDayStats.month, AppStrings.monthlyWorkouts),
    ];
    // Flutter: Row, mainAxis: start, crossAxis: stretch
    return Row(
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.s2),
              child: AppCard(
                padding: EdgeInsets.all(theme.spacing.s8),
                child: Column(
                  children: [
                    Text(
                      '${value.$1}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      value.$2,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
