import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan_revision.dart';
import 'package:fitness_counter/features/plans/domain/plan_schedule.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/test_database.dart';

void main() {
  final start = LocalDate(2026, 9, 1);
  final later = LocalDate(2026, 9, 15);
  final conflict = throwsA(
    isA<AppFailure>().having((e) => e.code, 'code', FailureCode.conflict),
  );

  test(
      'revision trees roundtrip all modes and select historical effective dates',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqlitePlanRepository(db);
    final plan = catalogPlan();
    final first = catalogRevision(
      effectiveFrom: start,
      mode: PlanMode.cycles,
      cycleCount: 10,
    );
    await repo.save(plan, first);
    await repo.save(
      plan,
      first.revised(
        id: 'r2',
        effectiveFrom: later,
        mode: PlanMode.dateRange,
        endDate: LocalDate(2026, 10, 1),
      ),
    );
    final all = await repo.revisions('p1');
    expect(all, hasLength(2));
    expect(all.first.cycleCount, 10);
    expect(all.last.endDate, LocalDate(2026, 10, 1));
    expect(all.last.cycleAnchorDate, start);
    expect(
      PlanSchedule.dayFor(plan, all, LocalDate(2026, 9, 14))!.revision.id,
      'r1',
    );
    expect(PlanSchedule.dayFor(plan, all, later)!.day.dayNumber, 3);
    final exercise = all.last.days.first.exercises.single;
    expect(exercise.nameSnapshot, '哑铃卧推');
    expect(exercise.exerciseId, 'x1');
    expect(exercise.targetRestSeconds, 90);
    expect(exercise.sets.single.plannedWeight, 20);
    expect(exercise.sets.single.plannedReps, 8);
    await repo.setEnabled('p1', false);
    expect((await repo.find('p1'))!.enabled, isFalse);
    expect((await repo.list()).single.id, 'p1');
  });

  test(
      'same date replaces unused revision atomically but enforces anchor transitions',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqlitePlanRepository(db);
    final plan = catalogPlan();
    await repo.save(plan, catalogRevision(effectiveFrom: start));
    await repo.save(
      plan,
      catalogRevision(id: 'replacement', effectiveFrom: start, cycleDays: 2),
    );
    expect((await repo.revisions('p1')).single.id, 'replacement');
    await expectLater(
      repo.save(
        plan,
        catalogRevision(
          id: 'wrong-anchor',
          effectiveFrom: later,
          cycleDays: 2,
        ),
      ),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', FailureCode.validation),
      ),
    );
    await expectLater(
      repo.save(
        plan,
        catalogRevision(
          id: 'wrong-reset',
          effectiveFrom: later,
          anchor: start,
          cycleDays: 4,
        ),
      ),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', FailureCode.validation),
      ),
    );
    await repo.save(
      plan,
      catalogRevision(id: 'new-cycle', effectiveFrom: later, cycleDays: 4),
    );
    expect(
      PlanSchedule.dayFor(plan, await repo.revisions('p1'), later)!
          .day
          .dayNumber,
      1,
    );
  });

  test(
      'any started snapshot reference blocks same-date replacement even after adjustment',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final plans = SqlitePlanRepository(db);
    final workouts = SqliteWorkoutRepository(db);
    final plan = catalogPlan(id: 'plan-1');
    await plans.save(
      plan,
      catalogRevision(
        id: 'revision-1',
        planId: 'plan-1',
        effectiveFrom: start,
      ),
    );
    var session = newSession();
    await workouts.create(session);
    session = session.copyWith(exercises: []);
    await workouts.save(session, expectedRevision: 0);
    await expectLater(
      plans.save(
        plan,
        catalogRevision(
          id: 'replacement',
          planId: 'plan-1',
          effectiveFrom: start,
        ),
      ),
      conflict,
    );
    expect((await plans.revisions('plan-1')).single.id, 'revision-1');
    await plans.save(
      plan,
      catalogRevision(
        id: 'new-date',
        planId: 'plan-1',
        effectiveFrom: later,
        anchor: start,
      ),
    );
    expect(await plans.revisions('plan-1'), hasLength(2));
  });

  test(
      'plan tree write failure rolls back identity and entire previous revision',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqlitePlanRepository(db);
    await repo.save(catalogPlan(), catalogRevision(effectiveFrom: start));
    await db.database.execute(
      "CREATE TRIGGER fail_plan_set BEFORE INSERT ON plan_sets BEGIN SELECT RAISE(ABORT, 'disk write failed'); END",
    );
    await expectLater(
      repo.save(
        catalogPlan(enabled: false),
        catalogRevision(id: 'new', effectiveFrom: start),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect((await repo.find('p1'))!.enabled, isTrue);
    expect((await repo.revisions('p1')).single.id, 'r1');
    expect((await repo.revisions('p1')).single.days, hasLength(3));
  });

  test(
      'duplicate creates independent IDs at every level and rebases date range',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqlitePlanRepository(db);
    final original = catalogRevision(
      effectiveFrom: start,
      mode: PlanMode.dateRange,
      endDate: LocalDate(2026, 9, 10),
    );
    await repo.save(catalogPlan(), original);
    final copy = await repo.duplicate('p1', newId: 'copy', startsOn: later);
    final revision = (await repo.revisions(copy.id)).single;
    expect(copy.id, 'copy');
    expect(revision.id, isNot('r1'));
    expect(revision.effectiveFrom, later);
    expect(revision.cycleAnchorDate, later);
    expect(revision.endDate, LocalDate(2026, 9, 24));
    expect(revision.days.map((d) => d.id).toSet(), hasLength(3));
    for (final day in revision.days) {
      expect(original.days.map((d) => d.id), isNot(contains(day.id)));
      expect(day.exercises.single.id, isNot('pe1'));
      expect(day.exercises.single.sets.single.id, isNot('s1'));
      expect(day.exercises.single.exerciseId, 'x1');
    }
    await repo.delete('p1');
    expect(await repo.revisions('p1'), isEmpty);
    expect((await repo.revisions('copy')).single.days, hasLength(3));
  });
}
