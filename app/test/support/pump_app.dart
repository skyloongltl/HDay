import 'package:fitness_counter/app/app.dart';
import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/app/router.dart';
import 'package:fitness_counter/core/data/app_database.dart';
import 'package:fitness_counter/features/exercises/application/exercise_providers.dart';
import 'package:fitness_counter/features/plans/application/plan_providers.dart';
import 'package:fitness_counter/features/today/application/today_providers.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_database.dart';

Future<GoRouter> pumpFitnessApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  AppDatabase? database,
  String initialLocation = '/home',
  bool waitForLoading = true,
}) async {
  final router = createRouter();
  router.go(initialLocation);
  addTearDown(router.dispose);
  final effectiveOverrides = overrides.isEmpty
      ? [
          themeDefinitionsProvider.overrideWith(
            (ref) async => [breathRhythmDefinition],
          ),
        ]
      : overrides;
  final db = database ?? (await tester.runAsync(openTestDatabase))!;
  if (database == null) addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) async => db),
      ...effectiveOverrides,
    ],
  );
  addTearDown(container.dispose);
  await tester
      .runAsync(() => container.read(exerciseControllerProvider.future));
  await tester.runAsync(() => container.read(planControllerProvider.future));
  await tester.runAsync(() => container.read(todayRepositoryProvider.future));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: const ValueKey('app-render'),
        child: FitnessCounterApp(router: router),
      ),
    ),
  );
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (waitForLoading &&
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the theme loading indicator to disappear.');
    }
    // Native SQLite I/O must progress outside the widget test's fake clock.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump();
  return router;
}
