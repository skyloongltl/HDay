import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/features/workout/application/workout_providers.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/fake_clock.dart';
import '../../../support/rest_effect_fakes.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test('published status refreshes on resume after permission change',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final platform = EffectHarness();
    final now = DateTime.utc(2026, 9, 17);
    var session =
        WorkoutMachine.start(id: 'resume', draft: twoSetDraft(), nowUtc: now);
    session = WorkoutMachine.transition(session, const StartSet('s1'), now);
    session = WorkoutMachine.transition(
      session,
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
      now,
    );
    await SqliteWorkoutRepository(db).create(session);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => db),
        clockProvider.overrideWithValue(FakeClock(now)),
        restEffectsEnabledProvider.overrideWithValue(true),
        restEffectsControllerProvider.overrideWithValue(platform.effects),
        workoutProjectionRefreshProvider.overrideWithValue(() async {}),
      ],
    );
    await container.read(appDatabaseProvider.future);
    {
      final controller = container.read(workoutControllerProvider.notifier);
      await controller.restore();
      await controller.refreshRestEffects();
    }
    expect(
      container
          .read(restEffectsStatusProvider)
          .permission
          ?.notificationsGranted,
      isTrue,
    );
    platform.notification.granted = false;
    platform.notification.exact = false;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final status = container.read(restEffectsStatusProvider);
    expect(status.permission?.notificationsGranted, isFalse);
    expect(status.permission?.exactAlarmsGranted, isFalse);
    expect(status.isTimingDegraded, isTrue);
    expect(platform.notification.active, isEmpty);
    expect(platform.vibration.active, hasLength(1));
    container.dispose();
    await platform.effects.dispose();
  });
}
