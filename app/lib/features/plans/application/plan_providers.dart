import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../data/sqlite_plan_repository.dart';
import '../domain/plan_repository.dart';
import 'plan_controller.dart';
import 'plan_editor_controller.dart';

final planRepositoryProvider = FutureProvider<PlanRepository>(
  (ref) async =>
      SqlitePlanRepository(await ref.watch(appDatabaseProvider.future)),
);
final planControllerProvider =
    AsyncNotifierProvider<PlanController, PlanListState>(PlanController.new);

/// Editor routes wait for planRepositoryProvider before opening this family.
/// autoDispose gives every reopened route a fresh committed source snapshot.
final planEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<PlanEditorController, PlanDraft, String?>((ref, id) {
  final controller = PlanEditorController(
    ref.watch(planRepositoryProvider).requireValue,
    ref.watch(clockProvider),
  );
  controller.open(id);
  return controller;
});
