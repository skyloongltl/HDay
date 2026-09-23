import 'dart:io';

import 'package:fitness_counter/core/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/test_database.dart';

void main() {
  test('new database creates empty business tables and enforces foreign keys',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    expect(await db.database.getVersion(), 1);
    expect(
      (await db.database.rawQuery('PRAGMA foreign_keys')).single.values.single,
      1,
    );
    for (final table in [
      'exercises',
      'plans',
      'plan_revisions',
      'plan_days',
      'plan_exercises',
      'plan_sets',
      'workout_sessions',
      'workout_exercises',
      'workout_sets',
      'app_settings',
    ]) {
      expect(await db.database.query(table), isEmpty, reason: table);
    }
    await expectLater(
      db.database.insert('plan_revisions', {
        'id': 'orphan',
        'plan_id': 'missing',
        'effective_from': '2026-09-15',
        'cycle_anchor_date': '2026-09-15',
        'cycle_days': 1,
        'mode': 'infinite',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('opening a future schema refuses downgrade without erasing its data',
      () async {
    final dir = await Directory.systemTemp.createTemp('fitness-schema-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/future.db';
    sqfliteFfiInit();
    final future = await databaseFactoryFfi.openDatabase(path);
    await future.execute('CREATE TABLE sentinel(value TEXT)');
    await future.insert('sentinel', {'value': 'retain'});
    await future.setVersion(2);
    await future.close();
    await expectLater(
      AppDatabase.open(path: path, factory: databaseFactoryFfi),
      throwsA(isA<Exception>()),
    );
    final reopened = await databaseFactoryFfi.openDatabase(path);
    expect((await reopened.query('sentinel')).single['value'], 'retain');
    await reopened.close();
  });

  test('reopening an existing database preserves business data', () async {
    final dir = await Directory.systemTemp.createTemp('fitness-preserve-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/existing.db';

    final first = await openTestDatabase(path: path);
    await first.database.insert('exercises', {
      'id': 'squat',
      'name': 'Back squat',
      'category': 'legs',
      'equipment': 'barbell',
      'default_unit': 'kg',
      'note': '',
      'created_at': 1,
      'updated_at': 1,
    });
    await first.database.insert('app_settings', {
      'id': 1,
      'default_unit': 'kg',
      'default_rest_seconds': 90,
      'rest_reminder': 1,
      'vibration': 1,
      'screen_awake': 1,
      'week_start': 'monday',
      'theme_id': 'breath-rhythm',
    });
    await first.close();

    final reopened = await openTestDatabase(path: path);
    addTearDown(reopened.close);
    expect(
      (await reopened.database.query('exercises')).single['name'],
      'Back squat',
    );
    expect(
      (await reopened.database.query('app_settings')).single['theme_id'],
      'breath-rhythm',
    );
  });
}
