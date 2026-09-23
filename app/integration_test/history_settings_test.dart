import 'package:fitness_counter/app/router.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/history/data/sqlite_history_repository.dart';
import 'package:fitness_counter/features/settings/data/sqlite_settings_repository.dart';
import 'package:fitness_counter/features/settings/domain/app_settings.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/integration_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'history corrections, source independence, statistics and settings persist',
    (tester) async {
      final clock = IntegrationTestClock(DateTime.utc(2026, 9, 18, 2));
      var app = await launchIntegrationApp(
        tester,
        initialLocation: AppRoutes.exerciseCreate,
        clock: clock,
      );
      addTearDown(() => app.close(tester));
      final exercise = await createExerciseViaUi(
        tester,
        app,
        name: 'Task 14 历史卧推',
        category: ExerciseCategory.chest,
        equipment: ExerciseEquipment.dumbbell,
        unit: WeightUnit.kg,
        note: '原始动作备注',
      );

      final firstStarted = await startFreeWorkoutViaUi(
        tester,
        app,
        exerciseIds: [exercise.id],
      );
      await completeCurrentSetViaUi(tester, app);
      final first = await saveWorkoutViaUi(
        tester,
        app,
        note: '第一场原始备注',
      );
      final originalSet = first.exercises.single.sets.single;

      app.router.go(AppRoutes.exerciseEdit(exercise.id));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('exercise-edit-screen')),
      );
      await tester.tap(find.byKey(const ValueKey('unit-lb')));
      await tester.enterText(
        find.byKey(const ValueKey('exercise-notes')),
        '来源已修改',
      );
      await tester.tap(find.byKey(const ValueKey('exercise-save')));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('exercises-screen')),
      );

      await startFreeWorkoutViaUi(
        tester,
        app,
        exerciseIds: [exercise.id],
      );
      await completeCurrentSetViaUi(tester, app);
      final second = await saveWorkoutViaUi(
        tester,
        app,
        note: '第二场',
      );
      expect(firstStarted.id, first.id);
      expect(second.id, isNot(first.id));

      final history = SqliteHistoryRepository(app.database);
      final records = await history.exerciseRecords(exercise.id);
      expect(records.map((record) => record.unit).toSet(), {
        WeightUnit.kg,
        WeightUnit.lb,
      });
      expect(
        (await history.stats(
          LocalDate(2026, 9, 18),
          weekStart: DateTime.monday,
        ))
            .total,
        1,
      );

      app.router.go('/history/2026-09-18?session=${first.id}');
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('history-day-detail')),
      );
      await tester.ensureVisible(
        find.byKey(ValueKey('correct-${first.id}-${originalSet.id}')),
      );
      await tester.tap(
        find.byKey(ValueKey('correct-${first.id}-${originalSet.id}')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('history-actual-weight')),
        '37.5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('history-actual-reps')),
        '12',
      );
      await tester.tap(
        find.byKey(const ValueKey('history-correction-save')),
      );
      await settleIntegrationApp(tester);
      await tester.ensureVisible(
        find.byKey(ValueKey('history-note-${first.id}')),
      );
      await tester.enterText(
        find.byKey(ValueKey('history-note-${first.id}')),
        '修正后的真实备注',
      );
      await tester.tap(find.byKey(ValueKey('save-note-${first.id}')));
      await settleIntegrationApp(tester);

      final corrected =
          (await SqliteWorkoutRepository(app.database).find(first.id))!;
      final correctedSet = corrected.exercises.single.sets.single;
      expect(correctedSet.actualWeight, 37.5);
      expect(correctedSet.actualReps, 12);
      expect(correctedSet.plannedWeight, originalSet.plannedWeight);
      expect(correctedSet.plannedReps, originalSet.plannedReps);
      expect(correctedSet.unit, originalSet.unit);
      expect(
        corrected.exercises.single.nameSnapshot,
        first.exercises.single.nameSnapshot,
      );
      expect(corrected.note, '修正后的真实备注');

      app.router.go(AppRoutes.settings);
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('settings-screen')),
      );
      await tester.tap(find.byKey(const ValueKey('setting-rest-reminder')));
      await settleIntegrationApp(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('setting-vibration')),
      );
      await tester.tap(find.byKey(const ValueKey('setting-vibration')));
      await settleIntegrationApp(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('setting-week-start')),
      );
      await tester.tap(find.byKey(const ValueKey('setting-week-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.sunday).last);
      await settleIntegrationApp(tester);
      final savedSettings = await SqliteSettingsRepository(app.database).read();
      expect(savedSettings.restReminder, isFalse);
      expect(savedSettings.vibration, isFalse);
      expect(savedSettings.weekStart, WeekStart.sunday);

      await app.database.database.update(
        'app_settings',
        {'theme_id': 'unknown-task14-theme'},
        where: 'id = 1',
      );
      app = await restartIntegrationApp(
        tester,
        app,
        initialLocation: AppRoutes.settings,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('theme-selected-breath-rhythm')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('theme-selected-breath-rhythm')),
        findsOneWidget,
      );
      final reopenedSettings =
          await SqliteSettingsRepository(app.database).read();
      expect(reopenedSettings.restReminder, isFalse);
      expect(reopenedSettings.vibration, isFalse);
      expect(reopenedSettings.weekStart, WeekStart.sunday);

      app.router.go(AppRoutes.exerciseEdit(exercise.id));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('exercise-edit-screen')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('exercise-delete')),
      );
      await tester.tap(find.byKey(const ValueKey('exercise-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.confirmDelete));
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('exercises-screen')),
      );
      final afterSourceDelete =
          (await SqliteWorkoutRepository(app.database).find(first.id))!;
      expect(afterSourceDelete.exercises.single.nameSnapshot, 'Task 14 历史卧推');
      expect(afterSourceDelete.exercises.single.unitSnapshot, WeightUnit.kg);

      app.router.go('/history/2026-09-18');
      await settleIntegrationApp(
        tester,
        until: find.byKey(const ValueKey('history-day-detail')),
      );
      await _deleteSessionThroughUi(tester, first.id);
      await _deleteSessionThroughUi(tester, second.id);
      expect(find.text(AppStrings.noDateHistory), findsOneWidget);
      expect(
        (await SqliteHistoryRepository(app.database).stats(
          LocalDate(2026, 9, 18),
          weekStart: DateTime.sunday,
        ))
            .total,
        0,
      );
    },
  );
}

Future<void> _deleteSessionThroughUi(
  WidgetTester tester,
  String sessionId,
) async {
  await tester.ensureVisible(
    find.byKey(ValueKey('delete-session-$sessionId')),
  );
  await tester.tap(find.byKey(ValueKey('delete-session-$sessionId')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.confirmDelete));
  await settleIntegrationApp(tester);
}
