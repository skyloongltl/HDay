import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../workout/domain/workout_session.dart';
import '../data/sqlite_history_repository.dart';
import '../domain/history_models.dart';
import '../domain/history_repository.dart';
import 'history_controller.dart';

final historyRepositoryProvider = FutureProvider<HistoryRepository>(
  (ref) async =>
      SqliteHistoryRepository(await ref.watch(appDatabaseProvider.future)),
);
final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryState>(
  HistoryController.new,
);
final recentHistoryProvider = FutureProvider<List<WorkoutSession>>(
  (ref) async => (await ref.watch(historyRepositoryProvider.future)).recent(),
);
final exerciseHistorySummaryProvider =
    FutureProvider.family<ExerciseHistorySummary, String>(
  (ref, id) async => ExerciseHistorySummary.fromRecords(
    await (await ref.watch(historyRepositoryProvider.future))
        .exerciseRecords(id),
  ),
);
