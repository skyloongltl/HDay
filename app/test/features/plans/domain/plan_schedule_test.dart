import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/plans/domain/plan_day.dart';
import 'package:fitness_counter/features/plans/domain/plan_revision.dart';
import 'package:fitness_counter/features/plans/domain/plan_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';

void main() {
  test('local date validates calendar days and formats ISO-8601', () {
    expect(LocalDate(2026, 9, 5).iso8601, '2026-09-05');
    expect(() => LocalDate(2026, 2, 29), throwsArgumentError);
  });

  group('natural-day scheduling', () {
    test('cycle-length revision restarts on its effective date only', () {
      final plan = catalogPlan();
      final revisions = [
        catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
        catalogRevision(
          id: 'r2',
          effectiveFrom: LocalDate(2026, 9, 15),
          cycleDays: 5,
        ),
      ];

      expect(
        PlanSchedule.dayFor(
          plan,
          revisions,
          LocalDate(2026, 9, 14),
        )?.day.dayNumber,
        2,
      );
      expect(
        PlanSchedule.dayFor(
          plan,
          revisions,
          LocalDate(2026, 9, 15),
        )?.day.dayNumber,
        1,
      );
    });

    test('a revision with unchanged cycle length preserves its anchor', () {
      final original = catalogRevision(
        effectiveFrom: LocalDate(2026, 9, 1),
      );

      final revised = original.revised(
        id: 'r2',
        effectiveFrom: LocalDate(2026, 9, 15),
      );

      expect(revised.cycleAnchorDate, LocalDate(2026, 9, 1));
      expect(
        PlanSchedule.dayFor(
          catalogPlan(),
          [original, revised],
          LocalDate(2026, 9, 15),
        )?.day.dayNumber,
        3,
      );
    });

    test('changing cycle length requires a new effective date', () {
      final revision = catalogRevision(
        effectiveFrom: LocalDate(2026, 9, 1),
      );

      expect(
        () => revision.revised(id: 'r2', cycleDays: 5),
        throwsArgumentError,
      );
    });

    test('completed-cycle mode stops after its final complete cycle', () {
      final revision = catalogRevision(
        effectiveFrom: LocalDate(2026, 9, 1),
        mode: PlanMode.cycles,
        cycleCount: 2,
      );

      expect(
        PlanSchedule.dayFor(
          catalogPlan(),
          [revision],
          LocalDate(2026, 9, 6),
        )?.day.dayNumber,
        3,
      );
      expect(
        PlanSchedule.dayFor(
          catalogPlan(),
          [revision],
          LocalDate(2026, 9, 7),
        ),
        isNull,
      );
    });

    test('date-range mode includes both endpoints and stops mid-cycle', () {
      final revision = catalogRevision(
        effectiveFrom: LocalDate(2026, 9, 1),
        mode: PlanMode.dateRange,
        endDate: LocalDate(2026, 9, 5),
      );

      expect(
        PlanSchedule.dayFor(
          catalogPlan(),
          [revision],
          LocalDate(2026, 9, 1),
        )?.day.dayNumber,
        1,
      );
      expect(
        PlanSchedule.dayFor(
          catalogPlan(),
          [revision],
          LocalDate(2026, 9, 5),
        )?.day.dayNumber,
        2,
      );
      expect(
        PlanSchedule.dayFor(
          catalogPlan(),
          [revision],
          LocalDate(2026, 9, 6),
        ),
        isNull,
      );
    });

    test('execution modes require their matching termination fields', () {
      expect(
        () => catalogRevision(
          effectiveFrom: LocalDate(2026, 9, 1),
          mode: PlanMode.cycles,
        ),
        throwsArgumentError,
      );
      expect(
        () => catalogRevision(
          effectiveFrom: LocalDate(2026, 9, 1),
          mode: PlanMode.dateRange,
        ),
        throwsArgumentError,
      );
    });

    test('calendar dates advance across leap day without local durations', () {
      final revision = catalogRevision(
        effectiveFrom: LocalDate(2028, 2, 28),
      );

      expect(
        PlanSchedule.dayFor(
          catalogPlan(),
          [revision],
          LocalDate(2028, 2, 29),
        )?.day.dayNumber,
        2,
      );
      expect(
        PlanSchedule.dayFor(
          catalogPlan(),
          [revision],
          LocalDate(2028, 3, 1),
        )?.day.dayNumber,
        3,
      );
      expect(
        calendarDayDifference(
          LocalDate(2026, 3, 13),
          LocalDate(2026, 3, 14),
        ),
        1,
      );
    });

    test('disabled plans and dates before the first revision are absent', () {
      final revision = catalogRevision(
        effectiveFrom: LocalDate(2026, 9, 2),
      );

      expect(
        PlanSchedule.dayFor(
          catalogPlan(enabled: false),
          [revision],
          LocalDate(2026, 9, 2),
        ),
        isNull,
      );
      expect(
        PlanSchedule.dayFor(
          catalogPlan(),
          [revision],
          LocalDate(2026, 9, 1),
        ),
        isNull,
      );
    });

    test('a later revision does not change an earlier date lookup', () {
      final original = catalogRevision(
        effectiveFrom: LocalDate(2026, 9, 1),
      );
      final changed = catalogRevision(
        id: 'r2',
        effectiveFrom: LocalDate(2026, 9, 15),
        cycleDays: 5,
      );

      final scheduled = PlanSchedule.dayFor(
        catalogPlan(),
        [changed, original],
        LocalDate(2026, 9, 14),
      );

      expect(scheduled?.revision.id, 'r1');
      expect(scheduled?.day.dayNumber, 2);
    });

    test('duplicate effective dates are rejected as an invalid timeline', () {
      final date = LocalDate(2026, 9, 1);

      expect(
        () => PlanSchedule.dayFor(
          catalogPlan(),
          [
            catalogRevision(effectiveFrom: date),
            catalogRevision(id: 'r2', effectiveFrom: date),
          ],
          date,
        ),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.code,
            'code',
            FailureCode.duplicate,
          ),
        ),
      );
    });
  });

  group('plan domain invariants', () {
    test('cycle length accepts 1 and 365 but rejects 0 and 366', () {
      expect(
        () => catalogRevision(
          effectiveFrom: LocalDate(2026, 9, 1),
          cycleDays: 1,
        ),
        returnsNormally,
      );
      expect(
        () => catalogRevision(
          effectiveFrom: LocalDate(2026, 9, 1),
          cycleDays: 365,
        ),
        returnsNormally,
      );
      expect(
        () => catalogRevision(
          effectiveFrom: LocalDate(2026, 9, 1),
          cycleDays: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => catalogRevision(
          effectiveFrom: LocalDate(2026, 9, 1),
          cycleDays: 366,
        ),
        throwsArgumentError,
      );
    });

    test('revision requires exactly one numbered day for each cycle day', () {
      expect(
        () => PlanRevision(
          id: 'r1',
          planId: 'p1',
          effectiveFrom: LocalDate(2026, 9, 1),
          cycleAnchorDate: LocalDate(2026, 9, 1),
          cycleDays: 2,
          mode: PlanMode.infinite,
          days: [
            PlanDay(
              id: 'd1',
              dayNumber: 1,
              name: 'D1',
              isRest: false,
              exercises: const [],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('aggregate collections are defensive and unmodifiable', () {
      final sets = [
        PlanSet(
          id: 's1',
          order: 0,
          plannedWeight: 20,
          unit: WeightUnit.kg,
          plannedReps: 8,
        ),
      ];
      final exercise = PlanExercise(
        id: 'pe1',
        exerciseId: 'x1',
        nameSnapshot: '哑铃卧推',
        note: '',
        targetRestSeconds: 90,
        order: 0,
        sets: sets,
      );
      sets.clear();
      final exercises = [exercise];
      final day = PlanDay(
        id: 'd1',
        dayNumber: 1,
        name: 'D1',
        isRest: false,
        exercises: exercises,
      );
      exercises.clear();
      final days = [day];
      final revision = PlanRevision(
        id: 'r1',
        planId: 'p1',
        effectiveFrom: LocalDate(2026, 9, 1),
        cycleAnchorDate: LocalDate(2026, 9, 1),
        cycleDays: 1,
        mode: PlanMode.infinite,
        days: days,
      );
      days.clear();

      expect(revision.days.single.exercises.single.sets, hasLength(1));
      expect(() => revision.days.add(day), throwsUnsupportedError);
      expect(() => day.exercises.add(exercise), throwsUnsupportedError);
      expect(() => exercise.sets.clear(), throwsUnsupportedError);
    });

    test('rest days reject exercises', () {
      final trainingDay = catalogRevision(
        effectiveFrom: LocalDate(2026, 9, 1),
        cycleDays: 1,
      ).days.single;

      expect(
        () => PlanDay(
          id: 'rest',
          dayNumber: 1,
          name: '休息',
          isRest: true,
          exercises: trainingDay.exercises,
        ),
        throwsArgumentError,
      );
    });

    test('planned values and target rest reject invalid values', () {
      PlanSet buildSet({double weight = 20, int reps = 8}) => PlanSet(
            id: 's1',
            order: 0,
            plannedWeight: weight,
            unit: WeightUnit.kg,
            plannedReps: reps,
          );

      expect(() => buildSet(weight: -1), throwsArgumentError);
      expect(() => buildSet(weight: double.infinity), throwsArgumentError);
      expect(() => buildSet(weight: double.nan), throwsArgumentError);
      expect(() => buildSet(reps: 0), throwsArgumentError);
      expect(
        () => PlanExercise(
          id: 'pe1',
          exerciseId: 'x1',
          nameSnapshot: '哑铃卧推',
          note: '',
          targetRestSeconds: -1,
          order: 0,
          sets: [buildSet()],
        ),
        throwsArgumentError,
      );
    });
  });
}
