import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_counter/features/exercises/application/exercise_providers.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/exercises/presentation/exercise_picker_sheet.dart';
import 'package:fitness_counter/features/workout/data/sqlite_workout_repository.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/persistence_fixtures.dart';
import '../../../support/pump_app.dart';
import '../../../support/test_database.dart';
import '../application/exercise_controller_test.dart' show draft;

void main() {
  setUpAll(() async {
    // Host-only visual evidence uses the installed CJK font; no user font is shipped.
    final font = File('C:/Windows/Fonts/msyh.ttc');
    if (font.existsSync()) {
      final loader = FontLoader(AppTheme.fontFamily)
        ..addFont(
          font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('library search matches the compact prototype geometry',
      (tester) async {
    await pumpFitnessApp(tester, initialLocation: '/exercises');

    final search = find.byKey(const ValueKey('exercise-search'));
    final searchSurface = find.byKey(const ValueKey('exercise-search-surface'));
    final searchIcon = find.descendant(
      of: search,
      matching: find.byIcon(Icons.search),
    );

    expect(tester.getSize(search).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(searchSurface).height, 40);
    expect(tester.widget<Icon>(searchIcon).size, 14);
    expect(
      tester.getCenter(searchIcon).dy,
      closeTo(tester.getCenter(searchSurface).dy, 0.5),
    );
  });

  testWidgets('empty name is rejected without a SQLite write or navigation',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/exercise-create',
    );
    await tester.enterText(find.byKey(const Key('exercise-name')), '   ');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('exercise-primary-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('exercise-primary-save')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.exerciseNameRequired), findsOneWidget);
    expect(router.state.uri.path, '/exercise-create');
    expect(
      await tester.runAsync(() => SqliteExerciseRepository(db).search()),
      isEmpty,
    );
  });

  testWidgets(
      'library opens the detail contract and editor persists category equipment and notes',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await tester
        .runAsync(() => SqliteExerciseRepository(db).save(draft('a', '原动作')));
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/exercises',
    );
    await tester.tap(find.byKey(const Key('library-exercise-a')));
    await settleExercise(tester);
    expect(router.state.uri.path, '/exercise-detail/a');
    await tester.tap(find.text(AppStrings.edit));
    await settleExercise(tester);
    expect(router.state.uri.path, '/exercise-edit/a');
    await tester.enterText(find.byKey(const Key('exercise-name')), '绳索划船');
    await tester.tap(find.byKey(const Key('category-back')));
    tester
        .widget<TextButton>(find.byKey(const Key('equipment-cable')))
        .onPressed!();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('exercise-notes')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('exercise-notes')), '保持背部稳定');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('exercise-primary-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('exercise-primary-save')));
    await settleExercise(tester);
    expect(router.state.uri.path, '/exercise-detail/a');
    final updated =
        (await tester.runAsync(() => SqliteExerciseRepository(db).find('a')))!;
    expect(updated.name, '绳索划船');
    expect(updated.category, ExerciseCategory.back);
    expect(updated.equipment, ExerciseEquipment.cable);
    expect(updated.note, '保持背部稳定');
  });
  testWidgets(
      'empty library creates first exercise through editor and shows persisted result',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    final router = await pumpFitnessApp(tester, database: db);
    router.go('/exercises');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.createExercise));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise-name')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('exercise-name')), '哑铃卧推');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('exercise-primary-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('exercise-primary-save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('哑铃卧推'), findsOneWidget);
    expect(
      (await tester.runAsync(() => SqliteExerciseRepository(db).search()))!
          .single
          .name,
      '哑铃卧推',
    );
  });

  testWidgets(
      'duplicate exercise stays editable with its draft and an actionable error',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await tester
        .runAsync(() => SqliteExerciseRepository(db).save(draft('a', '哑铃卧推')));
    final router = await pumpFitnessApp(tester, database: db);
    router.go('/exercise-create');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise-name')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('exercise-name')), '哑铃卧推');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('exercise-primary-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('exercise-primary-save')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.duplicateExerciseName), findsOneWidget);
    expect(find.widgetWithText(TextField, '哑铃卧推'), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.back));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('library-exercise-a')),
      findsOneWidget,
      reason: 'canceling a failed edit must still show the persisted library',
    );
  });

  testWidgets(
      'four units persist and deletion requires confirmation then returns to library',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await tester
        .runAsync(() => SqliteExerciseRepository(db).save(draft('a', '卧推')));
    final router = await pumpFitnessApp(tester, database: db);
    for (final unit in WeightUnit.values) {
      router.go('/exercise-edit/a');
      await settleExercise(tester);
      expect(find.byKey(const Key('exercise-name')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(Key('unit-${unit.code}')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(Key('unit-${unit.code}')));
      await tester.tap(find.byKey(const Key('exercise-save')));
      await settleExercise(tester);
      expect(
        router.state.uri.path,
        '/exercises',
        reason: 'successful edit must leave the editor',
      );
      expect(
        (await tester.runAsync(() => SqliteExerciseRepository(db).find('a')))!
            .defaultUnit,
        unit,
      );
    }
    router.go('/exercise-edit/a');
    await settleExercise(tester);
    // Reopening and saving without changing fields must not restore a stale unit.
    await tester.tap(find.byKey(const Key('exercise-save')));
    await settleExercise(tester);
    expect(
      (await tester.runAsync(() => SqliteExerciseRepository(db).find('a')))!
          .defaultUnit,
      WeightUnit.none,
      reason: 'editor must load the last committed unit',
    );
    router.go('/exercise-edit/a');
    await settleExercise(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('exercise-delete')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await captureExercise(tester, 'editor_edit_bottom_390_1.0');
    await tester.tap(find.byKey(const Key('exercise-delete')));
    await tester.pumpAndSettle();
    await captureExercise(tester, 'delete_confirmation_390_1.0');
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    expect(
      await tester.runAsync(() => SqliteExerciseRepository(db).find('a')),
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('exercise-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.confirmDelete));
    await settleExercise(tester);
    expect(router.state.uri.path, '/exercises');
    expect(
      await tester.runAsync(() => SqliteExerciseRepository(db).find('a')),
      isNull,
    );
  });

  testWidgets(
      'write failure retains draft and retry commits without premature navigation',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await tester.runAsync(
      () => db.database.execute(
        "CREATE TRIGGER fail_save BEFORE INSERT ON exercises BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      ),
    );
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/exercise-create',
    );
    expect(find.byKey(const Key('exercise-name')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('exercise-name')), '保留草稿');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('exercise-primary-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('exercise-primary-save')));
    await settleExercise(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/exercise-create');
    expect(find.widgetWithText(TextField, '保留草稿'), findsOneWidget);
    expect(find.text(AppStrings.exerciseWriteFailed), findsOneWidget);
    await tester.runAsync(() => db.database.execute('DROP TRIGGER fail_save'));
    await tester.tap(find.text(AppStrings.retry));
    await settleExercise(tester);
    expect(
      (await tester.runAsync(() => SqliteExerciseRepository(db).search()))!
          .single
          .name,
      '保留草稿',
    );
    expect(router.state.uri.path, '/exercises');
  });

  testWidgets(
      'picker supports selection cancellation exclusions and continuous add from separate callers',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await tester.runAsync(() async {
      await SqliteExerciseRepository(db).save(draft('a', '卧推'));
      await SqliteExerciseRepository(db).save(draft('b', '划船'));
    });
    final router = await pumpFitnessApp(tester, database: db);
    final selected = <String>[];
    for (final route in ['/home', '/plan']) {
      router.go(route);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      ExercisePickerSheet.show(context, onSelected: (e) => selected.add(e.id));
      await settleExercise(tester);
      expect(find.text(AppStrings.pickExercise), findsOneWidget);
      await tester.tap(find.byKey(const Key('picker-exercise-a')));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.pickExercise), findsNothing);
    }
    final context = tester.element(find.byType(Scaffold).first);
    ExercisePickerSheet.show(
      context,
      onSelected: (e) => selected.add(e.id),
      allowMultiple: true,
      excludeIds: {'b'},
    );
    await settleExercise(tester);
    await tester.tap(find.byKey(const Key('picker-exercise-b')));
    expect(selected, ['a', 'a']);
    await tester.tap(find.byKey(const Key('picker-exercise-a')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.alreadyAdded), findsNWidgets(2));
    await tester.tap(find.byTooltip(AppStrings.close));
    await tester.pumpAndSettle();
    expect(selected, ['a', 'a', 'a']);
  });

  testWidgets(
      'UI search and two filters compose and clear to restore the catalog',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await tester.runAsync(() async {
      final repo = SqliteExerciseRepository(db);
      await repo.save(draft('a', '哑铃卧推'));
      await repo.save(draft('b', '杠铃卧推', equipment: ExerciseEquipment.barbell));
      await repo.save(draft('c', '哑铃划船', category: ExerciseCategory.back));
    });
    await pumpFitnessApp(tester, database: db, initialLocation: '/exercises');
    await tester.enterText(find.byKey(const Key('exercise-search')), '卧推');
    await settleExercise(tester);
    await tester.tap(find.byKey(const Key('filter-category-chest')));
    await settleExercise(tester);
    await tester.tap(find.byKey(const Key('filter-equipment-dumbbell')));
    await settleExercise(tester);
    expect(find.byKey(const Key('library-exercise-a')), findsOneWidget);
    expect(find.byKey(const Key('library-exercise-b')), findsNothing);
    expect(find.byKey(const Key('library-exercise-c')), findsNothing);
    await tester.enterText(find.byKey(const Key('exercise-search')), '不存在');
    await settleExercise(tester);
    expect(find.text(AppStrings.noMatchingExercises), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.clearSearch));
    await tester.tap(find.byKey(const Key('filter-category-')));
    await tester.tap(find.byKey(const Key('filter-equipment-')));
    await settleExercise(tester);
    expect(find.byKey(const Key('library-exercise-a')), findsOneWidget);
    expect(find.byKey(const Key('library-exercise-b')), findsOneWidget);
    expect(find.byKey(const Key('library-exercise-c')), findsOneWidget);
  });

  testWidgets(
      'library retries a SQLite read failure without fabricating results',
      (tester) async {
    final db = await tester.runAsync(openTestDatabase);
    addTearDown(db!.close);
    await tester.runAsync(() async {
      await SqliteExerciseRepository(db).save(draft('a', '卧推'));
      await db.database
          .execute('ALTER TABLE exercises RENAME TO exercises_recoverable');
    });
    await pumpFitnessApp(tester, database: db, initialLocation: '/exercises');
    expect(find.text(AppStrings.exerciseLoadFailed), findsOneWidget);
    await tester.runAsync(
      () => db.database
          .execute('ALTER TABLE exercises_recoverable RENAME TO exercises'),
    );
    await tester.tap(find.text(AppStrings.retry));
    await settleExercise(tester);
    expect(find.byKey(const Key('library-exercise-a')), findsOneWidget);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'catalog editor picker fit $width at text scale $scale and keyboard save works',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final db = await tester.runAsync(openTestDatabase);
        addTearDown(db!.close);
        await tester.runAsync(() async {
          await SqliteExerciseRepository(db).save(draft('bench-press', '哑铃卧推'));
          await SqliteExerciseRepository(db).save(
            draft(
              'b',
              '高位下拉',
              category: ExerciseCategory.back,
              equipment: ExerciseEquipment.cable,
            ),
          );
          await persistCompleted(SqliteWorkoutRepository(db));
        });
        final router = await pumpFitnessApp(
          tester,
          database: db,
          initialLocation: '/exercises',
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('recent-exercise-bench-press')),
          findsOneWidget,
        );
        await captureExercise(tester, 'library_${width.toInt()}_$scale');
        final context = tester.element(find.byType(Scaffold).first);
        ExercisePickerSheet.show(context, onSelected: (_) {});
        await settleExercise(tester);
        expect(tester.takeException(), isNull);
        await captureExercise(tester, 'picker_${width.toInt()}_$scale');
        await tester.tap(find.byTooltip(AppStrings.close));
        await tester.pumpAndSettle();
        router.go('/exercise-create');
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('exercise-name')),
          '核心稳定训练',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await captureExercise(tester, 'editor_${width.toInt()}_$scale');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.showKeyboard(find.byKey(const Key('exercise-name')));
        await tester.pumpAndSettle();
        final save = find.byKey(const Key('exercise-primary-save'));
        await tester.scrollUntilVisible(
          save,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.getRect(save).bottom, lessThan(640));
        expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await captureExercise(tester, 'keyboard_${width.toInt()}_$scale');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.ensureVisible(save);
        await tester.tap(save);
        await settleExercise(tester);
        expect(router.state.uri.path, '/exercises');
        expect(
          (await tester.runAsync(
            () => SqliteExerciseRepository(db).search(query: '核心稳定训练'),
          ))!,
          hasLength(1),
        );
      });
    }
  }
}

Future<void> captureExercise(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(const Key('app-render')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final directory =
        Directory('../.superpowers/sdd/2026-09-15-flutter-rewrite/task-5-ui');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> settleExercise(WidgetTester tester) async {
  await tester.pump();
  final context = tester.element(find.byType(Scaffold).first);
  final container = ProviderScope.containerOf(context, listen: false);
  for (var i = 0; i < 100; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 20));
    if (!(container.read(exerciseControllerProvider).valueOrNull?.isSaving ??
            false) &&
        !(container.read(exerciseControllerProvider).valueOrNull?.isLoading ??
            false) &&
        find.byType(LinearProgressIndicator).evaluate().isEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}
