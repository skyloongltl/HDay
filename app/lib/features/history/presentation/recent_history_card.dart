import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/history_skin.dart';
import '../../workout/domain/workout_draft.dart';
import '../../workout/domain/workout_session.dart';

/// Flutter: Card + InkWell; the full date/summary row opens its saved session.
final class RecentHistoryCard extends StatelessWidget {
  const RecentHistoryCard({required this.session, super.key});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final date = session.workoutDate;
    final plans = session.exercises
        .map((e) => e.sourcePlanName)
        .whereType<String>()
        .toSet()
        .join(' · ');
    final completed = session.exercises
        .expand((e) => e.sets)
        .where((set) => set.status == SetStatus.completed)
        .length;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.s8),
      child: Material(
        key: ValueKey('recent-history-${session.id}'),
        color: theme.colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radii.md),
          side: BorderSide(
            color: theme.colors.outline,
            width: theme.borders.thin,
          ),
        ),
        child: InkWell(
          onTap: () => context.push(
            '/history/${date.iso8601}?session=${Uri.encodeQueryComponent(session.id)}',
          ),
          child: Semantics(
            label: date.iso8601,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: theme.minTapTarget),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.s14,
                  vertical: theme.spacing.s12,
                ),
                // Flutter: Row, mainAxis: start, crossAxis: center
                child: Row(
                  children: [
                    SizedBox(
                      key: ValueKey('recent-date-${session.id}'),
                      width: theme.spacing.s40,
                      // Flutter: Column, mainAxis: start, crossAxis: center
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: theme.typography.lg,
                              fontWeight: theme.typography.heavy,
                              color: theme.colors.text,
                            ),
                          ),
                          Text(
                            AppStrings.historyWeekday(
                              DateTime.utc(date.year, date.month, date.day)
                                  .weekday,
                            ),
                            style: TextStyle(
                              fontSize: theme.typography.xxs,
                              color: theme.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Spacer: spacing.12 -> SizedBox(width: spacing.12)
                    SizedBox(width: theme.spacing.s12),
                    SizedBox(
                      key: ValueKey('recent-divider-${session.id}'),
                      width: theme.borders.thin,
                      height: HistorySkin.recentDividerHeight,
                      child: ColoredBox(color: theme.colors.outline),
                    ),
                    // Spacer: spacing.12 -> SizedBox(width: spacing.12)
                    SizedBox(width: theme.spacing.s12),
                    Expanded(
                      // Flutter: Column, mainAxis: start, crossAxis: start
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plans.isEmpty ? AppStrings.freeWorkout : plans,
                            style: TextStyle(
                              fontSize: theme.typography.base,
                              fontWeight: theme.typography.semibold,
                              color: theme.colors.text,
                            ),
                          ),
                          Text(
                            '${AppStrings.historyDuration(session.timer.accumulatedActiveSeconds)} · ${AppStrings.setSummary(completed)}',
                            style: TextStyle(
                              fontSize: theme.typography.xxs,
                              color: theme.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Spacer: spacing.12 -> SizedBox(width: spacing.12)
                    SizedBox(width: theme.spacing.s12),
                    Icon(
                      Icons.chevron_right,
                      size: theme.typography.md,
                      color: theme.colors.textSubtle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
