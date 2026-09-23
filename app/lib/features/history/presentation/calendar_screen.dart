import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/history_skin.dart';
import '../../../widgets/app_scaffold.dart';
import '../../settings/domain/app_settings.dart';
import '../../workout/domain/workout_draft.dart';
import '../../workout/domain/workout_session.dart';
import '../application/history_controller.dart';
import '../application/history_providers.dart';
import '../domain/history_models.dart';
import 'recent_history_card.dart';

// PAGE: CalendarScreen
// ROUTE: /calendar
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, GridView, BottomNavigationBar
// STATE: selectedDate/currentMonth(LocalDate, HistoryController), selected(bool derived)
// ANIMATIONS: month slide 250ms easeOut; implicit selected background 150ms easeOut
// NAVIGATION: date -> selected preview; history card -> /history/:date
final class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

final class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      try {
        await ref.read(historyControllerProvider.future);
      } catch (_) {
        // The provider's error state presents retry in build.
        return;
      }
      if (mounted) {
        await ref.read(historyControllerProvider.notifier).reload();
        if (mounted) ref.invalidate(recentHistoryProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final view = ref.watch(historyControllerProvider);
    final month =
        view.valueOrNull?.currentMonth ?? ref.watch(clockProvider).today();
    return AppScaffold(
      selectedTabIndex: 2,
      onDestinationSelected: (index) => context.go(AppRoutes.primary[index]),
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(AppStrings.formatMonth(DateTime(month.year, month.month))),
        leading: IconButton(
          key: const ValueKey('calendar-previous'),
          tooltip: AppStrings.previousMonth,
          onPressed: view.hasValue
              ? () => ref
                  .read(historyControllerProvider.notifier)
                  .loadMonth(HistoryController.shiftMonth(month, -1))
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        actions: [
          IconButton(
            key: const ValueKey('calendar-next'),
            tooltip: AppStrings.nextMonth,
            onPressed: view.hasValue
                ? () => ref
                    .read(historyControllerProvider.notifier)
                    .loadMonth(HistoryController.shiftMonth(month, 1))
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: view.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () {
              ref.invalidate(historyRepositoryProvider);
              // Keep the pending month/date instead of resetting to today.
              ref.read(historyControllerProvider.notifier).reload();
            },
            child: const Text(AppStrings.retry),
          ),
        ),
        // Flutter: ListView, mainAxis: start, crossAxis: stretch
        data: (value) => ListView(
          key: const ValueKey('calendar-screen'),
          padding: EdgeInsets.symmetric(vertical: theme.spacing.s14),
          children: [
            if (value.failure != null)
              TextButton(
                onPressed: () =>
                    ref.read(historyControllerProvider.notifier).reload(),
                child: const Text(AppStrings.historyLoadFailed),
              ),
            _monthGrid(value),
            Padding(
              padding: EdgeInsets.all(theme.spacing.s16),
              child: _dayPreview(value),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.s16),
              child: _recent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthGrid(HistoryState value) {
    final theme = AppTheme.of(context);
    final cells =
        HistoryController.monthCells(value.currentMonth, value.weekStart);
    final labels = value.weekStart == WeekStart.monday
        ? AppStrings.weekLabelsMonday
        : AppStrings.weekLabelsSunday;
    return Padding(
      // Seven 48px targets need 336px: narrow screens use 8px outer padding.
      padding: EdgeInsets.symmetric(horizontal: theme.spacing.s8),
      // Flutter: Column, mainAxis: start, crossAxis: stretch
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Flutter: Row, mainAxis: start, crossAxis: center
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
            ],
          ),
          // Spacer: spacing.6 -> SizedBox(height: spacing.6)
          SizedBox(height: theme.spacing.s6),
          // Animation: explicit month slide 250ms easeOut.
          AnimatedSwitcher(
            duration: HistorySkin.monthDuration,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: HistorySkin.monthSlide,
                end: HistorySkin.restOffset,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
            // Flutter: GridView, mainAxis: start, crossAxis: stretch
            child: GridView.builder(
              key: ValueKey(value.currentMonth),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: DateTime.daysPerWeek,
                mainAxisExtent: theme.minTapTarget + theme.spacing.s8,
              ),
              itemCount: cells.length,
              itemBuilder: (_, index) {
                final date = cells[index];
                return date == null
                    ? const SizedBox.shrink()
                    : _cell(
                        value.month[date.day - 1],
                        value.selectedDate == date,
                      );
              },
            ),
          ),
          // Flutter: Wrap, mainAxis: start, crossAxis: center
          Wrap(
            spacing: theme.spacing.s12,
            runSpacing: theme.spacing.s4,
            children: [
              _legend(AppStrings.savedWorkout, HistorySkin.completed),
              _legend(
                AppStrings.unfinishedWorkout,
                HistorySkin.unfinishedBorder,
              ),
              _legend(
                AppStrings.plannedDay,
                theme.colors.textMuted,
                outline: true,
              ),
              _legend(AppStrings.restDay, theme.colors.mintText, outline: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color, {bool outline = false}) {
    final theme = AppTheme.of(context);
    // Flutter: Row, mainAxis: start, crossAxis: center
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          outline ? Icons.radio_button_unchecked : Icons.circle,
          color: color,
          size: theme.spacing.s8,
        ),
        // Spacer: spacing.4 -> SizedBox(width: spacing.4)
        SizedBox(width: theme.spacing.s4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }

  Widget _cell(CalendarDaySummary day, bool selected) {
    final theme = AppTheme.of(context);
    final today = day.date == ref.read(clockProvider).today();
    final background = selected
        ? theme.colors.text
        : day.hasSavedWorkout
            ? HistorySkin.completed
            : day.hasUnfinishedWorkout
                ? HistorySkin.unfinishedSurface
                : theme.colors.page;
    final foreground = selected || day.hasSavedWorkout
        ? theme.colors.onHero
        : day.hasUnfinishedWorkout
            ? HistorySkin.unfinishedText
            : today
                ? theme.primaryAction
                : theme.colors.text;
    final border = selected || day.hasSavedWorkout
        ? background
        : day.hasUnfinishedWorkout
            ? HistorySkin.unfinishedBorder
            : day.hasPlan && !day.isAllRest
                ? theme.colors.outlineStrong
                : today
                    ? theme.primaryAction
                    : theme.colors.page;
    final description = [
      day.date.iso8601,
      if (today) AppStrings.calendarToday,
      if (day.hasSavedWorkout) AppStrings.savedWorkout,
      if (day.hasUnfinishedWorkout) AppStrings.unfinishedWorkout,
      if (day.hasPlan)
        day.isAllRest ? AppStrings.restDay : AppStrings.plannedDay,
    ].join(', ');
    return Semantics(
      label: description,
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('calendar-day-${day.date.iso8601}'),
        onTap: () =>
            ref.read(historyControllerProvider.notifier).loadDay(day.date),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.s2),
          // Animation: implicit background/border 150ms easeOut per React cell annotation.
          child: AnimatedContainer(
            duration: HistorySkin.selectionDuration,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(
                color: border,
                width: theme.borders.strong,
              ),
              borderRadius: BorderRadius.circular(theme.radii.sm),
            ),
            // Flutter: Column, mainAxis: center, crossAxis: center
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.date.day}',
                  style: TextStyle(
                    fontSize: theme.typography.xs,
                    color: foreground,
                    fontWeight: selected || today || day.hasSavedWorkout
                        ? theme.typography.bold
                        : theme.typography.regular,
                  ),
                ),
                if (day.hasPlan)
                  Icon(
                    day.isAllRest
                        ? Icons.horizontal_rule
                        : Icons.radio_button_unchecked,
                    key: ValueKey(
                      'planned-marker-${day.date.iso8601}',
                    ),
                    size: theme.spacing.s10,
                    color: selected || day.hasSavedWorkout
                        ? theme.mint
                        : theme.colors.mintText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayPreview(HistoryState value) {
    final theme = AppTheme.of(context);
    final day = value.month[value.selectedDate.day - 1];
    // Flutter: Column, mainAxis: start, crossAxis: stretch
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.historyDate(
            value.selectedDate.month,
            value.selectedDate.day,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        // Spacer: spacing.10 -> SizedBox(height: spacing.10)
        SizedBox(height: theme.spacing.s10),
        if (value.sessions.isEmpty)
          DecoratedBox(
            decoration: HistorySkin.card(theme),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.s24),
              child: Text(
                day.isAllRest
                    ? AppStrings.restDay
                    : day.hasPlan
                        ? AppStrings.plannedNotStarted
                        : AppStrings.noDateHistory,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final session in value.sessions) _sessionCard(session),
      ],
    );
  }

  Widget _sessionCard(WorkoutSession session) {
    final theme = AppTheme.of(context);
    final sets = session.exercises.expand((e) => e.sets);
    final completed = sets.where((s) => s.status == SetStatus.completed).length;
    final title = session.exercises
        .map((e) => e.sourcePlanName)
        .whereType<String>()
        .toSet()
        .join(' · ');
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.s8),
      child: Material(
        color: theme.colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radii.lg),
          side: BorderSide(
            color: theme.colors.outline,
            width: theme.borders.thin,
          ),
        ),
        child: InkWell(
          key: ValueKey('calendar-session-${session.id}'),
          onTap: () => context.push(
            '/history/${session.workoutDate.iso8601}?session=${Uri.encodeQueryComponent(session.id)}',
          ),
          // Flutter: Column, mainAxis: start, crossAxis: stretch
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.s14,
                  theme.spacing.s14,
                  theme.spacing.s14,
                  theme.spacing.s10,
                ),
                // Flutter: Column, mainAxis: start, crossAxis: stretch
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Flutter: Row, mainAxis: spaceBetween, crossAxis: start
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          // Flutter: Column, mainAxis: start, crossAxis: start
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? AppStrings.freeWorkout : title,
                                style: TextStyle(
                                  fontSize: theme.typography.base,
                                  color: theme.colors.text,
                                  fontWeight: theme.typography.bold,
                                ),
                              ),
                              // Spacer: spacing.2 -> SizedBox(height: spacing.2)
                              SizedBox(height: theme.spacing.s2),
                              Text(
                                '${AppStrings.historyDuration(session.timer.accumulatedActiveSeconds)} · ${AppStrings.exerciseCompletion(completed, sets.length)}',
                                style: TextStyle(
                                  fontSize: theme.typography.xxs,
                                  color: theme.colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Spacer: spacing.8 -> SizedBox(width: spacing.8)
                        SizedBox(width: theme.spacing.s8),
                        _chip(
                          session.phase == WorkoutPhase.saved
                              ? AppStrings.savedWorkoutComplete
                              : AppStrings.unfinishedWorkout,
                          status: session.phase,
                        ),
                      ],
                    ),
                    // Spacer: spacing.8 -> SizedBox(height: spacing.8)
                    SizedBox(height: theme.spacing.s8),
                    // Flutter: Wrap, mainAxis: start, crossAxis: center
                    Wrap(
                      spacing: theme.spacing.s4,
                      runSpacing: theme.spacing.s4,
                      children: [
                        for (final exercise in session.exercises
                            .take(HistorySkin.previewExerciseLimit))
                          _chip(exercise.nameSnapshot),
                        if (session.exercises.length >
                            HistorySkin.previewExerciseLimit)
                          _chip(
                            AppStrings.remainingExercises(
                              session.exercises.length -
                                  HistorySkin.previewExerciseLimit,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                key: ValueKey('calendar-history-footer-${session.id}'),
                decoration: BoxDecoration(
                  color: theme.colors.inputSurface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colors.outline,
                      width: theme.borders.thin,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.s14,
                    vertical: theme.spacing.s8,
                  ),
                  // Flutter: Row, mainAxis: spaceBetween, crossAxis: center
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.viewFullHistory,
                          style: TextStyle(
                            fontSize: theme.typography.xxs,
                            color: theme.colors.textMuted,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: theme.typography.md,
                        color: theme.colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {WorkoutPhase? status}) {
    final theme = AppTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status == null
            ? theme.colors.inputSurface
            : status == WorkoutPhase.saved
                ? theme.colors.mintSurface
                : HistorySkin.unfinishedSurface,
        borderRadius: BorderRadius.circular(theme.radii.full),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.s8,
          vertical: HistorySkin.chipVerticalPadding,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: theme.typography.xxs,
            fontWeight: status == null
                ? theme.typography.regular
                : theme.typography.bold,
            color: status == null
                ? theme.colors.textMuted
                : status == WorkoutPhase.saved
                    ? theme.colors.mintText
                    : HistorySkin.unfinishedText,
          ),
        ),
      ),
    );
  }

  Widget _recent() => ref.watch(recentHistoryProvider).when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => TextButton(
          onPressed: () => ref.invalidate(recentHistoryProvider),
          child: const Text(AppStrings.retry),
        ),
        // Flutter: Column, mainAxis: start, crossAxis: stretch
        data: (sessions) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.recentTraining,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // Spacer: spacing.10 -> SizedBox(height: spacing.10)
            SizedBox(height: AppTheme.of(context).spacing.s10),
            if (sessions.isEmpty) const Text(AppStrings.noWorkoutHistory),
            for (final session in sessions) RecentHistoryCard(session: session),
          ],
        ),
      );
}
