import 'dart:async';
import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/features/settings/domain/app_settings.dart';
import 'package:fitness_counter/features/workout/application/workout_controller.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/fake_clock.dart';
import '../../../support/rest_effect_fakes.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  test(
      'failed rest write schedules nothing and successful retry schedules once',
      () async {
    final h = await _create();
    await h.controller.dispatch(const StartSet('s1'));
    h.repository.failSave = true;
    await expectLater(
      h.controller
          .dispatch(const CompleteSet('s1', actualWeight: 20, actualReps: 8)),
      throwsA(isA<AppFailure>()),
    );
    await _drain();
    expect(h.platform.notification.events, isEmpty);
    expect(h.platform.vibration.events, isEmpty);
    await h.controller.retry();
    await _drain();
    expect(h.platform.notification.events, ['schedule']);
    expect(h.platform.vibration.events, ['schedule']);
    expect(h.controller.state.session!.phase, WorkoutPhase.resting);
  });
  for (final exit in ['startNext', 'discard', 'finishAndSave']) {
    test('committed $exit cancels effects even if projection refresh fails',
        () async {
      var refreshFails = false;
      final h = await _create(
        refresh: () async {
          if (refreshFails) throw StateError('projection read failed');
        },
      );
      await _rest(h.controller);
      await _drain();
      expect(h.platform.notification.active, hasLength(1));
      refreshFails = true;
      final action = switch (exit) {
        'startNext' => h.controller.dispatch(const StartSet('s2')),
        'discard' => h.controller.discard(),
        _ => h.controller.dispatch(const PrepareFinish()),
      };
      await expectLater(action, throwsA(isA<AppFailure>()));
      await _drain();
      expect(h.platform.notification.active, isEmpty);
      expect(h.platform.vibration.active, isEmpty);
      if (exit == 'finishAndSave') {
        refreshFails = false;
        await h.controller.retry();
        refreshFails = true;
        await expectLater(
          h.controller.save(note: 'done'),
          throwsA(isA<AppFailure>()),
        );
        await _drain();
        expect(h.controller.state.session, isNull);
        expect(h.platform.wake.values.last, isFalse);
      }
    });
  }
  test('slow earlier settings cannot rearm a committed discarded rest',
      () async {
    Completer<AppSettings>? gate;
    final h = await _create(
      settings: () => gate?.future ?? Future.value(AppSettings()),
    );
    await h.controller.dispatch(const StartSet('s1'));
    await _drain();
    gate = Completer<AppSettings>();
    await h.controller
        .dispatch(const CompleteSet('s1', actualWeight: 20, actualReps: 8));
    final oldRead = gate;
    gate = null;
    await h.controller.discard();
    await _drain();
    oldRead.complete(AppSettings());
    await _drain();
    expect(h.platform.notification.active, isEmpty);
    expect(h.platform.vibration.active, isEmpty);
  });
  test('outer permission query failure never gates vibration or screen release',
      () async {
    final h = await _create();
    h.platform.notification.failQuery = true;
    await _rest(h.controller);
    await _drain();
    expect(h.platform.vibration.active, hasLength(1));
    await h.controller.discard();
    await _drain();
    expect(h.platform.vibration.active, isEmpty);
    expect(h.platform.wake.values.last, isFalse);
  });
}

Future<void> _rest(WorkoutController c) async {
  await c.dispatch(const StartSet('s1'));
  await c.dispatch(const CompleteSet('s1', actualWeight: 20, actualReps: 8));
}

Future<void> _drain() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<
    ({
      WorkoutController controller,
      _FailSave repository,
      EffectHarness platform
    })> _create({
  Future<void> Function()? refresh,
  Future<AppSettings> Function()? settings,
}) async {
  final db = await openTestDatabase();
  addTearDown(db.close);
  final repository = _FailSave(SqliteWorkoutRepository(db));
  final platform = EffectHarness();
  addTearDown(platform.effects.dispose);
  final controller = WorkoutController(
    repository: repository,
    clock: FakeClock(DateTime.utc(2026, 9, 17)),
    refreshProjections: refresh,
    restEffectsController: platform.effects,
    restEffectsSettings: settings ?? () async => AppSettings(),
  );
  addTearDown(controller.dispose);
  controller.setWorkoutScreenVisible('test-route', true);
  await controller.start(twoSetDraft());
  await _drain();
  return (controller: controller, repository: repository, platform: platform);
}

final class _FailSave implements WorkoutRepository {
  _FailSave(this.delegate);
  final WorkoutRepository delegate;
  bool failSave = false;
  @override
  Future<void> create(WorkoutSession session) => delegate.create(session);
  @override
  Future<void> discard(String id) => delegate.discard(id);
  @override
  Future<WorkoutSession?> find(String id) => delegate.find(id);
  @override
  Future<WorkoutSession?> findUnfinished() => delegate.findUnfinished();
  @override
  Future<void> save(
    WorkoutSession session, {
    required int expectedRevision,
  }) async {
    if (failSave) {
      failSave = false;
      throw const AppFailure(FailureCode.persistence);
    }
    await delegate.save(session, expectedRevision: expectedRevision);
  }

  @override
  Future<void> saveCompleted(
    String id, {
    required String note,
    required int expectedRevision,
    DateTime? endedAtUtc,
  }) =>
      delegate.saveCompleted(
        id,
        note: note,
        expectedRevision: expectedRevision,
        endedAtUtc: endedAtUtc,
      );
}
