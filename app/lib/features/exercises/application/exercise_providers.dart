import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../data/sqlite_exercise_repository.dart';
import '../domain/exercise.dart';
import '../domain/exercise_repository.dart';
import 'exercise_controller.dart';

final exerciseControllerProvider =
    AsyncNotifierProvider<ExerciseController, ExerciseState>(
  ExerciseController.new,
);
final exercisePickerControllerProvider =
    AsyncNotifierProvider<ExerciseController, ExerciseState>(
  ExerciseController.new,
);
final exerciseRepositoryProvider = FutureProvider<ExerciseRepository>(
  (ref) async =>
      SqliteExerciseRepository(await ref.watch(appDatabaseProvider.future)),
);
final exerciseByIdProvider = FutureProvider.family<Exercise?, String>(
  (ref, id) async =>
      (await ref.watch(exerciseRepositoryProvider.future)).find(id),
);

/// Each editing session loads a fresh committed row. Catalog/detail refreshes
/// never replace the form's initial snapshot while its save is in flight.
final exerciseEditorSourceProvider =
    FutureProvider.autoDispose.family<Exercise?, String>(
  (ref, id) async =>
      (await ref.watch(exerciseRepositoryProvider.future)).find(id),
);
