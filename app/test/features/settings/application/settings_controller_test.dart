import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/data/app_database.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_schedule.dart';
import 'package:fitness_counter/features/settings/application/settings_providers.dart';
import 'package:fitness_counter/features/settings/data/sqlite_settings_repository.dart';
import 'package:fitness_counter/features/settings/domain/app_settings.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:fitness_counter/theme/theme_id.dart';
import 'package:fitness_counter/theme/theme_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/persistence_fixtures.dart';
import '../../../support/test_database.dart';

void main() {
  test(
      'all settings survive controller restart, including independent 00 switches',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final desired = AppSettings(
      defaultUnit: WeightUnit.lb,
      defaultRestSeconds: 0,
      restReminder: false,
      vibration: false,
      screenAwake: false,
      weekStart: WeekStart.sunday,
      themeId: const ThemeId('breath-rhythm'),
    );
    final first = _container(db);
    addTearDown(first.dispose);
    final controller = first.read(settingsControllerProvider.notifier);
    await first.read(settingsControllerProvider.notifier).initialize();

    expect(await controller.update(desired), isTrue);
    expect(
      first.read(settingsControllerProvider).requireValue.weightUnit,
      WeightUnit.lb,
    );
    expect(first.read(settingsControllerProvider).requireValue.defaultRest, 0);
    expect(
      first.read(settingsControllerProvider).requireValue.restReminder,
      isFalse,
    );
    expect(
      first.read(settingsControllerProvider).requireValue.vibration,
      isFalse,
    );

    first.dispose();
    final second = _container(db);
    addTearDown(second.dispose);
    final restored =
        await second.read(settingsControllerProvider.notifier).initialize();
    expect(restored.weightUnit, WeightUnit.lb);
    expect(restored.defaultRest, 0);
    expect(restored.restReminder, isFalse);
    expect(restored.vibration, isFalse);
    expect(restored.screenAwake, isFalse);
    expect(restored.weekStart, WeekStart.sunday);
  });

  test(
      'failed save renders committed values, keeps intended retry, and retries',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final container = _container(db);
    addTearDown(container.dispose);
    await container.read(settingsControllerProvider.notifier).initialize();
    await db.database.execute(
      "CREATE TRIGGER fail_settings BEFORE INSERT ON app_settings BEGIN SELECT RAISE(ABORT, 'settings disk failure'); END",
    );
    final controller = container.read(settingsControllerProvider.notifier);
    final intended = AppSettings(defaultRestSeconds: 120, vibration: false);

    expect(await controller.update(intended), isFalse);
    final failed = container.read(settingsControllerProvider).requireValue;
    expect(failed.defaultRest, 90);
    expect(failed.vibration, isTrue);
    expect(failed.pendingSettings?.defaultRestSeconds, 120);
    expect(failed.failure, isNotNull);

    await db.database.execute('DROP TRIGGER fail_settings');
    expect(await controller.retry(), isTrue);
    final retried = container.read(settingsControllerProvider).requireValue;
    expect(retried.defaultRest, 120);
    expect(retried.vibration, isFalse);
    expect(retried.pendingSettings, isNull);
    expect((await SqliteSettingsRepository(db).read()).defaultRestSeconds, 120);
  });

  test('rapid independent changes are persisted in invocation order', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final container = _container(db);
    addTearDown(container.dispose);
    final controller = container.read(settingsControllerProvider.notifier);
    final loaded = await controller.initialize();

    final reminderOff = controller.update(
      loaded.committedSettings.copyWith(restReminder: false),
    );
    final vibrationOff = controller.update(
      loaded.committedSettings.copyWith(
        restReminder: false,
        vibration: false,
      ),
    );

    expect(await reminderOff, isTrue);
    expect(await vibrationOff, isTrue);
    final saved = await SqliteSettingsRepository(db).read();
    expect(saved.restReminder, isFalse);
    expect(saved.vibration, isFalse);
  });

  test(
      'unknown persisted theme resolves to registry default without touching active snapshots',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final workouts = SqliteWorkoutRepository(db);
    await persistCompleted(workouts, id: 'saved-settings');
    final active = newSession(id: 'active-settings');
    await workouts.create(active);
    await SqliteSettingsRepository(db).save(
      AppSettings(themeId: const ThemeId('corrupt-theme')),
    );

    final container = _container(db);
    addTearDown(container.dispose);
    final state =
        await container.read(settingsControllerProvider.notifier).initialize();
    expect(state.selectedTheme, breathRhythmThemeId);
    expect(
      (await workouts.findUnfinished())!.exercises.single.targetRestSeconds,
      active.exercises.single.targetRestSeconds,
    );
    expect(
      (await workouts.find('saved-settings'))!.exercises.single.unitSnapshot,
      active.exercises.single.unitSnapshot,
    );
  });

  test(
      'settings defaults do not mutate plan schedule or active workout snapshots',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final plans = SqlitePlanRepository(db);
    final plan = catalogPlan(id: 'settings-plan');
    final revision = catalogRevision(
      id: 'settings-revision',
      planId: plan.id,
      effectiveFrom: LocalDate(2026, 9, 15),
    );
    await plans.save(plan, revision);
    final workouts = SqliteWorkoutRepository(db);
    final active = newSession(id: 'snapshot-settings');
    await workouts.create(active);
    final before = (await SqlitePlanSchedule.read(db.database))
        .on(LocalDate(2026, 9, 15))
        .single
        .day
        .exercises
        .single
        .targetRestSeconds;

    final container = _container(db);
    addTearDown(container.dispose);
    final controller = container.read(settingsControllerProvider.notifier);
    await container.read(settingsControllerProvider.notifier).initialize();
    expect(
      await controller.update(
        AppSettings(defaultRestSeconds: 120, defaultUnit: WeightUnit.lb),
      ),
      isTrue,
    );
    final after = (await SqlitePlanSchedule.read(db.database))
        .on(LocalDate(2026, 9, 15))
        .single
        .day
        .exercises
        .single
        .targetRestSeconds;
    expect(after, before);
    final restored = (await workouts.findUnfinished())!;
    expect(
      restored.exercises.single.targetRestSeconds,
      active.exercises.single.targetRestSeconds,
    );
    expect(
      restored.exercises.single.unitSnapshot,
      active.exercises.single.unitSnapshot,
    );
  });
}

ProviderContainer _container(AppDatabase db) => ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((_) async => db),
        themeRegistryProvider.overrideWith(
          (_) async => ThemeRegistry([breathRhythmDefinition]),
        ),
      ],
    );
