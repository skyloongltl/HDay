import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/history/application/history_providers.dart';
import 'package:fitness_counter/features/history/data/sqlite_history_repository.dart';
import 'package:fitness_counter/features/history/domain/history_models.dart';
import 'package:fitness_counter/features/history/domain/history_repository.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/fake_clock.dart';
import '../../../support/history_test_support.dart';
import '../../../support/pump_app.dart';
import '../../../support/test_database.dart';

void main() {
  setUpAll(loadHistoryFonts);
  testWidgets(
      'calendar retry reloads the requested month after a transient read failure',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final repository = _FailingDayRepository(SqliteHistoryRepository(db));
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/calendar',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 9, 15))),
        historyRepositoryProvider.overrideWith((_) async => repository),
      ],
    );
    await settleHistory(tester);
    expect(find.byKey(const Key('calendar-day-2026-09-01')), findsOneWidget);
    repository.failedMonth = LocalDate(2026, 10, 1);
    await tester.tap(find.byKey(const Key('calendar-next')));
    await settleHistory(tester);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.byKey(const Key('calendar-screen')), findsNothing);
    repository.failedMonth = null;
    await tester.tap(find.text(AppStrings.retry));
    await settleHistory(tester);
    expect(
      find.byKey(const Key('calendar-day-2026-10-01')),
      findsOneWidget,
      reason:
          'Retry must preserve the requested October, not reset to Clock September.',
    );
    expect(find.byKey(const Key('calendar-day-2026-09-01')), findsNothing);
    expect(find.text('2026 年 10 月'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'recent history preserves date pillar summary and whole card target at $width/$scale',
          (tester) async {
        await _pumpSavedCalendar(tester, width, scale);
        final card = find.byKey(const Key('recent-history-saved'));
        expect(card, findsOneWidget);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        final material = tester.widget<Material>(card);
        expect(material.color, const Color(0xffFFFFFF));
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.side.color, const Color(0xffDFE7EC));
        expect(shape.borderRadius, BorderRadius.circular(12));
        final date = find.byKey(const Key('recent-date-saved'));
        expect(tester.getSize(date).width, 40);
        expect(
          find.descendant(of: date, matching: find.text('15')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: date, matching: find.text('周二')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text('推拉腿计划')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.text('01:00 · 1 组')),
          findsOneWidget,
        );
        final divider = find.byKey(const Key('recent-divider-saved'));
        expect(tester.getSize(divider), const Size(1, 36));
        expect(
          find.descendant(
            of: card,
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
        await captureHistory(
          tester,
          'fix1_recent_history_${width.toInt()}_$scale',
        );
        // Tap the date pillar, proving the whole row navigates, not only chevron.
        await tester.tap(date);
        await settleHistory(tester);
        expect(find.byKey(const Key('session-saved')), findsOneWidget);
        expect(
          GoRouterState.of(
            tester.element(find.byKey(const Key('history-day-detail'))),
          ).uri.toString(),
          '/history/2026-09-15?session=saved',
        );
        expect(tester.takeException(), isNull);
      });
      testWidgets(
          'selected saved card retains result chips and footer at $width/$scale',
          (tester) async {
        await _pumpSavedCalendar(tester, width, scale);
        final card = find.byKey(const Key('calendar-session-saved'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        final pill = find.descendant(of: card, matching: find.text('已完成'));
        expect(pill, findsOneWidget);
        expect(
          _decorations(tester, pill)
              .any((d) => d.color == const Color(0xffDFF5EE)),
          isTrue,
        );
        final exercise = find.descendant(of: card, matching: find.text('杠铃卧推'));
        expect(
          _decorations(tester, exercise)
              .any((d) => d.color == const Color(0xffEEF3F6)),
          isTrue,
        );
        expect(
          find.descendant(of: card, matching: find.text('推拉腿计划')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.textContaining('1/2 组完成')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.textContaining('01:00')),
          findsOneWidget,
        );
        final footer = find.byKey(const Key('calendar-history-footer-saved'));
        final decoration =
            tester.widget<DecoratedBox>(footer).decoration as BoxDecoration;
        expect(decoration.color, const Color(0xffEEF3F6));
        expect(decoration.border!.top.color, const Color(0xffDFE7EC));
        expect(
          find.descendant(
            of: footer,
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
        await captureHistory(
          tester,
          'fix1_selected_saved_${width.toInt()}_$scale',
        );
        await tester.tap(find.text(AppStrings.viewFullHistory));
        await settleHistory(tester);
        expect(find.byKey(const Key('session-saved')), findsOneWidget);
        expect(
          GoRouterState.of(
            tester.element(find.byKey(const Key('history-day-detail'))),
          ).uri.toString(),
          '/history/2026-09-15?session=saved',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final date in ['not-a-date', '2026-02-30']) {
    testWidgets('invalid history date $date safely returns to calendar',
        (tester) async {
      final router = await pumpFitnessApp(
        tester,
        initialLocation: '/history/$date',
      );
      await settleHistory(tester);
      expect(tester.takeException(), isNull);
      expect(router.routeInformationProvider.value.uri.path, '/calendar');
      expect(find.byKey(const Key('calendar-screen')), findsOneWidget);
      expect(find.byKey(const Key('history-day-detail')), findsNothing);
    });
  }
  testWidgets(
      'failed second date never labels prior sessions as that date and retries',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(() async {
      await savePerformanceSession(
        db,
        id: 'first',
        start: DateTime.utc(2026, 9, 15),
        date: LocalDate(2026, 9, 15),
      );
      await savePerformanceSession(
        db,
        id: 'second',
        start: DateTime.utc(2026, 9, 16),
        date: LocalDate(2026, 9, 16),
      );
    });
    final repository = _FailingDayRepository(SqliteHistoryRepository(db));
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/history/2026-09-15',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 9, 15))),
        historyRepositoryProvider.overrideWith((_) async => repository),
      ],
    );
    await settleHistory(tester);
    expect(find.byKey(const Key('session-first')), findsOneWidget);
    repository.failedDate = LocalDate(2026, 9, 16);
    router.go('/history/2026-09-16');
    await settleHistory(tester);
    expect(find.textContaining('9 月 16 日'), findsOneWidget);
    expect(
      find.byKey(const Key('session-first')),
      findsNothing,
      reason: 'The requested date must never relabel the last committed day.',
    );
    expect(find.text(AppStrings.historyLoadFailed), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    repository.failedDate = null;
    await tester.tap(find.text(AppStrings.retry));
    await settleHistory(tester);
    expect(find.byKey(const Key('session-second')), findsOneWidget);
    expect(find.byKey(const Key('session-first')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Iterable<BoxDecoration> _decorations(WidgetTester tester, Finder child) =>
    tester
        .widgetList<DecoratedBox>(
          find.ancestor(of: child, matching: find.byType(DecoratedBox)),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>();

Future<GoRouter> _pumpSavedCalendar(
  WidgetTester tester,
  double width,
  double scale,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final db = (await tester.runAsync(openTestDatabase))!;
  addTearDown(db.close);
  await tester.runAsync(() async {
    await SqlitePlanRepository(db).save(
      catalogPlan(),
      catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
    );
    await savePerformanceSession(
      db,
      id: 'saved',
      start: DateTime.utc(2026, 9, 15),
    );
  });
  final router = await pumpFitnessApp(
    tester,
    database: db,
    initialLocation: '/calendar',
    overrides: [
      themeDefinitionsProvider
          .overrideWith((_) async => [breathRhythmDefinition]),
      clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 9, 15))),
    ],
  );
  await settleHistory(tester);
  return router;
}

// Only the read-failure boundary is injected; all data comes from real SQLite.
final class _FailingDayRepository implements HistoryRepository {
  _FailingDayRepository(this.delegate);
  final HistoryRepository delegate;
  LocalDate? failedDate;
  LocalDate? failedMonth;
  @override
  Future<List<WorkoutSession>> day(LocalDate date) async {
    if (date == failedDate) throw StateError('requested day unavailable');
    return delegate.day(date);
  }

  @override
  Future<List<CalendarDaySummary>> month(LocalDate date) async {
    if (date == failedMonth) throw StateError('requested month unavailable');
    return delegate.month(date);
  }

  @override
  Future<List<WorkoutSession>> recent({int limit = 20}) =>
      delegate.recent(limit: limit);
  @override
  Future<FitnessDayStats> stats(LocalDate date, {required int weekStart}) =>
      delegate.stats(date, weekStart: weekStart);
  @override
  Future<List<ExerciseRecord>> exerciseRecords(String id) =>
      delegate.exerciseRecords(id);
  @override
  Future<void> correctSet(
    String sessionId,
    String setId, {
    required double? weight,
    required int reps,
  }) =>
      delegate.correctSet(sessionId, setId, weight: weight, reps: reps);
  @override
  Future<void> deleteSession(String id) => delegate.deleteSession(id);
  @override
  Future<void> updateNote(String id, String note) =>
      delegate.updateNote(id, note);
}
