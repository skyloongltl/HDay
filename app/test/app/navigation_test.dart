import 'dart:convert';

import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/platform/theme_package_source.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/history_test_support.dart';
import '../support/memory_asset_bundle.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('the four primary destinations switch through one router',
      (tester) async {
    final router = await pumpFitnessApp(tester);

    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/home');

    final destinations = <String, String>{
      AppStrings.plansTab: '/plan',
      AppStrings.calendarTab: '/calendar',
      AppStrings.exercisesTab: '/exercises',
      AppStrings.todayTab: '/home',
    };
    for (final entry in destinations.entries) {
      await tester.tap(find.text(entry.key).last);
      await settleHistory(tester);
      expect(router.routeInformationProvider.value.uri.path, entry.value);
    }
  });

  testWidgets('settings belongs to Today and shell consumes insets once',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);

    await pumpFitnessApp(tester);

    expect(find.byTooltip(AppStrings.settings), findsOneWidget);
    _expectShellConsumesInsetsOnce(tester);

    await tester.tap(find.text(AppStrings.plansTab).last);
    await tester.pumpAndSettle();

    expect(find.byTooltip(AppStrings.settings), findsNothing);
    _expectShellConsumesInsetsOnce(tester);
  });

  testWidgets('app paints a light status bar with dark Android icons',
      (tester) async {
    await pumpFitnessApp(tester);

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const ValueKey('app-system-ui')),
    );
    expect(region.value.statusBarColor, Colors.transparent);
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    expect(region.value.statusBarBrightness, Brightness.light);
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('app-system-bar-background')),
          )
          .color,
      isNot(Colors.black),
    );
  });

  testWidgets(
      'initial destinations present real empty states without seed data',
      (tester) async {
    await pumpFitnessApp(tester);

    expect(find.text(AppStrings.noExercisesToday), findsOneWidget);

    await tester.tap(find.text(AppStrings.plansTab).last);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.noPlans), findsOneWidget);

    await tester.tap(find.text(AppStrings.calendarTab).last);
    await settleHistory(tester);
    expect(find.text(AppStrings.noWorkoutHistory), findsOneWidget);

    await tester.tap(find.text(AppStrings.exercisesTab).last);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.noExercises), findsOneWidget);
  });

  testWidgets('empty shell fits 360 and 430 logical pixels at 1.3 text scale',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final width in [360.0, 430.0]) {
      tester.view.physicalSize = Size(width, 800);
      await pumpFitnessApp(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(AppStrings.exercisesTab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'theme load failure is visible and retry invokes the source again',
      (tester) async {
    var attempts = 0;
    await pumpFitnessApp(
      tester,
      overrides: [
        themeDefinitionsProvider.overrideWith((ref) async {
          attempts += 1;
          throw const FormatException('invalid bundled theme');
        }),
      ],
    );

    expect(find.text(AppStrings.themeLoadFailed), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text(AppStrings.themeLoadFailed), findsOneWidget);
  });

  testWidgets('invalid theme package retries into the runnable shell',
      (tester) async {
    final validManifest = await rootBundle.loadString(bundledThemeManifestPath);
    final schema = await rootBundle.loadString(bundledThemeSchemaPath);
    final invalidPackage = (jsonDecode(validManifest) as Map<String, dynamic>)
        .cast<String, Object?>();
    final invalidTokens = invalidPackage['tokens']! as Map<String, Object?>;
    invalidTokens['colors.coral'] = 123;
    var attempts = 0;

    await pumpFitnessApp(
      tester,
      overrides: [
        themeDefinitionsProvider.overrideWith((ref) async {
          attempts += 1;
          final manifest =
              attempts == 1 ? jsonEncode(invalidPackage) : validManifest;
          return BundledThemePackageSource(
            bundle: MemoryAssetBundle({
              bundledThemeManifestPath: manifest,
              bundledThemeSchemaPath: schema,
            }),
          ).load();
        }),
      ],
    );

    expect(find.text(AppStrings.themeLoadFailed), findsOneWidget);
    expect(attempts, 1);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text(AppStrings.themeLoadFailed), findsNothing);
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    // The restored shell starts native settings/Today reads. Settle them before
    // the in-memory database teardown, beyond pumpAndSettle's fake scheduler.
    await settleHistory(tester);
  });
}

void _expectShellConsumesInsetsOnce(WidgetTester tester) {
  final shellSafeArea = find.byWidgetPredicate(
    (widget) => widget is SafeArea && widget.child is Scaffold,
    description: 'the AppScaffold-owned SafeArea',
  );
  expect(shellSafeArea, findsOneWidget);

  final shellScaffold = find.descendant(
    of: shellSafeArea,
    matching: find.byType(Scaffold),
  );
  expect(shellScaffold, findsOneWidget);
  expect(tester.getTopLeft(shellScaffold).dy, 24);
  expect(tester.getBottomRight(shellScaffold).dy, 780);
}
