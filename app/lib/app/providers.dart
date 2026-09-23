import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/app_database.dart';
import '../core/domain/clock.dart';
import '../core/platform/system_clock.dart';

import '../core/platform/theme_package_source.dart';
import '../theme/app_theme_definition.dart';
import '../theme/theme_registry.dart';

final themePackageSourceProvider = Provider<ThemePackageSource>(
  (ref) => const BundledThemePackageSource(),
);

final themeDefinitionsProvider = FutureProvider<List<AppThemeDefinition>>(
  (ref) => ref.watch(themePackageSourceProvider).load(),
);

final themeRegistryProvider = FutureProvider<ThemeRegistry>(
  (ref) async =>
      ThemeRegistry(await ref.watch(themeDefinitionsProvider.future)),
);

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final opened = AppDatabase.open();
  ref.onDispose(() async => (await opened).close());
  return opened;
});
final clockProvider = Provider<Clock>((ref) => SystemClock());
