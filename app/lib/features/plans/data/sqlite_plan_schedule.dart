import 'package:sqflite/sqflite.dart';

import '../../../core/domain/local_date.dart';
import '../domain/plan.dart';
import '../domain/plan_revision.dart';
import '../domain/plan_schedule.dart';
import 'sqlite_plan_repository.dart';

/// One transaction snapshot of plan templates, reusable for all days in a month.
final class SqlitePlanSchedule {
  const SqlitePlanSchedule._(this._plans);
  final List<(Plan, List<PlanRevision>)> _plans;

  static Future<SqlitePlanSchedule> read(DatabaseExecutor executor) async {
    final plans = await SqlitePlanRepository.readPlans(executor);
    return SqlitePlanSchedule._([
      for (final plan in plans)
        (plan, await SqlitePlanRepository.readRevisions(executor, plan.id)),
    ]);
  }

  List<ScheduledPlanDay> on(LocalDate date) => [
        for (final (plan, revisions) in _plans)
          if (PlanSchedule.dayFor(plan, revisions, date)
              case final ScheduledPlanDay scheduled)
            scheduled,
      ];
}
