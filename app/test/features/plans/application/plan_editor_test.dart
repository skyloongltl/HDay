import 'dart:io';

import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/core/domain/clock.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/plans/application/plan_editor_controller.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/domain/plan_revision.dart';
import 'package:fitness_counter/features/plans/domain/plan_schedule.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/test_database.dart';

class PlanTestClock implements Clock {
  @override
  LocalDate today() => LocalDate(2026, 9, 1);
  @override
  DateTime nowUtc() => DateTime.utc(2026, 9, 1, 8);
  @override
  Duration get monotonicElapsed => Duration.zero;
}

void main() {
  final start = LocalDate(2026, 9, 1);
  test('opening existing content selects the current cycle day', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repository = SqlitePlanRepository(db);
    await repository.save(
      catalogPlan(),
      catalogRevision(effectiveFrom: LocalDate(2026, 8, 31)),
    );
    final editor = PlanEditorController(repository, PlanTestClock());
    addTearDown(editor.dispose);
    await editor.open('p1');
    expect(editor.state.selectedDayIndex, 1);
  });
  // Catches off-by-one execution bounds and losing persisted form values.
  test('1, 3 and 365 day plans persist all execution modes with inclusive ends',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('hday-plan-editor-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/plans.db';
    var db = await openTestDatabase(path: path);
    addTearDown(() => db.close());
    var repo = SqlitePlanRepository(db);
    final ids = <String>[];
    for (final entry in [
      (1, PlanMode.infinite),
      (3, PlanMode.cycles),
      (365, PlanMode.dateRange),
    ]) {
      final editor = PlanEditorController(repo, PlanTestClock());
      addTearDown(editor.dispose);
      await editor.open(null);
      editor.updateBasics(
        name: '计划${entry.$1}',
        cycleLength: entry.$1,
        execMode: entry.$2,
        loopCount: 2,
        endDate: LocalDate(2026, 9, 10),
        priority: entry.$1,
      );
      expect(await editor.save(effectiveFrom: start), isTrue);
      ids.add(editor.state.planId!);
      if (entry.$2 == PlanMode.cycles) {
        expect(editor.state.computedEndDate, LocalDate(2026, 9, 6));
      }
      if (entry.$2 == PlanMode.dateRange) {
        expect(editor.state.rangeSummary, (0, 10));
      }
    }
    await db.close();
    db = await openTestDatabase(path: path);
    repo = SqlitePlanRepository(db);
    expect((await repo.list()).map((p) => p.name), ['计划365', '计划3', '计划1']);
    final plan = (await repo.find(ids[1]))!;
    final revisions = await repo.revisions(plan.id);
    expect(
      PlanSchedule.dayFor(plan, revisions, LocalDate(2026, 9, 6)),
      isNotNull,
    );
    expect(PlanSchedule.dayFor(plan, revisions, LocalDate(2026, 9, 7)), isNull);
    expect((await repo.revisions(ids[2])).single.days, hasLength(365));
  });

  // Catches shallow copies, batched aliases, lost edits and order normalization.
  test(
      'batch, copy and reorder commands persist independent day exercise and set trees',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqlitePlanRepository(db);
    final editor = PlanEditorController(repo, PlanTestClock());
    addTearDown(editor.dispose);
    await editor.open(null);
    editor.updateBasics(name: '力量', cycleLength: 3);
    editor.addExercise(0, catalogExercise());
    expect(editor.state.days, hasLength(3));
    final exerciseId = editor.state.days.first.exercises.single.id;
    expect(editor.state.days.first.exercises.single.sets, isEmpty);
    editor.batchAddSets(
      0,
      exerciseId,
      count: 5,
      weight: 32,
      unit: WeightUnit.kg,
      reps: 8,
    );
    final original = editor.state.days.first.exercises.single.sets;
    expect(original.map((s) => s.id).toSet(), hasLength(5));
    editor.updateSet(
      0,
      exerciseId,
      original.first.id,
      weight: 40,
      unit: WeightUnit.lb,
      reps: 6,
    );
    editor.copySet(0, exerciseId, original.first.id);
    editor.deleteSet(0, exerciseId, original.last.id);
    final ordered = editor.state.days.first.exercises.single.sets
        .map((s) => s.id)
        .toList()
        .reversed
        .toList();
    editor.reorderSets(0, exerciseId, ordered);
    editor.updateExercise(0, exerciseId, note: '慢速离心', targetRestSeconds: 120);
    editor.copyExercise(0, exerciseId);
    final copyId = editor.state.days.first.exercises.last.id;
    editor.reorderExercises(0, [copyId, exerciseId]);
    editor.copyDay(0, 1);
    editor.renameDay(1, '上肢');
    editor.setDayRest(2, true);
    expect(await editor.save(effectiveFrom: start), isTrue);
    final persisted = (await repo.revisions(editor.state.planId!)).single;
    expect(persisted.days[0].exercises.map((e) => e.id), [copyId, exerciseId]);
    expect(persisted.days[0].exercises.last.sets.map((s) => s.id), ordered);
    expect(persisted.days[0].exercises.last.sets.first.plannedWeight, 40);
    expect(persisted.days[0].exercises.last.note, '慢速离心');
    expect(persisted.days[0].exercises.last.targetRestSeconds, 120);
    expect(persisted.days[1].name, '上肢');
    final allIds = <String>[];
    for (final day in persisted.days) {
      allIds.add(day.id);
      for (final exercise in day.exercises) {
        allIds.add(exercise.id);
        allIds.addAll(exercise.sets.map((s) => s.id));
      }
    }
    expect(allIds.toSet().length, allIds.length);
    expect(persisted.days.last.isRest, isTrue);
    expect(persisted.days.last.exercises, isEmpty);
    editor.deleteExercise(0, copyId);
    expect(editor.state.days.first.exercises, hasLength(1));
  });

  // Catches accidental restart for ordinary edits and hidden length reset.
  test(
      'same length preserves anchor while changed length uses explicit effective date as D1',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqlitePlanRepository(db);
    await repo.save(catalogPlan(), catalogRevision(effectiveFrom: start));
    final editor = PlanEditorController(repo, PlanTestClock());
    addTearDown(editor.dispose);
    await editor.open('p1');
    editor.updateBasics(name: '修改');
    expect(await editor.save(effectiveFrom: LocalDate(2026, 9, 5)), isTrue);
    var revisions = await repo.revisions('p1');
    expect(revisions.last.cycleAnchorDate, start);
    expect(
      PlanSchedule.dayFor(
        (await repo.find('p1'))!,
        revisions,
        LocalDate(2026, 9, 5),
      )!
          .day
          .dayNumber,
      2,
    );
    editor.updateBasics(cycleLength: 4);
    expect(editor.state.requiresEffectiveDate, isTrue);
    expect(await editor.save(effectiveFrom: LocalDate(2026, 9, 8)), isTrue);
    revisions = await repo.revisions('p1');
    expect(revisions.last.cycleAnchorDate, LocalDate(2026, 9, 8));
    expect(
      PlanSchedule.dayFor(
        (await repo.find('p1'))!,
        revisions,
        LocalDate(2026, 9, 8),
      )!
          .day
          .dayNumber,
      1,
    );
  });

  // Catches losing the draft or navigating as if failed writes succeeded.
  test(
      'used revision conflict and SQLite failure keep editable drafts for retry',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqlitePlanRepository(db);
    await repo.save(
      catalogPlan(id: 'plan-1'),
      catalogRevision(
        id: 'revision-1',
        planId: 'plan-1',
        effectiveFrom: start,
      ),
    );
    await SqliteWorkoutRepository(db).create(newSession());
    final editor = PlanEditorController(repo, PlanTestClock());
    addTearDown(editor.dispose);
    await editor.open('plan-1');
    editor.updateBasics(name: '保留输入');
    expect(await editor.save(effectiveFrom: start), isFalse);
    expect(editor.state.failure?.code, FailureCode.conflict);
    expect(editor.state.name, '保留输入');
    await db.database.execute(
      "CREATE TRIGGER fail_plan BEFORE INSERT ON plan_sets BEGIN SELECT RAISE(ABORT, 'disk'); END",
    );
    expect(await editor.save(effectiveFrom: LocalDate(2026, 9, 2)), isFalse);
    expect(editor.state.name, '保留输入');
    expect((await repo.find('plan-1'))!.name, '三日训练计划');
    await db.database.execute('DROP TRIGGER fail_plan');
    expect(await editor.save(effectiveFrom: LocalDate(2026, 9, 2)), isTrue);
    expect((await repo.find('plan-1'))!.name, '保留输入');
  });
}
