import '../../../core/domain/app_failure.dart';
import '../../../core/domain/local_date.dart';
import 'plan.dart';
import 'plan_day.dart';
import 'plan_revision.dart';

final class ScheduledPlanDay {
  const ScheduledPlanDay({
    required this.plan,
    required this.revision,
    required this.day,
  });

  final Plan plan;
  final PlanRevision revision;
  final PlanDay day;
}

abstract final class PlanSchedule {
  static ScheduledPlanDay? dayFor(
    Plan plan,
    List<PlanRevision> revisions,
    LocalDate date,
  ) {
    if (!plan.enabled) {
      return null;
    }

    final planRevisions = revisions
        .where((revision) => revision.planId == plan.id)
        .toList(growable: false);
    final dates = <LocalDate>{};
    for (final revision in planRevisions) {
      if (!dates.add(revision.effectiveFrom)) {
        throw AppFailure(
          FailureCode.duplicate,
          detail: revision.effectiveFrom.iso8601,
        );
      }
    }

    PlanRevision? active;
    for (final revision in planRevisions) {
      if (revision.effectiveFrom.compareTo(date) <= 0 &&
          (active == null ||
              revision.effectiveFrom.compareTo(active.effectiveFrom) > 0)) {
        active = revision;
      }
    }
    if (active == null || !_isWithinExecution(active, date)) {
      return null;
    }

    final elapsedDays = calendarDayDifference(active.cycleAnchorDate, date);
    final dayNumber = elapsedDays % active.cycleDays + 1;
    final day = active.days[dayNumber - 1];
    return ScheduledPlanDay(plan: plan, revision: active, day: day);
  }

  static bool _isWithinExecution(PlanRevision revision, LocalDate date) {
    final elapsedDays = calendarDayDifference(
      revision.cycleAnchorDate,
      date,
    );
    return switch (revision.mode) {
      PlanMode.infinite => true,
      PlanMode.cycles =>
        elapsedDays < revision.cycleDays * revision.cycleCount!,
      PlanMode.dateRange => date.compareTo(revision.endDate!) <= 0,
    };
  }
}
