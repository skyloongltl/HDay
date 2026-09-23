import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/domain/workout_draft.dart';
import 'package:fitness_counter/features/workout/presentation/workout_draft_card.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/app_theme.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('planned draft exposes source, set editors, and reorder actions',
      (tester) async {
    double? weight;
    int? reps;
    var movedExerciseDown = false;
    var movedSetDown = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(breathRhythmDefinition),
        home: Scaffold(
          body: WorkoutDraftCard(
            exercise: _exercise(),
            canMoveExerciseUp: false,
            canMoveExerciseDown: true,
            onMoveExerciseUp: () {},
            onMoveExerciseDown: () => movedExerciseDown = true,
            onRemove: () {},
            onAddSet: () {},
            onDeleteSet: (_) {},
            onUpdateSet: (_, nextWeight, nextReps) {
              if (nextWeight != null) weight = nextWeight;
              if (nextReps != null) reps = nextReps;
            },
            onMoveSetUp: (_) {},
            onMoveSetDown: (_) => movedSetDown = true,
          ),
        ),
      ),
    );

    expect(find.text('计划：力量计划 · 版本 r1 · D2 下肢'), findsOneWidget);
    expect(find.byKey(const ValueKey('set-weight-s1')), findsOneWidget);
    expect(find.byKey(const ValueKey('set-reps-s1')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('set-weight-s1')), '32.5');
    await tester.enterText(find.byKey(const ValueKey('set-reps-s1')), '12');
    expect(weight, 32.5);
    expect(reps, 12);
    await tester.tap(find.byTooltip(AppStrings.moveExerciseDown));
    await tester.tap(find.byTooltip(AppStrings.moveSetDown).first);
    expect(movedExerciseDown, isTrue);
    expect(movedSetDown, isTrue);

    for (final element in find.byType(IconButton).evaluate()) {
      expect(
        tester.getSize(find.byWidget(element.widget)).shortestSide,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('partial and invalid set input shows errors without draft writes',
      (tester) async {
    final updates = <(double?, int?)>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(breathRhythmDefinition),
        home: Scaffold(
          body: WorkoutDraftCard(
            exercise: _exercise(),
            canMoveExerciseUp: false,
            canMoveExerciseDown: false,
            onMoveExerciseUp: () {},
            onMoveExerciseDown: () {},
            onRemove: () {},
            onAddSet: () {},
            onDeleteSet: (_) {},
            onUpdateSet: (_, weight, reps) => updates.add((weight, reps)),
            onMoveSetUp: (_) {},
            onMoveSetDown: (_) {},
          ),
        ),
      ),
    );
    final weight = find.byKey(const ValueKey('set-weight-s1'));
    final reps = find.byKey(const ValueKey('set-reps-s1'));

    for (final value in ['', '-1', 'abc']) {
      await tester.enterText(weight, value);
      await tester.pump();
      expect(find.text(AppStrings.invalidWeight), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    for (final value in ['', '0', '-1', 'abc']) {
      await tester.enterText(reps, value);
      await tester.pump();
      expect(find.text(AppStrings.invalidReps), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    expect(updates, isEmpty);

    await tester.enterText(weight, '0');
    await tester.enterText(reps, '1');
    await tester.pump();
    expect(updates, [(0.0, null), (null, 1)]);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('draft card fits $width width at $scale text scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(breathRhythmDefinition),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: WorkoutDraftCard(
                    exercise: _exercise(),
                    canMoveExerciseUp: false,
                    canMoveExerciseDown: false,
                    onMoveExerciseUp: () {},
                    onMoveExerciseDown: () {},
                    onRemove: () {},
                    onAddSet: () {},
                    onDeleteSet: (_) {},
                    onUpdateSet: (_, __, ___) {},
                    onMoveSetUp: (_) {},
                    onMoveSetDown: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

WorkoutExercise _exercise() => WorkoutExercise(
      id: 'pe1',
      exerciseId: 'x1',
      nameSnapshot: '深蹲',
      categorySnapshot: ExerciseCategory.legs,
      equipmentSnapshot: ExerciseEquipment.barbell,
      unitSnapshot: WeightUnit.kg,
      sourcePlanId: 'p1',
      sourcePlanName: '力量计划',
      sourceRevisionId: 'r1',
      sourceDayNumber: 2,
      sourceDayName: '下肢',
      note: '',
      targetRestSeconds: 90,
      order: 0,
      temporary: false,
      sets: [
        WorkoutSet(
          id: 's1',
          order: 0,
          plannedWeight: 30,
          plannedReps: 10,
          unit: WeightUnit.kg,
          temporary: false,
        ),
        WorkoutSet(
          id: 's2',
          order: 1,
          plannedWeight: 30,
          plannedReps: 10,
          unit: WeightUnit.kg,
          temporary: false,
        ),
      ],
    );
