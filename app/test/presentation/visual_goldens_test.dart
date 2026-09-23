import 'dart:async';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/today/domain/today_overview.dart';
import 'package:fitness_counter/features/today/domain/today_repository.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/history_test_support.dart';
import '../support/task13_fixtures.dart';

void main() {
  setUpAll(loadHistoryFonts);
  for (final screen in [
    task13EmptyHome,
    ...task13Screens,
    ...task13ExtraScreens,
  ]) {
    for (final (width, scale) in [(390.0, 1.0), (360.0, 1.3), (430.0, 1.3)]) {
      testWidgets('${screen.name} final host golden $width x $scale',
          (tester) async {
        await pumpTask13(tester, screen, width: width, scale: scale);
        await expectLater(
          find.byKey(const ValueKey('app-render')),
          matchesGoldenFile(
            'goldens/final_${screen.name}_${width.toInt()}_$scale.png',
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final state in ['loading', 'error']) {
    testWidgets('home $state real read boundary host golden', (tester) async {
      final gate = _ReadGate();
      if (state == 'error') gate.fail = true;
      await pumpTask13(
        tester,
        task13EmptyHome,
        waitForContent: false,
        todayWrapper: (repository) {
          gate.delegate = repository;
          return gate;
        },
      );
      expect(
        find.text(
          state == 'error'
              ? AppStrings.todayLoadFailed
              : AppStrings.todayLoading,
        ),
        findsWidgets,
      );
      await _golden(tester, 'home_$state', 390, 1);
      gate.fail = false;
      gate.ready.complete();
      if (state == 'error') await tester.tap(find.text(AppStrings.retry));
      await settleTask13(tester, task13EmptyHome);
    });
  }
  for (final (width, scale) in [(390.0, 1.0), (360.0, 1.3)]) {
    testWidgets('picker reset final host golden $width x $scale',
        (tester) async {
      final screen = task13Screens.firstWhere((s) => s.name == 'pre_workout');
      await pumpTask13(tester, screen, width: width, scale: scale);
      await tester.tap(find.text(AppStrings.addTemporaryExercise));
      await settleTask13(tester, screen);
      expect(find.byKey(const ValueKey('exercise-search')), findsOneWidget);
      expect(
        tester
                .widget<TextField>(
                  find.byKey(const ValueKey('exercise-search')),
                )
                .controller
                ?.text ??
            '',
        isEmpty,
      );
      await _golden(tester, 'picker', width, scale);
    });
    testWidgets('rest early end final host golden $width x $scale',
        (tester) async {
      final screen = task13Screens.firstWhere((s) => s.name == 'rest');
      await pumpTask13(tester, screen, width: width, scale: scale);
      await tester.tap(find.byKey(const ValueKey('end-rest-workout')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey('early-end-sheet')), findsOneWidget);
      for (final key in [
        'end-and-save',
        'continue-training',
        'discard-workout',
      ]) {
        final target = find.byKey(ValueKey(key));
        expect(target.hitTestable(), findsOneWidget);
        final bounds = tester.getRect(target);
        expect(bounds.shortestSide, greaterThanOrEqualTo(48));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(844));
      }
      await _golden(tester, 'rest_early_end', width, scale);
    });
    testWidgets('exercise form scrolled save final host golden $width x $scale',
        (tester) async {
      final screen = task13Screens.firstWhere((s) => s.name == 'exercise_edit');
      await pumpTask13(tester, screen, width: width, scale: scale);
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('exercise-primary-save')));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('exercise-primary-save')))
            .shortestSide,
        greaterThanOrEqualTo(48),
      );
      await _golden(tester, 'exercise_edit_scrolled', width, scale);
    });
  }
}

Future<void> _golden(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  await tester.pump();
  await expectLater(
    find.byKey(const ValueKey('app-render')),
    matchesGoldenFile(
      'goldens/final_${name}_${width.toInt()}_${scale.toStringAsFixed(1)}.png',
    ),
  );
  expect(tester.takeException(), isNull);
}

/// Delays/fails the typed read boundary; successful retry uses the real SQLite
/// repository. No widget, controller state or successful data is substituted.
final class _ReadGate implements TodayRepository {
  final ready = Completer<void>();
  late TodayRepository delegate;
  bool fail = false;
  @override
  Future<TodayOverview> load(LocalDate date) async {
    if (fail) throw StateError('test-owned read failure');
    await ready.future;
    return delegate.load(date);
  }
}
