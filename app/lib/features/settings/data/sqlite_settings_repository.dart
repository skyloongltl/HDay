import 'package:sqflite/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../../../theme/theme_id.dart';
import '../../exercises/domain/exercise.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

final class SqliteSettingsRepository implements SettingsRepository {
  const SqliteSettingsRepository(this._db);
  final AppDatabase _db;

  @override
  Future<AppSettings> read() => databaseGuard(() => readFrom(_db.database));

  static Future<AppSettings> readFrom(DatabaseExecutor executor) async {
    final rows = await executor.query('app_settings', where: 'id = 1');
    if (rows.isEmpty) return AppSettings();
    final row = rows.single;
    return AppSettings(
      defaultUnit: WeightUnit.fromCode(row['default_unit'] as String),
      defaultRestSeconds: row['default_rest_seconds'] as int,
      restReminder: row['rest_reminder'] == 1,
      vibration: row['vibration'] == 1,
      screenAwake: row['screen_awake'] == 1,
      weekStart: WeekStart.values.byName(row['week_start'] as String),
      themeId: ThemeId(row['theme_id'] as String),
    );
  }

  @override
  Future<void> save(AppSettings settings) => databaseGuard(() async {
        await _db.database.insert(
          'app_settings',
          {
            'id': 1,
            'default_unit': settings.defaultUnit.code,
            'default_rest_seconds': settings.defaultRestSeconds,
            'rest_reminder': settings.restReminder ? 1 : 0,
            'vibration': settings.vibration ? 1 : 0,
            'screen_awake': settings.screenAwake ? 1 : 0,
            'week_start': settings.weekStart.name,
            'theme_id': settings.themeId.value,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
}
