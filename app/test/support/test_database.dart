import 'package:fitness_counter/core/data/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppDatabase> openTestDatabase({String? path}) {
  sqfliteFfiInit();
  return AppDatabase.open(
    path: path ?? inMemoryDatabasePath,
    factory: databaseFactoryFfi,
  );
}
