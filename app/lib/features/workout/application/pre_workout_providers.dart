import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../today/application/today_providers.dart';
import '../domain/workout_draft.dart';
import 'pre_workout_controller.dart';

typedef PreWorkoutRequest = ({String date, bool freeWorkout});

final preWorkoutControllerProvider = StateNotifierProvider.autoDispose
    .family<PreWorkoutController, WorkoutDraft?, PreWorkoutRequest>(
        (ref, request) {
  return PreWorkoutController(
    todayRepository: ref.watch(todayRepositoryProvider).requireValue,
  );
});
