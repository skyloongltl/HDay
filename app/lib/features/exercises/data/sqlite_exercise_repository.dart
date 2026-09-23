import '../../../core/data/app_database.dart';
import '../../../core/data/sql_values.dart';
import '../domain/exercise.dart';
import '../domain/exercise_repository.dart';

final class SqliteExerciseRepository implements ExerciseRepository {
  const SqliteExerciseRepository(this._db);
  final AppDatabase _db;

  @override
  Future<List<Exercise>> search({
    String query = '',
    String? category,
    String? equipment,
  }) =>
      databaseGuard(() async {
        final rows = await _db.database.query(
          'exercises',
          where: 'instr(lower(name), lower(?)) > 0'
              '${category == null ? '' : ' AND category = ?'}'
              '${equipment == null ? '' : ' AND equipment = ?'}',
          whereArgs: [
            query.trim(),
            if (category != null) category,
            if (equipment != null) equipment,
          ],
          orderBy: 'name COLLATE NOCASE, id',
        );
        return rows.map(_read).toList(growable: false);
      });

  @override
  Future<Exercise?> find(String id) => databaseGuard(() async {
        final rows = await _db.database
            .query('exercises', where: 'id = ?', whereArgs: [id]);
        return rows.isEmpty ? null : _read(rows.single);
      });

  @override
  Future<List<Exercise>> recent({int limit = 10}) => databaseGuard(() async {
        if (limit <= 0) return [];
        final rows = await _db.database.rawQuery(
          '''
      SELECT e.* FROM exercises e
      JOIN workout_exercises we ON we.exercise_id = e.id
      JOIN workout_sessions ws ON ws.id = we.session_id
      GROUP BY e.id ORDER BY MAX(ws.started_at) DESC, e.id LIMIT ?
    ''',
          [limit],
        );
        return rows.map(_read).toList(growable: false);
      });

  @override
  Future<void> save(Exercise exercise) => _db.transaction((tx) async {
        final row = <String, Object?>{
          'id': exercise.id,
          'name': exercise.name,
          'category': exercise.category.code,
          'equipment': exercise.equipment.code,
          'default_unit': exercise.defaultUnit.code,
          'note': exercise.note,
          'created_at': utcValue(exercise.createdAt),
          'updated_at': utcValue(exercise.updatedAt),
        };
        final updated = await tx.update(
          'exercises',
          row,
          where: 'id = ?',
          whereArgs: [exercise.id],
        );
        if (updated == 0) await tx.insert('exercises', row);
      });

  @override
  Future<void> delete(String id) => databaseGuard(() async {
        await _db.database
            .delete('exercises', where: 'id = ?', whereArgs: [id]);
      });

  static Exercise _read(Map<String, Object?> row) => Exercise(
        id: row['id'] as String,
        name: row['name'] as String,
        category: ExerciseCategory.fromCode(row['category'] as String),
        equipment: ExerciseEquipment.fromCode(row['equipment'] as String),
        defaultUnit: WeightUnit.fromCode(row['default_unit'] as String),
        note: row['note'] as String,
        createdAt: readUtc(row['created_at'])!,
        updatedAt: readUtc(row['updated_at'])!,
      );
}
