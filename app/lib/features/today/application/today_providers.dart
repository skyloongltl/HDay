import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/sqlite_today_repository.dart';
import '../domain/today_overview.dart';
import '../domain/today_repository.dart';
import 'today_controller.dart';

final todayRepositoryProvider = FutureProvider<TodayRepository>(
  (ref) async =>
      SqliteTodayRepository(await ref.watch(appDatabaseProvider.future)),
);

final todayControllerProvider =
    StateNotifierProvider<TodayController, AsyncValue<TodayOverview>>((ref) {
  final controller = TodayController(
    repository: ref.watch(todayRepositoryProvider).requireValue,
    clock: ref.watch(clockProvider),
  );
  controller.refresh();
  return controller;
});

final todayOverviewProvider = FutureProvider<TodayOverview>((ref) async {
  final repository = await ref.watch(todayRepositoryProvider.future);
  return repository.load(ref.watch(clockProvider).today());
});
