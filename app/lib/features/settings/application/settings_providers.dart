import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/sqlite_settings_repository.dart';
import '../domain/settings_repository.dart';
import 'settings_controller.dart';
import 'test_data_seeder.dart';

final settingsRepositoryProvider = FutureProvider<SettingsRepository>(
  (ref) async =>
      SqliteSettingsRepository(await ref.watch(appDatabaseProvider.future)),
);

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AsyncValue<SettingsState>>(
  (ref) {
    final controller = SettingsController(ref);
    controller.initialize().then<void>((_) {}, onError: (_, __) {});
    return controller;
  },
);

final testDataSeederProvider = FutureProvider<TestDataSeeder>(
  (ref) async => TestDataSeeder(
    await ref.watch(appDatabaseProvider.future),
    ref.watch(clockProvider),
  ),
);
