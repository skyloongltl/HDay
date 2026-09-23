import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/platform/android_notification_gateway.dart';
import '../../../core/platform/android_vibration_gateway.dart';
import '../../../core/platform/android_wake_lock_gateway.dart';
import '../../settings/application/settings_providers.dart';
import '../../today/application/today_providers.dart';
import '../data/sqlite_workout_repository.dart';
import '../domain/workout_repository.dart';
import 'rest_effects_controller.dart';
import 'workout_controller.dart';
import 'workout_view_state.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => SqliteWorkoutRepository(
    ref.watch(appDatabaseProvider).requireValue,
  ),
);

final workoutProjectionRefreshProvider = Provider<WorkoutProjectionRefresh>(
  (ref) => () async {
    ref.invalidate(todayOverviewProvider);
    await ref.read(todayControllerProvider.notifier).refresh();
  },
);

final restEffectsControllerProvider = Provider<RestEffectsController>((ref) {
  final controller = RestEffectsController(
    notificationGateway: AndroidNotificationGateway(),
    vibrationGateway: AndroidVibrationGateway(),
    wakeLockGateway: AndroidWakeLockGateway(),
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  unawaited(controller.refreshPermission());
  return controller;
});

final restEffectsEnabledProvider = Provider<bool>((ref) => Platform.isAndroid);
final restEffectsStatusProvider = Provider<RestEffectsStatus>((ref) {
  final status = ref.watch(restEffectsControllerProvider).status;
  status.addListener(ref.invalidateSelf);
  ref.onDispose(() => status.removeListener(ref.invalidateSelf));
  return status.value;
});

final workoutControllerProvider =
    StateNotifierProvider<WorkoutController, WorkoutViewState>((ref) {
  final effects = ref.watch(restEffectsEnabledProvider)
      ? ref.watch(restEffectsControllerProvider)
      : null;
  final controller = WorkoutController(
    repository: ref.watch(workoutRepositoryProvider),
    clock: ref.watch(clockProvider),
    refreshProjections: ref.watch(workoutProjectionRefreshProvider),
    restEffectsController: effects,
    restEffectsSettings: effects == null
        ? null
        : () => ref
            .read(settingsRepositoryProvider.future)
            .then((repository) => repository.read()),
  );
  unawaited(controller.restore().catchError((_) {}));
  if (effects != null) {
    final observer = _RestEffectsLifecycleObserver(controller);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  }
  return controller;
});

final class _RestEffectsLifecycleObserver extends WidgetsBindingObserver {
  _RestEffectsLifecycleObserver(this.controller);
  final WorkoutController controller;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.refreshRestEffects());
    }
  }
}
