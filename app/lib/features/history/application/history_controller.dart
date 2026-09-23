import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/domain/local_date.dart';
import '../../settings/data/sqlite_settings_repository.dart';
import '../../settings/domain/app_settings.dart';
import '../../today/application/today_providers.dart';
import '../../workout/domain/workout_session.dart';
import '../domain/history_models.dart';
import 'history_providers.dart';

final class HistoryState {
  const HistoryState({
    required this.selectedDate,
    required this.currentMonth,
    required this.weekStart,
    required this.month,
    required this.sessions,
    this.isSaving = false,
    this.failure,
  });
  final LocalDate selectedDate;
  final LocalDate currentMonth;
  final WeekStart weekStart;
  final List<CalendarDaySummary> month;
  final List<WorkoutSession> sessions;
  final bool isSaving;
  final Object? failure;
  HistoryState writing({bool isSaving = false, Object? failure}) =>
      HistoryState(
        selectedDate: selectedDate,
        currentMonth: currentMonth,
        weekStart: weekStart,
        month: month,
        sessions: sessions,
        isSaving: isSaving,
        failure: failure,
      );
}

/// Committed repository snapshots are the only published records. Editors own
/// drafts until a successful write; a failed write never replaces these values.
final class HistoryController extends AsyncNotifier<HistoryState> {
  // Requested navigation is separate from the committed dates in HistoryState.
  late LocalDate _requestedDate;
  late LocalDate _requestedMonth;
  int _request = 0;
  bool _disposed = false;

  @override
  Future<HistoryState> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _requestedDate = ref.watch(clockProvider).today();
    _requestedMonth = LocalDate(_requestedDate.year, _requestedDate.month, 1);
    return _read();
  }

  Future<HistoryState> _read() async {
    final date = _requestedDate;
    final month = _requestedMonth;
    final repository = await ref.read(historyRepositoryProvider.future);
    final settings = await SqliteSettingsRepository(
      await ref.read(appDatabaseProvider.future),
    ).read();
    return HistoryState(
      selectedDate: date,
      currentMonth: month,
      weekStart: settings.weekStart,
      month: await repository.month(month),
      sessions: await repository.day(date),
    );
  }

  Future<void> reload() async {
    final request = ++_request;
    try {
      final next = await _read();
      if (!_disposed && request == _request) state = AsyncData(next);
    } catch (error, trace) {
      if (!_disposed && request == _request) {
        // A failed read is not a committed snapshot for the requested date.
        state = AsyncError(error, trace);
      }
    }
  }

  Future<void> loadMonth(LocalDate value) async {
    _requestedMonth = LocalDate(value.year, value.month, 1);
    _requestedDate = _requestedMonth;
    await reload();
  }

  Future<void> loadDay(LocalDate value) async {
    _requestedDate = value;
    _requestedMonth = LocalDate(value.year, value.month, 1);
    await reload();
  }

  Future<bool> correctSet(
    String sessionId,
    String setId, {
    required double? weight,
    required int reps,
  }) =>
      _write(
        () async => (await ref.read(historyRepositoryProvider.future))
            .correctSet(sessionId, setId, weight: weight, reps: reps),
      );
  Future<bool> updateNote(String sessionId, String note) => _write(
        () async => (await ref.read(historyRepositoryProvider.future))
            .updateNote(sessionId, note),
      );
  Future<bool> deleteSession(String id) => _write(
        () async => (await ref.read(historyRepositoryProvider.future))
            .deleteSession(id),
      );

  Future<bool> _write(Future<void> Function() action) async {
    final previous = state.requireValue;
    if (previous.isSaving) return false;
    state = AsyncData(previous.writing(isSaving: true));
    try {
      await action();
    } catch (error) {
      if (!_disposed) state = AsyncData(previous.writing(failure: error));
      return false;
    }
    // A committed write is successful even if a subsequent read needs retry.
    ref.invalidate(todayOverviewProvider);
    ref.invalidate(todayControllerProvider);
    ref.invalidate(exerciseHistorySummaryProvider);
    ref.invalidate(recentHistoryProvider);
    await reload();
    return true;
  }

  static LocalDate shiftMonth(LocalDate value, int delta) =>
      LocalDate.fromDateTime(DateTime.utc(value.year, value.month + delta));
  static List<LocalDate?> monthCells(LocalDate value, WeekStart weekStart) {
    final first = LocalDate(value.year, value.month, 1);
    final weekday = DateTime.utc(first.year, first.month).weekday;
    final offset = (weekday -
            (weekStart == WeekStart.monday
                ? DateTime.monday
                : DateTime.sunday)) %
        DateTime.daysPerWeek;
    final count = calendarDayDifference(first, shiftMonth(first, 1));
    final cells = <LocalDate?>[
      ...List<LocalDate?>.filled(offset, null),
      for (var i = 0; i < count; i++) first.addDays(i),
    ];
    while (cells.length % DateTime.daysPerWeek != 0) {
      cells.add(null);
    }
    return List.unmodifiable(cells);
  }
}
