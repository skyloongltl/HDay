import 'dart:io';
import 'dart:ui' as ui;
import 'package:fitness_counter/core/data/app_database.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/features/workout/domain/workout_draft.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:fitness_counter/theme/app_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> savePerformanceSession(
  AppDatabase db, {
  required String id,
  required DateTime start,
  String exerciseId = 'bench-press',
  WeightUnit unit = WeightUnit.kg,
  double weight = 40,
  int reps = 8,
  LocalDate? date,
}) async {
  final draft = WorkoutDraft(
    workoutDate: date ?? LocalDate(2026, 9, 15),
    exercises: [
      WorkoutExercise(
        id: 'e1',
        exerciseId: exerciseId,
        nameSnapshot: '杠铃卧推',
        categorySnapshot: ExerciseCategory.chest,
        equipmentSnapshot: ExerciseEquipment.barbell,
        unitSnapshot: unit,
        sourcePlanId: 'plan-1',
        sourcePlanName: '推拉腿计划',
        sourceRevisionId: 'revision-1',
        sourceDayNumber: 1,
        sourceDayName: '胸肩训练',
        note: '',
        targetRestSeconds: 90,
        order: 0,
        temporary: false,
        sets: [
          WorkoutSet(
            id: 's1',
            order: 0,
            plannedWeight: 20,
            plannedReps: 8,
            unit: unit,
            temporary: false,
          ),
          WorkoutSet(
            id: 's2',
            order: 1,
            plannedWeight: 20,
            plannedReps: 8,
            unit: unit,
            temporary: true,
          ),
        ],
      ),
    ],
  );
  final repository = SqliteWorkoutRepository(db);
  var session = WorkoutMachine.start(id: id, draft: draft, nowUtc: start);
  await repository.create(session);
  session = WorkoutMachine.transition(session, const StartSet('s1'), start);
  session = WorkoutMachine.transition(
    session,
    CompleteSet('s1', actualWeight: weight, actualReps: reps),
    start.add(const Duration(seconds: 30)),
  );
  session = WorkoutMachine.transition(
    session,
    const PrepareFinish(),
    start.add(const Duration(minutes: 1)),
  );
  await repository.save(session, expectedRevision: 0);
  await repository.saveCompleted(
    id,
    note: '动作稳定，下次继续',
    expectedRevision: 1,
    endedAtUtc: start.add(const Duration(minutes: 1)),
  );
}

Future<void> loadHistoryFonts() async {
  final font = File('C:/Windows/Fonts/NotoSansSC-VF.ttf');
  if (font.existsSync()) {
    await (FontLoader(AppTheme.fontFamily)
          ..addFont(font.readAsBytes().then(ByteData.sublistView)))
        .load();
  }
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
}

Future<void> settleHistory(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 25));
  }
  await tester.pumpAndSettle();
}

Future<void> captureHistory(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(const Key('app-render')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final directory =
        Directory('../.superpowers/sdd/2026-09-15-flutter-rewrite/task-11-ui');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}
