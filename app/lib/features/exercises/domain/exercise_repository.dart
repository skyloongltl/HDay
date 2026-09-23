import 'exercise.dart';

abstract interface class ExerciseRepository {
  Future<List<Exercise>> search({
    String query = '',
    String? category,
    String? equipment,
  });

  Future<Exercise?> find(String id);

  Future<List<Exercise>> recent({int limit = 10});

  Future<void> save(Exercise exercise);

  Future<void> delete(String id);
}
