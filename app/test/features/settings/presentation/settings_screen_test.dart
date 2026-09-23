import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/platform/notification_gateway.dart';
import 'package:fitness_counter/features/workout/application/rest_effects_controller.dart';
import 'package:fitness_counter/features/workout/application/workout_providers.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/history_test_support.dart';
import '../../../support/pump_app.dart';
import '../../../support/rest_effect_fakes.dart';
import '../../../support/test_database.dart';

void main() {
  testWidgets(
      'settings app bar centers title with balanced circular back affordance',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/settings',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        restEffectsStatusProvider.overrideWithValue(
          const RestEffectsStatus(
            permission: NotificationPermissionState(
              notificationsGranted: true,
              exactAlarmsGranted: true,
            ),
          ),
        ),
      ],
    );
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isTrue);
    expect(appBar.actions, hasLength(1));
    expect(find.byType(DecoratedBox), findsWidgets);
    expect(
      tester.getSize(find.byType(IconButton).first).width,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets(
      'settings route shows exactly registry themes and selected fallback',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await tester.runAsync(() async {
      await db.database.insert('app_settings', {
        'id': 1,
        'default_unit': 'kg',
        'default_rest_seconds': 90,
        'rest_reminder': 1,
        'vibration': 1,
        'screen_awake': 1,
        'week_start': 'monday',
        'theme_id': 'unknown-corrupt-id',
      });
    });
    await pumpFitnessApp(tester, database: db, initialLocation: '/settings');

    expect(find.byKey(const ValueKey('settings-screen')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('theme-option-breath-rhythm')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.byKey(const ValueKey('theme-option-breath-rhythm')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('theme-option-future')), findsNothing);
    expect(
      find.byKey(const ValueKey('theme-selected-breath-rhythm')),
      findsOneWidget,
    );
  });

  testWidgets('permission actions use live gateway and refresh rest effects',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    final harness = EffectHarness();
    harness.notification.granted = false;
    harness.notification.exact = false;
    await harness.effects.refreshPermission();
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/settings',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        restEffectsEnabledProvider.overrideWithValue(true),
        restEffectsControllerProvider.overrideWithValue(harness.effects),
      ],
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('request-notification-permission')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('通知权限未开启'), findsOneWidget);
    expect(find.text('精确提醒不可用'), findsOneWidget);

    harness.notification.granted = true;
    await tester
        .tap(find.byKey(const ValueKey('request-notification-permission')));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    harness.notification.exact = true;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('request-exact-alarm-permission')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester
        .tap(find.byKey(const ValueKey('request-exact-alarm-permission')));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(harness.notification.requestNotificationCount, 1);
    expect(harness.notification.requestExactCount, 1);
    expect(
      harness.effects.status.value.permission?.notificationsGranted,
      isTrue,
    );
    expect(harness.effects.status.value.permission?.exactAlarmsGranted, isTrue);
  });

  testWidgets(
      'permission unavailable state disables ordinary notification request',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    final harness = EffectHarness();
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/settings',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        restEffectsControllerProvider.overrideWithValue(harness.effects),
      ],
    );

    expect(find.text(AppStrings.permissionUnavailable), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('request-notification-permission')),
      findsNothing,
    );
    expect(find.text(AppStrings.permissionRefreshing), findsOneWidget);
    expect(find.text(AppStrings.retryPermission), findsOneWidget);
  });

  testWidgets('permission request failure is surfaced separately from denial',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    final harness = EffectHarness();
    harness.notification.granted = false;
    harness.notification.exact = false;
    harness.notification.failRequest = true;
    await harness.effects.refreshPermission();
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/settings',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        restEffectsEnabledProvider.overrideWithValue(true),
        restEffectsControllerProvider.overrideWithValue(harness.effects),
      ],
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('request-notification-permission')),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester
        .tap(find.byKey(const ValueKey('request-notification-permission')));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.text(AppStrings.permissionActionFailed), findsOneWidget);
    expect(find.text(AppStrings.notificationPermissionDenied), findsNothing);
    expect(harness.notification.requestNotificationCount, 1);
  });

  testWidgets('permission timing degradation is visible in live status',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/settings',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        restEffectsStatusProvider.overrideWithValue(
          const RestEffectsStatus(
            permission: NotificationPermissionState(
              notificationsGranted: true,
              exactAlarmsGranted: true,
            ),
            isTimingDegraded: true,
          ),
        ),
      ],
    );

    expect(find.text(AppStrings.permissionTimingDegraded), findsOneWidget);
  });

  testWidgets(
      'settings visual matrix captures supported widths and text scales',
      (tester) async {
    await tester.runAsync(loadHistoryFonts);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/settings',
      overrides: [
        themeDefinitionsProvider
            .overrideWith((_) async => [breathRhythmDefinition]),
        restEffectsStatusProvider.overrideWithValue(
          const RestEffectsStatus(
            permission: NotificationPermissionState(
              notificationsGranted: true,
              exactAlarmsGranted: true,
            ),
          ),
        ),
      ],
    );

    const matrix = <({int width, double scale})>[
      (width: 360, scale: 1),
      (width: 390, scale: 1),
      (width: 430, scale: 1),
      (width: 360, scale: 1.3),
      (width: 390, scale: 1.3),
      (width: 430, scale: 1.3),
    ];
    for (final entry in matrix) {
      tester.view.physicalSize = Size(entry.width.toDouble(), 800);
      tester.platformDispatcher.textScaleFactorTestValue = entry.scale;
      await tester.pump();
      expect(find.byKey(const ValueKey('settings-list')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('settings-list'))).dy,
        lessThan(100),
      );
      await _captureSettings(
        tester,
        'settings_${entry.width}_${entry.scale.toStringAsFixed(1)}',
      );
    }
  });

  testWidgets(
      'settings controls persist both reminders off and fit narrow large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await pumpFitnessApp(tester, database: db, initialLocation: '/settings');
    await tester.tap(find.byKey(const ValueKey('setting-rest-reminder')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('setting-vibration')));
    await tester.tap(find.byKey(const ValueKey('setting-vibration')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    Map<String, Object?>? persisted;
    while (DateTime.now().isBefore(deadline)) {
      final rows =
          await tester.runAsync(() => db.database.query('app_settings'));
      if (rows!.isNotEmpty &&
          rows.single['rest_reminder'] == 0 &&
          rows.single['vibration'] == 0) {
        persisted = rows.single;
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(persisted?['rest_reminder'], 0);
    expect(persisted?['vibration'], 0);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('setting-rest-reminder')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('test data action confirms, seeds, and reports success',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await pumpFitnessApp(tester, database: db, initialLocation: '/settings');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('seed-test-data')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('seed-test-data')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.seedTestDataConfirmation), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-seed-test-data')));
    await tester.pump();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final rows = await tester.runAsync(
        () => db.database.query(
          'exercises',
          where: "id LIKE 'hday-test-%'",
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (rows!.length == 4 &&
          find.text(AppStrings.seedTestDataComplete).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text(AppStrings.seedTestDataComplete), findsOneWidget);
    expect(
      await tester.runAsync(
        () => db.database.query(
          'exercises',
          where: "id LIKE 'hday-test-%'",
        ),
      ),
      hasLength(4),
    );
  });
}

Future<void> _captureSettings(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('app-render')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory(
      '../.superpowers/sdd/2026-09-15-flutter-rewrite/task-12-ui',
    );
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
