import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/domain/clock.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/history_test_support.dart';
import '../../../support/pump_app.dart';

void main() {
  testWidgets('empty Today starts a dated free-workout preparation flow',
      (tester) async {
    final router = await pumpFitnessApp(
      tester,
      overrides: [
        themeDefinitionsProvider.overrideWith(
          (ref) async => [breathRhythmDefinition],
        ),
        clockProvider.overrideWith(
          (ref) => _FixedClock(LocalDate(2026, 9, 15)),
        ),
      ],
    );

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (find.text(AppStrings.startFreeWorkout).evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text(AppStrings.startFreeWorkout), findsOneWidget);

    await tester.tap(find.text(AppStrings.startFreeWorkout));
    // Preparation reads SQLite outside the fake widget scheduler.
    await settleHistory(tester);
    expect(find.text(AppStrings.addExercise), findsOneWidget);

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/pre-workout?free=true&date=2026-09-15',
    );
  });
}

final class _FixedClock implements Clock {
  const _FixedClock(this._today);
  final LocalDate _today;

  @override
  Duration get monotonicElapsed => Duration.zero;

  @override
  DateTime nowUtc() => DateTime.utc(2026, 9, 15);

  @override
  LocalDate today() => _today;
}
