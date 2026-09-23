import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/sql_values.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/local_date.dart';
import '../../exercises/domain/exercise.dart';
import '../domain/plan.dart';
import '../domain/plan_day.dart';
import '../domain/plan_repository.dart';
import '../domain/plan_revision.dart';

final class SqlitePlanRepository implements PlanRepository {
  const SqlitePlanRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<Plan>> list() => databaseGuard(() => readPlans(_db.database));

  @override
  Future<Plan?> find(String id) => databaseGuard(() async {
        final rows =
            await _db.database.query('plans', where: 'id = ?', whereArgs: [id]);
        return rows.isEmpty ? null : _readPlan(rows.single);
      });

  @override
  Future<List<PlanRevision>> revisions(String id) =>
      _db.transaction((tx) => readRevisions(tx, id));

  @override
  Future<void> save(Plan plan, PlanRevision revision) =>
      _db.transaction((tx) async {
        if (plan.id != revision.planId) {
          throw const AppFailure(
            FailureCode.validation,
            detail: 'Revision belongs to another plan.',
          );
        }
        final existing = await readRevisions(tx, plan.id);
        final previous = existing.lastOrNull;
        if (previous != null) {
          if (revision.effectiveFrom.compareTo(previous.effectiveFrom) < 0) {
            throw const AppFailure(
              FailureCode.validation,
              detail: 'Use the latest revision or a new effective date.',
            );
          }
          final expectedAnchor = revision.cycleDays == previous.cycleDays
              ? previous.cycleAnchorDate
              : revision.effectiveFrom;
          if (revision.cycleAnchorDate != expectedAnchor) {
            throw const AppFailure(
              FailureCode.validation,
              detail:
                  'Cycle length changes reset D1; other edits preserve the anchor.',
            );
          }
          if (revision.effectiveFrom == previous.effectiveFrom) {
            final references = await tx.query(
              'workout_revision_references',
              columns: ['session_id'],
              where: 'revision_id = ?',
              whereArgs: [previous.id],
              limit: 1,
            );
            if (references.isNotEmpty) {
              throw const AppFailure(
                FailureCode.conflict,
                detail:
                    'This revision has been used by training. Choose a new effective date.',
              );
            }
            await tx.delete(
              'plan_revisions',
              where: 'id = ?',
              whereArgs: [previous.id],
            );
          }
        }
        // UPDATE instead of REPLACE avoids cascading away older revisions.
        final updated = await tx.update(
          'plans',
          _planRow(plan),
          where: 'id = ?',
          whereArgs: [plan.id],
        );
        if (updated == 0) await tx.insert('plans', _planRow(plan));
        await _insertRevision(tx, revision);
      });

  @override
  Future<void> setEnabled(String id, bool enabled) => databaseGuard(() async {
        final changed = await _db.database.update(
          'plans',
          {
            'enabled': enabled ? 1 : 0,
            'updated_at': utcValue(DateTime.now().toUtc()),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        if (changed == 0) throw const AppFailure(FailureCode.notFound);
      });

  @override
  Future<void> delete(String id) => _db.transaction((tx) async {
        await tx.delete('plans', where: 'id = ?', whereArgs: [id]);
      });

  /// Copies the latest stored template, preserving its execution duration.
  @override
  Future<Plan> duplicate(
    String id, {
    required String newId,
    required LocalDate startsOn,
  }) =>
      _db.transaction((tx) async {
        final rows = await tx.query('plans', where: 'id = ?', whereArgs: [id]);
        if (rows.isEmpty) throw const AppFailure(FailureCode.notFound);
        final source = _readPlan(rows.single);
        final revisions = await readRevisions(tx, id);
        if (revisions.isEmpty) throw const AppFailure(FailureCode.notFound);
        if ((await tx.query(
          'plans',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [newId],
        ))
            .isNotEmpty) {
          throw const AppFailure(FailureCode.duplicate);
        }
        final template = revisions.last;
        final now = DateTime.now().toUtc();
        final plan = Plan(
          id: newId,
          name: '${source.name} 副本',
          enabled: source.enabled,
          priority: source.priority,
          defaultOrder: source.defaultOrder + 1,
          createdAt: now,
          updatedAt: now,
        );
        final copy = PlanRevision(
          id: _newId(),
          planId: newId,
          effectiveFrom: startsOn,
          cycleAnchorDate: startsOn,
          cycleDays: template.cycleDays,
          mode: template.mode,
          cycleCount: template.cycleCount,
          endDate: template.endDate == null
              ? null
              : startsOn.addDays(
                  calendarDayDifference(
                    template.effectiveFrom,
                    template.endDate!,
                  ),
                ),
          days: [
            for (final day in template.days)
              PlanDay(
                id: _newId(),
                dayNumber: day.dayNumber,
                name: day.name,
                isRest: day.isRest,
                exercises: [
                  for (final exercise in day.exercises)
                    PlanExercise(
                      id: _newId(),
                      exerciseId: exercise.exerciseId,
                      nameSnapshot: exercise.nameSnapshot,
                      note: exercise.note,
                      targetRestSeconds: exercise.targetRestSeconds,
                      order: exercise.order,
                      sets: [
                        for (final set in exercise.sets)
                          PlanSet(
                            id: _newId(),
                            order: set.order,
                            plannedWeight: set.plannedWeight,
                            unit: set.unit,
                            plannedReps: set.plannedReps,
                          ),
                      ],
                    ),
                ],
              ),
          ],
        );
        await tx.insert('plans', _planRow(plan));
        await _insertRevision(tx, copy);
        return plan;
      });

  // Data-only aggregate readers let Today/History share one read transaction.
  static Future<List<Plan>> readPlans(DatabaseExecutor executor) async =>
      (await executor.query(
        'plans',
        orderBy: 'priority DESC, default_order, id',
      ))
          .map(_readPlan)
          .toList(growable: false);

  static Future<List<PlanRevision>> readRevisions(
    DatabaseExecutor executor,
    String planId,
  ) async {
    final rows = await executor.query(
      'plan_revisions',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'effective_from',
    );
    final result = <PlanRevision>[];
    for (final row in rows) {
      final revisionId = row['id'] as String;
      final dayRows = await executor.query(
        'plan_days',
        where: 'revision_id = ?',
        whereArgs: [revisionId],
        orderBy: 'day_number',
      );
      final days = <PlanDay>[];
      for (final day in dayRows) {
        final dayId = day['id'] as String;
        final exerciseRows = await executor.query(
          'plan_exercises',
          where: 'revision_id = ? AND day_id = ?',
          whereArgs: [revisionId, dayId],
          orderBy: 'sort_order',
        );
        final exercises = <PlanExercise>[];
        for (final exercise in exerciseRows) {
          final setRows = await executor.query(
            'plan_sets',
            where: 'revision_id = ? AND day_id = ? AND exercise_id = ?',
            whereArgs: [revisionId, dayId, exercise['id']],
            orderBy: 'sort_order',
          );
          exercises.add(
            PlanExercise(
              id: exercise['id'] as String,
              exerciseId: exercise['exercise_id'] as String,
              nameSnapshot: exercise['name_snapshot'] as String,
              note: exercise['note'] as String,
              targetRestSeconds: exercise['target_rest_seconds'] as int,
              order: exercise['sort_order'] as int,
              sets: [
                for (final set in setRows)
                  PlanSet(
                    id: set['id'] as String,
                    order: set['sort_order'] as int,
                    plannedWeight: (set['planned_weight'] as num).toDouble(),
                    unit: WeightUnit.fromCode(set['unit'] as String),
                    plannedReps: set['planned_reps'] as int,
                  ),
              ],
            ),
          );
        }
        days.add(
          PlanDay(
            id: dayId,
            dayNumber: day['day_number'] as int,
            name: day['name'] as String,
            isRest: day['is_rest'] == 1,
            exercises: exercises,
          ),
        );
      }
      result.add(
        PlanRevision(
          id: revisionId,
          planId: planId,
          effectiveFrom: readDate(row['effective_from']),
          cycleAnchorDate: readDate(row['cycle_anchor_date']),
          cycleDays: row['cycle_days'] as int,
          mode: PlanMode.values.byName(row['mode'] as String),
          cycleCount: row['cycle_count'] as int?,
          endDate: row['end_date'] == null ? null : readDate(row['end_date']),
          days: days,
        ),
      );
    }
    return result;
  }

  static Future<void> _insertRevision(
    DatabaseExecutor tx,
    PlanRevision revision,
  ) async {
    await tx.insert('plan_revisions', {
      'id': revision.id,
      'plan_id': revision.planId,
      'effective_from': revision.effectiveFrom.iso8601,
      'cycle_anchor_date': revision.cycleAnchorDate.iso8601,
      'cycle_days': revision.cycleDays,
      'mode': revision.mode.name,
      'cycle_count': revision.cycleCount,
      'end_date': revision.endDate?.iso8601,
    });
    for (final day in revision.days) {
      await tx.insert('plan_days', {
        'revision_id': revision.id,
        'id': day.id,
        'day_number': day.dayNumber,
        'name': day.name,
        'is_rest': day.isRest ? 1 : 0,
      });
      for (final (position, exercise) in day.exercises.indexed) {
        await tx.insert('plan_exercises', {
          'revision_id': revision.id,
          'day_id': day.id,
          'id': exercise.id,
          'exercise_id': exercise.exerciseId,
          'name_snapshot': exercise.nameSnapshot,
          'note': exercise.note,
          'target_rest_seconds': exercise.targetRestSeconds,
          'sort_order': position,
        });
        for (final (position, set) in exercise.sets.indexed) {
          await tx.insert('plan_sets', {
            'revision_id': revision.id,
            'day_id': day.id,
            'exercise_id': exercise.id,
            'id': set.id,
            'sort_order': position,
            'planned_weight': set.plannedWeight,
            'unit': set.unit.code,
            'planned_reps': set.plannedReps,
          });
        }
      }
    }
  }

  static Map<String, Object?> _planRow(Plan plan) => {
        'id': plan.id,
        'name': plan.name,
        'enabled': plan.enabled ? 1 : 0,
        'priority': plan.priority,
        'default_order': plan.defaultOrder,
        'created_at': utcValue(plan.createdAt),
        'updated_at': utcValue(plan.updatedAt),
      };

  static Plan _readPlan(Map<String, Object?> row) => Plan(
        id: row['id'] as String,
        name: row['name'] as String,
        enabled: row['enabled'] == 1,
        priority: row['priority'] as int,
        defaultOrder: row['default_order'] as int,
        createdAt: readUtc(row['created_at'])!,
        updatedAt: readUtc(row['updated_at'])!,
      );
}

String _newId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
