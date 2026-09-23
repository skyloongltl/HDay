import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';

import '../domain/app_failure.dart';
import 'schema.dart';

final class AppDatabase {
  AppDatabase._(this.database);

  /// Data/composition boundary only. Domain repositories expose typed values.
  final Database database;

  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) =>
      databaseGuard(() async {
        final selectedFactory = factory ?? databaseFactory;
        final selectedPath = path ??
            paths.join(
              await selectedFactory.getDatabasesPath(),
              Schema.databaseName,
            );
        final db = await selectedFactory.openDatabase(
          selectedPath,
          options: OpenDatabaseOptions(
            version: Schema.version,
            singleInstance: false,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: Schema.create,
            onUpgrade: Schema.upgrade,
            onDowngrade: Schema.downgrade,
          ),
        );
        return AppDatabase._(db);
      });

  Future<T> transaction<T>(Future<T> Function(Transaction) action) =>
      databaseGuard(() => database.transaction(action));

  Future<void> close() => database.close();
}

Future<T> databaseGuard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DatabaseException catch (error) {
    final message = error.toString();
    final code = message.contains('one_unfinished_workout')
        ? FailureCode.conflict
        : message.contains('UNIQUE constraint failed: exercises.name')
            ? FailureCode.duplicate
            : FailureCode.persistence;
    throw AppFailure(code, detail: message);
  } on FormatException catch (error) {
    throw AppFailure(FailureCode.persistence, detail: error.message);
  }
}
