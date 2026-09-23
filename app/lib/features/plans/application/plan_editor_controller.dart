import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/local_date.dart';
import '../../../l10n/app_strings.dart';
import '../../exercises/domain/exercise.dart';
import '../domain/plan.dart';
import '../domain/plan_day.dart';
import '../domain/plan_repository.dart';
import '../domain/plan_revision.dart';
import '../domain/plan_schedule.dart';

String newPlanId() => List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

/// Immutable Riverpod editor state; all commands change draft only until save.
class PlanDraft {
  const PlanDraft({
    required this.startDate,
    required this.endDate,
    this.planId,
    this.name = '',
    this.cycleLength = 7,
    this.execMode = PlanMode.infinite,
    this.loopCount = 12,
    this.priority = 0,
    this.enabled = true,
    this.selectedDayIndex = 0,
    this.days = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.failure,
    this.previous,
    this.isDirty = false,
  });
  final String? planId;
  final String name;
  final int cycleLength, loopCount, priority, selectedDayIndex;
  final PlanMode execMode;
  final LocalDate startDate, endDate;
  final bool enabled, isLoading, isSaving, isDirty;
  final List<PlanDay> days;
  final AppFailure? failure;
  final PlanRevision? previous;
  bool get requiresEffectiveDate =>
      previous != null && previous!.cycleDays != cycleLength;
  LocalDate get anchor => previous != null && !requiresEffectiveDate
      ? previous!.cycleAnchorDate
      : startDate;
  LocalDate? get computedEndDate => execMode == PlanMode.infinite
      ? null
      : execMode == PlanMode.cycles
          ? anchor.addDays(cycleLength * loopCount - 1)
          : endDate;
  (int, int) get rangeSummary {
    final length = calendarDayDifference(startDate, endDate) + 1;
    return (length ~/ cycleLength, length % cycleLength);
  }

  PlanDraft copyWith({
    String? planId,
    String? name,
    int? cycleLength,
    PlanMode? execMode,
    int? loopCount,
    LocalDate? startDate,
    LocalDate? endDate,
    int? priority,
    bool? enabled,
    int? selectedDayIndex,
    List<PlanDay>? days,
    bool? isLoading,
    bool? isSaving,
    AppFailure? failure,
    PlanRevision? previous,
    bool? isDirty,
  }) =>
      PlanDraft(
        planId: planId ?? this.planId,
        name: name ?? this.name,
        cycleLength: cycleLength ?? this.cycleLength,
        execMode: execMode ?? this.execMode,
        loopCount: loopCount ?? this.loopCount,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        priority: priority ?? this.priority,
        enabled: enabled ?? this.enabled,
        selectedDayIndex: selectedDayIndex ?? this.selectedDayIndex,
        days: List.unmodifiable(days ?? this.days),
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        failure: failure,
        previous: previous ?? this.previous,
        isDirty: isDirty ?? this.isDirty,
      );
}

class PlanEditorController extends StateNotifier<PlanDraft> {
  PlanEditorController(this.repository, this.clock)
      : super(
          PlanDraft(
            startDate: clock.today(),
            endDate: clock.today().addDays(83),
          ),
        );
  final PlanRepository repository;
  final Clock clock;
  Plan? _plan;

  /// Restore this route's entry snapshot, retaining edits from its parent route.
  void restoreDraft(PlanDraft checkpoint) {
    if (!state.isSaving && checkpoint.planId == state.planId) {
      state = checkpoint;
    }
  }

  Future<void> open(String? planId) async {
    state = state.copyWith(isLoading: true);
    try {
      _plan = planId == null ? null : await repository.find(planId);
      if (planId != null && _plan == null) {
        throw const AppFailure(FailureCode.notFound);
      }
      final previous =
          planId == null ? null : (await repository.revisions(planId)).last;
      if (!mounted) return;
      final start = previous?.effectiveFrom ?? clock.today();
      final length = previous?.cycleDays ?? 7;
      final current = previous == null
          ? null
          : PlanSchedule.dayFor(_plan!, [previous], clock.today());
      state = PlanDraft(
        selectedDayIndex: current == null ? 0 : current.day.dayNumber - 1,
        planId: _plan?.id,
        name: _plan?.name ?? '',
        startDate: start,
        endDate: previous?.endDate ?? start.addDays(83),
        cycleLength: length,
        execMode: previous?.mode ?? PlanMode.infinite,
        loopCount: previous?.cycleCount ?? 12,
        priority: _plan?.priority ?? 0,
        enabled: _plan?.enabled ?? true,
        previous: previous,
        isLoading: false,
        days: previous?.days ?? List.generate(length, _emptyDay),
      );
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isLoading: false, failure: _failure(error));
      }
    }
  }

  PlanDay _emptyDay(int index) => PlanDay(
        id: newPlanId(),
        dayNumber: index + 1,
        name: AppStrings.dayLabel(index + 1),
        isRest: false,
        exercises: const [],
      );

  void updateBasics({
    String? name,
    int? cycleLength,
    PlanMode? execMode,
    int? loopCount,
    LocalDate? startDate,
    LocalDate? endDate,
    int? priority,
    bool? enabled,
  }) {
    if (state.isSaving) return;
    if (cycleLength != null && (cycleLength < 1 || cycleLength > 365)) {
      throw const AppFailure(FailureCode.validation);
    }
    if (loopCount != null && loopCount < 1) {
      throw const AppFailure(FailureCode.validation);
    }
    final length = cycleLength ?? state.cycleLength;
    final days = List.generate(
      length,
      (index) =>
          index < state.days.length ? state.days[index] : _emptyDay(index),
    );
    state = state.copyWith(
      name: name,
      cycleLength: length,
      execMode: execMode,
      loopCount: loopCount,
      startDate: startDate,
      endDate: endDate,
      priority: priority,
      enabled: enabled,
      days: days,
      selectedDayIndex: min(state.selectedDayIndex, length - 1),
      isDirty: true,
    );
  }

  void selectDay(int index) {
    if (index >= 0 && index < state.days.length) {
      state = state.copyWith(selectedDayIndex: index);
    }
  }

  void _day(int index, PlanDay Function(PlanDay) change) {
    if (state.isSaving) return;
    final days = [...state.days];
    days[index] = change(days[index]);
    state = state.copyWith(days: days, isDirty: true);
  }

  PlanDay _withDay(
    PlanDay day, {
    String? name,
    bool? isRest,
    List<PlanExercise>? exercises,
  }) =>
      PlanDay(
        id: day.id,
        dayNumber: day.dayNumber,
        name: name ?? day.name,
        isRest: isRest ?? day.isRest,
        exercises: exercises ?? day.exercises,
      );
  void setDayRest(int index, bool value) => _day(
        index,
        (day) => _withDay(
          day,
          isRest: value,
          exercises: value ? [] : day.exercises,
        ),
      );
  void renameDay(int index, String name) => _day(
        index,
        (day) => _withDay(
          day,
          name: name.trim().isEmpty ? AppStrings.dayLabel(index + 1) : name,
        ),
      );
  void copyDay(int source, int target) {
    final from = state.days[source];
    _day(
      target,
      (day) => _withDay(
        day,
        name: from.name,
        isRest: from.isRest,
        exercises: from.exercises.map(_copyExercise).toList(),
      ),
    );
  }

  PlanExercise _withExercise(
    PlanExercise exercise, {
    String? id,
    String? note,
    int? targetRestSeconds,
    List<PlanSet>? sets,
  }) =>
      PlanExercise(
        id: id ?? exercise.id,
        exerciseId: exercise.exerciseId,
        nameSnapshot: exercise.nameSnapshot,
        note: note ?? exercise.note,
        targetRestSeconds: targetRestSeconds ?? exercise.targetRestSeconds,
        order: exercise.order,
        sets: sets ?? exercise.sets,
      );
  PlanSet _copySet(PlanSet set) => PlanSet(
        id: newPlanId(),
        order: set.order,
        plannedWeight: set.plannedWeight,
        unit: set.unit,
        plannedReps: set.plannedReps,
      );
  PlanExercise _copyExercise(PlanExercise exercise) => _withExercise(
        exercise,
        id: newPlanId(),
        sets: exercise.sets.map(_copySet).toList(),
      );
  void _exercises(
    int index,
    List<PlanExercise> Function(List<PlanExercise>) change,
  ) =>
      _day(index, (day) {
        if (day.isRest) throw const AppFailure(FailureCode.validation);
        return _withDay(day, exercises: change(day.exercises));
      });
  void _exercise(
    int dayIndex,
    String id,
    PlanExercise Function(PlanExercise) change,
  ) =>
      _exercises(
        dayIndex,
        (items) => [
          for (final item in items)
            if (item.id == id) change(item) else item,
        ],
      );
  void addExercise(int dayIndex, Exercise exercise) => _exercises(
        dayIndex,
        (items) => [
          ...items,
          PlanExercise(
            id: newPlanId(),
            exerciseId: exercise.id,
            nameSnapshot: exercise.name,
            note: exercise.note,
            targetRestSeconds: 90,
            order: items.length,
            sets: const [],
          ),
        ],
      );
  void deleteExercise(int dayIndex, String exerciseId) => _exercises(
        dayIndex,
        (items) => items.where((e) => e.id != exerciseId).toList(),
      );
  void copyExercise(int dayIndex, String exerciseId) => _exercises(
        dayIndex,
        (items) => [
          ...items,
          _copyExercise(items.firstWhere((e) => e.id == exerciseId)),
        ],
      );
  List<T> _ordered<T>(
    List<T> items,
    List<String> ids,
    String Function(T) getId,
  ) {
    if (ids.length != items.length ||
        ids.toSet().length != items.length ||
        !items.every((e) => ids.contains(getId(e)))) {
      throw const AppFailure(FailureCode.validation);
    }
    return ids.map((id) => items.firstWhere((e) => getId(e) == id)).toList();
  }

  void reorderExercises(int dayIndex, List<String> ids) =>
      _exercises(dayIndex, (items) => _ordered(items, ids, (e) => e.id));
  void updateExercise(
    int dayIndex,
    String exerciseId, {
    required String note,
    required int targetRestSeconds,
  }) =>
      _exercise(
        dayIndex,
        exerciseId,
        (e) =>
            _withExercise(e, note: note, targetRestSeconds: targetRestSeconds),
      );
  void batchAddSets(
    int dayIndex,
    String exerciseId, {
    required int count,
    required double? weight,
    required WeightUnit unit,
    required int reps,
  }) {
    if (count < 1) throw const AppFailure(FailureCode.validation);
    _exercise(
      dayIndex,
      exerciseId,
      (e) => _withExercise(
        e,
        sets: [
          ...e.sets,
          for (var i = 0; i < count; i++)
            PlanSet(
              id: newPlanId(),
              order: e.sets.length + i,
              plannedWeight: weight ?? 0,
              unit: unit,
              plannedReps: reps,
            ),
        ],
      ),
    );
  }

  void updateSet(
    int dayIndex,
    String exerciseId,
    String setId, {
    required double? weight,
    required WeightUnit unit,
    required int reps,
  }) =>
      _exercise(
        dayIndex,
        exerciseId,
        (e) => _withExercise(
          e,
          sets: [
            for (final s in e.sets)
              if (s.id == setId)
                PlanSet(
                  id: s.id,
                  order: s.order,
                  plannedWeight: weight ?? 0,
                  unit: unit,
                  plannedReps: reps,
                )
              else
                s,
          ],
        ),
      );
  void deleteSet(int dayIndex, String exerciseId, String setId) => _exercise(
        dayIndex,
        exerciseId,
        (e) =>
            _withExercise(e, sets: e.sets.where((s) => s.id != setId).toList()),
      );
  void copySet(int dayIndex, String exerciseId, String setId) => _exercise(
        dayIndex,
        exerciseId,
        (e) => _withExercise(
          e,
          sets: [
            ...e.sets,
            _copySet(e.sets.firstWhere((s) => s.id == setId)),
          ],
        ),
      );
  void reorderSets(int dayIndex, String exerciseId, List<String> ids) =>
      _exercise(
        dayIndex,
        exerciseId,
        (e) => _withExercise(e, sets: _ordered(e.sets, ids, (s) => s.id)),
      );
  Future<bool> save({required LocalDate effectiveFrom}) async {
    if (state.isSaving || state.isLoading) return false;
    state = state.copyWith(isSaving: true);
    try {
      final now = clock.nowUtc();
      final plans = _plan == null ? await repository.list() : const <Plan>[];
      final plan = Plan(
        id: _plan?.id ?? newPlanId(),
        name: state.name,
        enabled: state.enabled,
        priority: state.priority,
        defaultOrder: _plan?.defaultOrder ??
            plans.fold(-1, (int a, b) => max(a, b.defaultOrder)) + 1,
        createdAt: _plan?.createdAt ?? now,
        updatedAt: now,
      );
      final previous = state.previous;
      final revision = previous == null
          ? PlanRevision(
              id: newPlanId(),
              planId: plan.id,
              effectiveFrom: effectiveFrom,
              cycleAnchorDate: effectiveFrom,
              cycleDays: state.cycleLength,
              mode: state.execMode,
              cycleCount:
                  state.execMode == PlanMode.cycles ? state.loopCount : null,
              endDate:
                  state.execMode == PlanMode.dateRange ? state.endDate : null,
              days: state.days,
            )
          : previous.revised(
              id: newPlanId(),
              effectiveFrom: effectiveFrom,
              cycleDays: state.cycleLength,
              mode: state.execMode,
              cycleCount: state.loopCount,
              endDate: state.endDate,
              days: state.days,
            );
      await repository.save(plan, revision);
      _plan = plan;
      if (mounted) {
        state = state.copyWith(
          planId: plan.id,
          previous: revision,
          startDate: effectiveFrom,
          isSaving: false,
          isDirty: false,
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        state = state.copyWith(isSaving: false, failure: _failure(error));
      }
      return false;
    }
  }

  AppFailure _failure(Object error) => error is AppFailure
      ? error
      : AppFailure(
          error is ArgumentError
              ? FailureCode.validation
              : FailureCode.persistence,
        );
}
