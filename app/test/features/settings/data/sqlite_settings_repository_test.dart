import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/settings/data/sqlite_settings_repository.dart';
import 'package:fitness_counter/features/settings/domain/app_settings.dart';
import 'package:fitness_counter/theme/theme_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_database.dart';

void main() {
  test('settings return defaults without seeds and persist all overrides',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqliteSettingsRepository(db);
    final defaults = await repo.read();
    expect(defaults.defaultUnit, WeightUnit.kg);
    expect(defaults.defaultRestSeconds, 90);
    expect(defaults.restReminder, isTrue);
    expect(defaults.vibration, isTrue);
    expect(defaults.screenAwake, isTrue);
    expect(defaults.weekStart, WeekStart.monday);
    expect(defaults.themeId.value, 'breath-rhythm');
    expect(await db.database.query('app_settings'), isEmpty);
    await repo.save(
      AppSettings(
        defaultUnit: WeightUnit.none,
        defaultRestSeconds: 45,
        restReminder: false,
        vibration: false,
        screenAwake: false,
        weekStart: WeekStart.sunday,
        themeId: const ThemeId('future-theme'),
      ),
    );
    final saved = await SqliteSettingsRepository(db).read();
    expect(saved.defaultUnit, WeightUnit.none);
    expect(saved.defaultRestSeconds, 45);
    expect(saved.restReminder, isFalse);
    expect(saved.vibration, isFalse);
    expect(saved.screenAwake, isFalse);
    expect(saved.weekStart, WeekStart.sunday);
    expect(saved.themeId.value, 'future-theme');
  });
}
