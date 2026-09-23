import 'dart:async';

import 'package:fitness_counter/core/domain/app_failure.dart';
import 'package:fitness_counter/features/workout/application/workout_controller.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:fitness_counter/features/workout/domain/workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_clock.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  test('restore failure is explicit and retry restores the same session',
      () async {
    final repository = _FailOnceRepository();
    final seedClock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final seeded = WorkoutMachine.start(
      id: 'existing',
      draft: twoSetDraft(),
      nowUtc: seedClock.nowUtc(),
    );
    await repository.create(seeded);
    repository.failNextRestore = true;
    final controller = WorkoutController(
      repository: repository,
      clock: seedClock,
    );
    addTearDown(controller.dispose);

    await expectLater(controller.restore(), throwsA(isA<AppFailure>()));
    expect(controller.state.failure, isNotNull);
    expect(controller.state.session, isNull);

    await controller.retry();
    expect(controller.state.session!.id, 'existing');
    expect(controller.state.failure, isNull);
  });

  test('concurrent restore callers share one repository lookup', () async {
    final repository = _FailOnceRepository();
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    repository.stored = WorkoutMachine.start(
      id: 'existing',
      draft: twoSetDraft(),
      nowUtc: clock.nowUtc(),
    );
    repository.restoreGate = Completer<void>();
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);

    final first = controller.restore();
    while (repository.restoreCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    final second = controller.restore();
    repository.restoreGate!.complete();
    await Future.wait([first, second]);

    expect(repository.restoreCalls, 1);
    expect(controller.state.session!.id, 'existing');
  });

  test('retry adopts one created session after a lost start response',
      () async {
    final repository = _FailOnceRepository()..commitThenFailNextCreate = true;
    final controller = WorkoutController(
      repository: repository,
      clock: FakeClock(DateTime.utc(2026, 9, 15, 10)),
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.start(twoSetDraft()),
      throwsA(isA<AppFailure>()),
    );
    final createdId = repository.stored!.id;
    await controller.retry();

    expect(controller.state.session!.id, createdId);
    expect(repository.createCalls, 1);
  });

  test('start lookup failure retains the captured draft and retries creation',
      () async {
    final repository = _FailOnceRepository()..failNextRestore = true;
    final controller = WorkoutController(
      repository: repository,
      clock: FakeClock(DateTime.utc(2026, 9, 15, 10)),
      sessionIdFactory: () => 'captured-start',
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.start(twoSetDraft()),
      throwsA(isA<AppFailure>()),
    );
    expect(controller.state.pendingSession!.id, 'captured-start');
    expect(controller.state.pendingSession!.exercises, hasLength(1));
    expect(repository.createCalls, 0);

    await controller.retry();
    expect(controller.state.session!.id, 'captured-start');
    expect(controller.state.session!.exercises.first.sets, hasLength(2));
    expect(repository.createCalls, 1);
  });

  test('failed dispatch retains committed and exact pending state for retry',
      () async {
    final repository = _FailOnceRepository();
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);
    await controller.start(twoSetDraft());
    repository.failNextSave = true;

    await expectLater(
      controller.dispatch(const StartSet('s1')),
      throwsA(isA<AppFailure>()),
    );
    final pending = controller.state.pendingSession;
    expect(controller.state.session!.activeSetId, isNull);
    expect(pending!.activeSetId, 's1');
    expect(controller.state.failure, isNotNull);

    clock.advance(const Duration(minutes: 5));
    await controller.retry();
    expect(controller.state.session!.activeSetId, 's1');
    expect(
      controller.state.session!.exercises.first.sets.first.startedAt,
      DateTime.utc(2026, 9, 15, 10),
    );
    expect(repository.saveCalls, 2);
  });

  test('failed dispatch rejects a different command and preserves exact retry',
      () async {
    final repository = _FailOnceRepository();
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);
    await controller.start(twoSetDraft());
    repository.failNextSave = true;

    await expectLater(
      controller.dispatch(const StartSet('s1')),
      throwsA(isA<AppFailure>()),
    );
    final pending = controller.state.pendingSession;
    final failure = controller.state.failure;

    await expectLater(
      controller.dispatch(const SelectSet('s2')),
      throwsA(same(failure)),
    );
    await expectLater(
      controller.start(oneSetDraft()),
      throwsA(same(failure)),
    );
    await expectLater(
      controller.save(note: '不得覆盖'),
      throwsA(same(failure)),
    );
    await expectLater(controller.discard(), throwsA(same(failure)));
    await expectLater(controller.restore(), throwsA(same(failure)));
    expect(controller.state.pendingSession, same(pending));
    expect(controller.state.pendingSession!.activeSetId, 's1');
    expect(controller.state.pendingSession!.selectedSetId, 's1');

    await controller.retry();
    expect(controller.state.session!.activeSetId, 's1');
    expect(repository.saveCalls, 2);
  });

  test('retry acknowledges the exact candidate after a lost save response',
      () async {
    final repository = _FailOnceRepository();
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);
    await controller.start(twoSetDraft());
    repository.commitThenFailNextSave = true;

    await expectLater(
      controller.dispatch(const StartSet('s1')),
      throwsA(isA<AppFailure>()),
    );
    expect(repository.stored!.revision, 1);
    expect(controller.state.session!.revision, 0);

    clock.advance(const Duration(minutes: 3));
    await controller.retry();

    expect(controller.state.session!.revision, 1);
    expect(controller.state.session!.activeSetId, 's1');
    expect(controller.state.pendingSession, isNull);
    expect(repository.saveCalls, 2);
  });

  test('failed final save keeps note candidate and refreshes only on retry',
      () async {
    final repository = _FailOnceRepository();
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    var refreshCount = 0;
    final controller = WorkoutController(
      repository: repository,
      clock: clock,
      refreshProjections: () async => refreshCount += 1,
    );
    addTearDown(controller.dispose);
    await controller.start(oneSetDraft());
    await controller.dispatch(const StartSet('s1'));
    clock.advance(const Duration(seconds: 20));
    await controller.dispatch(
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    );
    await controller.dispatch(const PrepareFinish());
    final beforeFailureRefreshes = refreshCount;
    repository.failNextCompletedSave = true;

    await expectLater(
      controller.save(note: '保留备注'),
      throwsA(isA<AppFailure>()),
    );
    expect(controller.state.session!.phase, WorkoutPhase.finishing);
    expect(controller.state.pendingSession!.note, '保留备注');
    expect(refreshCount, beforeFailureRefreshes);

    await controller.retry();
    expect(controller.state.session, isNull);
    expect(repository.stored!.phase, WorkoutPhase.saved);
    expect(repository.stored!.note, '保留备注');
    expect(refreshCount, beforeFailureRefreshes + 1);
  });

  test('failed final save rejects discard and preserves the note retry',
      () async {
    final repository = _FailOnceRepository();
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);
    await controller.start(oneSetDraft());
    await controller.dispatch(const StartSet('s1'));
    clock.advance(const Duration(seconds: 20));
    await controller.dispatch(
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
    );
    await controller.dispatch(const PrepareFinish());
    repository.failNextCompletedSave = true;

    await expectLater(
      controller.save(note: '必须保留'),
      throwsA(isA<AppFailure>()),
    );
    final pending = controller.state.pendingSession;
    final failure = controller.state.failure;

    await expectLater(controller.discard(), throwsA(same(failure)));
    expect(controller.state.pendingSession, same(pending));
    expect(controller.state.pendingSession!.note, '必须保留');
    expect(repository.stored, isNotNull);

    await controller.retry();
    expect(controller.state.session, isNull);
    expect(repository.stored!.phase, WorkoutPhase.saved);
    expect(repository.stored!.note, '必须保留');
  });

  test('failed discard retains the intended session until retry succeeds',
      () async {
    final repository = _FailOnceRepository();
    var refreshCount = 0;
    final controller = WorkoutController(
      repository: repository,
      clock: FakeClock(DateTime.utc(2026, 9, 15, 10)),
      refreshProjections: () async => refreshCount += 1,
    );
    addTearDown(controller.dispose);
    final id = await controller.start(twoSetDraft());
    final beforeFailureRefreshes = refreshCount;
    repository.failNextDiscard = true;

    await expectLater(controller.discard(), throwsA(isA<AppFailure>()));
    expect(controller.state.session!.id, id);
    expect(controller.state.pendingSession!.id, id);
    expect(refreshCount, beforeFailureRefreshes);

    await controller.retry();
    expect(controller.state.session, isNull);
    expect(repository.stored, isNull);
    expect(refreshCount, beforeFailureRefreshes + 1);
  });

  test('failed discard rejects start and preserves the discard retry',
      () async {
    final repository = _FailOnceRepository();
    final controller = WorkoutController(
      repository: repository,
      clock: FakeClock(DateTime.utc(2026, 9, 15, 10)),
      sessionIdFactory: () => 'replacement',
    );
    addTearDown(controller.dispose);
    final originalId = await controller.start(twoSetDraft());
    repository.failNextDiscard = true;

    await expectLater(controller.discard(), throwsA(isA<AppFailure>()));
    final pending = controller.state.pendingSession;
    final failure = controller.state.failure;

    await expectLater(
      controller.start(oneSetDraft()),
      throwsA(same(failure)),
    );
    expect(controller.state.pendingSession, same(pending));
    expect(controller.state.pendingSession!.id, originalId);

    await controller.retry();
    expect(controller.state.session, isNull);
    expect(repository.stored, isNull);
  });

  test('CAS conflict keeps committed and exact pending command visible',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repository = SqliteWorkoutRepository(db);
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);
    await controller.start(twoSetDraft());
    final external = WorkoutMachine.transition(
      controller.state.session!,
      const SelectSet('s2'),
      clock.nowUtc(),
    );
    await repository.save(external, expectedRevision: 0);

    await expectLater(
      controller.dispatch(const StartSet('s1')),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.code,
          'code',
          FailureCode.conflict,
        ),
      ),
    );

    expect(controller.state.session!.revision, 0);
    expect(controller.state.session!.activeSetId, isNull);
    expect(controller.state.pendingSession!.activeSetId, 's1');
    expect((await repository.findUnfinished())!.selectedSetId, 's2');
  });

  test('zero-completed save guard is exposed as controller failure', () async {
    final repository = _FailOnceRepository();
    final clock = FakeClock(DateTime.utc(2026, 9, 15, 10));
    final started = WorkoutMachine.start(
      id: 'zero-completed',
      draft: oneSetDraft(),
      nowUtc: clock.nowUtc(),
    );
    final invalidFinishing = started.copyWith(
      phase: WorkoutPhase.finishing,
      timer: started.timer.pause(clock.nowUtc()),
    );
    await repository.create(invalidFinishing);
    final controller = WorkoutController(repository: repository, clock: clock);
    addTearDown(controller.dispose);
    await controller.restore();

    await expectLater(
      controller.save(note: 'must not save'),
      throwsA(isA<AppFailure>()),
    );

    expect(controller.state.failure, isNotNull);
    expect(controller.state.isSaving, isFalse);
    expect(controller.state.session!.phase, WorkoutPhase.finishing);
    expect(repository.stored!.phase, WorkoutPhase.finishing);
  });
}

final class _FailOnceRepository implements WorkoutRepository {
  WorkoutSession? stored;
  bool failNextSave = false;
  bool commitThenFailNextSave = false;
  int saveCalls = 0;
  bool commitThenFailNextCreate = false;
  int createCalls = 0;
  bool failNextCompletedSave = false;
  bool failNextDiscard = false;
  bool failNextRestore = false;
  int restoreCalls = 0;
  Completer<void>? restoreGate;

  @override
  Future<void> create(WorkoutSession session) async {
    createCalls += 1;
    if (stored != null) {
      throw const AppFailure(FailureCode.conflict, detail: 'duplicate');
    }
    stored = session;
    if (commitThenFailNextCreate) {
      commitThenFailNextCreate = false;
      throw const AppFailure(FailureCode.persistence, detail: 'lost response');
    }
  }

  @override
  Future<void> discard(String id) async {
    if (failNextDiscard) {
      failNextDiscard = false;
      throw const AppFailure(FailureCode.persistence, detail: 'disk full');
    }
    stored = null;
  }

  @override
  Future<WorkoutSession?> find(String id) async => stored;

  @override
  Future<WorkoutSession?> findUnfinished() async {
    restoreCalls += 1;
    await restoreGate?.future;
    if (failNextRestore) {
      failNextRestore = false;
      throw const AppFailure(FailureCode.persistence, detail: 'read failed');
    }
    return stored;
  }

  @override
  Future<void> save(
    WorkoutSession session, {
    required int expectedRevision,
  }) async {
    saveCalls += 1;
    if (failNextSave) {
      failNextSave = false;
      throw const AppFailure(FailureCode.persistence, detail: 'disk full');
    }
    if (stored!.revision != expectedRevision) {
      throw const AppFailure(FailureCode.conflict, detail: 'stale');
    }
    stored = session.copyWith(revision: expectedRevision + 1);
    if (commitThenFailNextSave) {
      commitThenFailNextSave = false;
      throw const AppFailure(FailureCode.persistence, detail: 'lost response');
    }
  }

  @override
  Future<void> saveCompleted(
    String id, {
    required String note,
    required int expectedRevision,
    DateTime? endedAtUtc,
  }) async {
    if (failNextCompletedSave) {
      failNextCompletedSave = false;
      throw const AppFailure(FailureCode.persistence, detail: 'disk full');
    }
    final current = stored!;
    if (current.revision != expectedRevision) {
      throw const AppFailure(FailureCode.conflict, detail: 'stale');
    }
    stored = WorkoutMachine.transition(
      current,
      SaveWorkout(note: note),
      endedAtUtc!,
    ).copyWith(revision: expectedRevision + 1);
  }
}
