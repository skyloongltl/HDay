import '../../../core/domain/local_date.dart';
import 'plan_day.dart';

enum PlanMode { infinite, cycles, dateRange }

final class PlanRevision {
  PlanRevision({
    required this.id,
    required this.planId,
    required this.effectiveFrom,
    required this.cycleAnchorDate,
    required this.cycleDays,
    required this.mode,
    this.cycleCount,
    this.endDate,
    required List<PlanDay> days,
  }) : days = List.unmodifiable(days) {
    _requireNonempty(id, 'id');
    _requireNonempty(planId, 'planId');
    if (cycleDays < 1 || cycleDays > 365) {
      throw ArgumentError.value(
        cycleDays,
        'cycleDays',
        'Must be between 1 and 365.',
      );
    }
    if (cycleAnchorDate.compareTo(effectiveFrom) > 0) {
      throw ArgumentError.value(
        cycleAnchorDate,
        'cycleAnchorDate',
        'Must not be after effectiveFrom.',
      );
    }
    if (this.days.length != cycleDays ||
        this.days.indexed.any((entry) => entry.$2.dayNumber != entry.$1 + 1)) {
      throw ArgumentError.value(
        days,
        'days',
        'Must contain ordered day numbers 1 through cycleDays.',
      );
    }
    switch (mode) {
      case PlanMode.infinite:
        if (cycleCount != null || endDate != null) {
          throw ArgumentError('Infinite mode cannot have an end condition.');
        }
      case PlanMode.cycles:
        if (cycleCount == null || cycleCount! < 1 || endDate != null) {
          throw ArgumentError(
            'Cycles mode requires a positive cycleCount only.',
          );
        }
      case PlanMode.dateRange:
        if (endDate == null ||
            endDate!.compareTo(effectiveFrom) < 0 ||
            cycleCount != null) {
          throw ArgumentError(
            'Date-range mode requires an endDate on or after effectiveFrom.',
          );
        }
    }
  }

  final String id;
  final String planId;
  final LocalDate effectiveFrom;
  final LocalDate cycleAnchorDate;
  final int cycleDays;
  final PlanMode mode;
  final int? cycleCount;
  final LocalDate? endDate;
  final List<PlanDay> days;

  PlanRevision revised({
    required String id,
    LocalDate? effectiveFrom,
    int? cycleDays,
    PlanMode? mode,
    int? cycleCount,
    LocalDate? endDate,
    List<PlanDay>? days,
  }) {
    final nextCycleDays = cycleDays ?? this.cycleDays;
    final changesCycleLength = nextCycleDays != this.cycleDays;
    if (changesCycleLength && effectiveFrom == null) {
      throw ArgumentError(
        'Changing cycleDays requires a new effectiveFrom date.',
      );
    }
    if (changesCycleLength && days == null) {
      throw ArgumentError('Changing cycleDays requires replacement days.');
    }
    final nextEffectiveFrom = effectiveFrom ?? this.effectiveFrom;
    if (nextEffectiveFrom.compareTo(this.effectiveFrom) < 0) {
      throw ArgumentError.value(
        nextEffectiveFrom,
        'effectiveFrom',
        'Must not precede the current revision.',
      );
    }
    final nextMode = mode ?? this.mode;
    final nextCycleCount = nextMode == PlanMode.cycles
        ? cycleCount ?? (this.mode == PlanMode.cycles ? this.cycleCount : null)
        : null;
    final nextEndDate = nextMode == PlanMode.dateRange
        ? endDate ?? (this.mode == PlanMode.dateRange ? this.endDate : null)
        : null;

    return PlanRevision(
      id: id,
      planId: planId,
      effectiveFrom: nextEffectiveFrom,
      cycleAnchorDate: changesCycleLength ? nextEffectiveFrom : cycleAnchorDate,
      cycleDays: nextCycleDays,
      mode: nextMode,
      cycleCount: nextCycleCount,
      endDate: nextEndDate,
      days: days ?? this.days,
    );
  }
}

void _requireNonempty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}
