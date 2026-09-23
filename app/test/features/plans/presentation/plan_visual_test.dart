import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/core/data/app_database.dart';
import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/exercises/data/sqlite_exercise_repository.dart';
import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/plans/application/plan_editor_controller.dart';
import 'package:fitness_counter/features/plans/application/plan_providers.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/app_theme.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/pump_app.dart';
import '../../../support/test_database.dart';
import '../application/plan_editor_test.dart' show PlanTestClock;
import 'plan_flow_test.dart' show settlePlan;

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/msyh.ttc');
    if (font.existsSync()) {
      final loader = FontLoader(AppTheme.fontFamily)
        ..addFont(
          font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets(
      'overview renders the active cycle when a shorter revision starts tomorrow',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final clock = PlanTestClock();
    final repository = SqlitePlanRepository(db);
    await tester.runAsync(() async {
      await repository.save(
        catalogPlan(),
        catalogRevision(
          id: 'active-revision',
          effectiveFrom: clock.today().addDays(-4),
          cycleDays: 6,
        ),
      );
      await repository.save(
        catalogPlan(),
        catalogRevision(
          id: 'upcoming-revision',
          effectiveFrom: clock.today().addDays(1),
          cycleDays: 3,
        ),
      );
    });
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/plan',
      overrides: [
        themeDefinitionsProvider.overrideWith(
          (ref) async => [breathRhythmDefinition],
        ),
        clockProvider.overrideWithValue(clock),
      ],
    );
    await settlePlan(tester);

    expect(find.text(AppStrings.cycleSummary(6, 5)), findsOneWidget);
    expect(find.text(AppStrings.viewDays(6)), findsOneWidget);
    expect(find.text(AppStrings.cycleSummary(3, 5)), findsNothing);
    expect(find.byKey(const Key('plan-upcoming-revision')), findsNothing);

    await tester.tap(find.text(AppStrings.viewDays(6)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-current-day-dot-5')), findsOneWidget);
    expect(find.byKey(const Key('plan-day-6')), findsOneWidget);
    await capturePlan(tester, 'list_upcoming_390_1.0');
  });

  testWidgets('plan cards and mode summaries preserve the reference hierarchy',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final id = (await tester.runAsync(() => makePlan(db)))!;
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/plan',
    );
    await settlePlan(tester);

    final theme = AppTheme.of(tester.element(find.byType(Scaffold).first));
    final searchSurface = tester.getRect(
      find.byKey(const Key('plan-search-surface')),
    );
    final search = find.byKey(const Key('plan-search'));
    expect(searchSurface.height, theme.spacing.s40);
    expect(tester.getSize(search).height, greaterThanOrEqualTo(48));
    final editableText = find.descendant(
      of: search,
      matching: find.byType(EditableText),
    );
    await tester.tapAt(Offset(searchSurface.center.dx, searchSurface.top + 1));
    await tester.pump();
    expect(
      tester.widget<EditableText>(editableText).focusNode.hasFocus,
      isTrue,
    );
    tester.widget<EditableText>(editableText).focusNode.unfocus();
    await tester.pump();
    await tester.tapAt(
      Offset(searchSurface.center.dx, searchSurface.bottom - 1),
    );
    await tester.pump();
    expect(
      tester.widget<EditableText>(editableText).focusNode.hasFocus,
      isTrue,
    );

    final badge = tester.widget<Container>(
      find.byKey(ValueKey('plan-status-badge-$id')),
    );
    expect(
      (badge.decoration! as BoxDecoration).color,
      theme.colors.primarySurface,
    );
    expect(find.text(AppStrings.infiniteMode), findsNothing);
    expect(find.textContaining('2026-'), findsNothing);
    expect(find.textContaining(AppStrings.planPriority(0)), findsNothing);
    expect(find.byTooltip(AppStrings.moreActions), findsNothing);

    final editButton = tester.widget<IconButton>(
      find.byKey(ValueKey('plan-edit-$id')),
    );
    expect(editButton.constraints!.minWidth, theme.minTapTarget);
    expect(editButton.constraints!.minHeight, theme.minTapTarget);
    final editVisual = tester.getSize(
      find.byKey(ValueKey('plan-edit-visual-$id')),
    );
    expect(editVisual, Size.square(theme.spacing.s28));
    expect(
      find.descendant(
        of: find.byKey(ValueKey('plan-edit-visual-$id')),
        matching: find.byIcon(Icons.edit),
      ),
      findsOneWidget,
    );
    final summaryCenter =
        tester.getCenter(find.byKey(ValueKey('plan-summary-$id'))).dy;
    final editCenter =
        tester.getCenter(find.byKey(ValueKey('plan-edit-$id'))).dy;
    final toggleCenter =
        tester.getCenter(find.byKey(ValueKey('plan-enabled-$id'))).dy;
    expect(editCenter, summaryCenter);
    expect(toggleCenter, summaryCenter);

    final planCard = tester.widget<Container>(find.byKey(ValueKey('plan-$id')));
    final cardOutline = planCard.foregroundDecoration! as BoxDecoration;
    expect(cardOutline.border, isNotNull);
    expect(
      cardOutline.borderRadius,
      BorderRadius.circular(theme.appCard.radius),
    );

    final expansionHeader = tester.widget<Material>(
      find.byKey(ValueKey('plan-expansion-header-$id')),
    );
    expect(expansionHeader.color, theme.colors.inputSurface);
    expect(
      tester.getSize(find.byKey(ValueKey('plan-expansion-header-$id'))).height,
      theme.spacing.s40 + theme.borders.thin,
    );
    final overviewChevron = find.descendant(
      of: find.byKey(ValueKey('plan-expansion-header-$id')),
      matching: find.byKey(const Key('plan-expansion-chevron')),
    );
    expect(overviewChevron, findsOneWidget);
    expect(tester.getSize(overviewChevron), Size.square(theme.typography.lg));
    final cardTopBeforeToggle = tester.getTopLeft(
      find.byKey(ValueKey('plan-$id')),
    );
    await tester.tap(find.byKey(ValueKey('plan-enabled-$id')));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(ValueKey('plan-$id'))),
      cardTopBeforeToggle,
    );
    await tester.tap(find.byKey(ValueKey('plan-enabled-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('plan-expansion-header-$id')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-current-day-dot')), findsOneWidget);
    final divider = tester.widget<DecoratedBox>(
      find.byKey(const Key('plan-day-divider-2')),
    );
    expect((divider.decoration as BoxDecoration).border, isNotNull);
    await tester.tap(find.byKey(const Key('plan-day-1')));
    await tester.pumpAndSettle();
    final firstDay = find.byKey(const Key('plan-day-1'));
    final dayTitleLeft = tester.getTopLeft(find.text('D1 · 推力训练')).dx;
    final daySummaryLeft = tester.getTopLeft(find.text('1 个动作 · 4 组')).dx;
    final exerciseTitleLeft = tester.getTopLeft(find.text('哑铃卧推')).dx;
    expect(daySummaryLeft, dayTitleLeft);
    expect(exerciseTitleLeft, dayTitleLeft);
    expect(
      find.descendant(
        of: firstDay,
        matching: find.text('4组 · 32kg · 8次'),
      ),
      findsOneWidget,
    );
    final exerciseRow = tester.widget<Container>(
      find
          .descendant(
            of: firstDay,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>)
                      .value
                      .startsWith('plan-exercise-'),
            ),
          )
          .first,
    );
    expect((exerciseRow.decoration! as BoxDecoration).border, isNotNull);

    router.go('/create-plan');
    await settlePlan(tester);
    final basicCard = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('plan-basic-card')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      basicCard.padding,
      EdgeInsets.fromLTRB(
        theme.spacing.s16,
        theme.spacing.s16,
        theme.spacing.s16,
        theme.spacing.s8,
      ),
    );
    final executionCard = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('plan-execution-card')),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(executionCard.padding, EdgeInsets.all(theme.spacing.s12));
    final startDateField = tester.widget<Container>(
      find.byKey(const Key('plan-effective-date')),
    );
    expect(
      (startDateField.decoration! as BoxDecoration).border,
      isNotNull,
    );
    await tester.ensureVisible(find.byKey(const Key('plan-mode-cycles')));
    await tester.tap(find.byKey(const Key('plan-mode-cycles')));
    await tester.pumpAndSettle();
    final cyclesSummary = tester.widget<Container>(
      find.byKey(const Key('plan-cycles-summary')),
    );
    expect(
      (cyclesSummary.decoration! as BoxDecoration).color,
      theme.colors.inputSurface,
    );
    await tester.ensureVisible(find.byKey(const Key('plan-mode-dateRange')));
    await tester.tap(find.byKey(const Key('plan-mode-dateRange')));
    await tester.pumpAndSettle();
    final rangeSummary = tester.widget<Container>(
      find.byKey(const Key('plan-range-summary')),
    );
    expect(
      (rangeSummary.decoration! as BoxDecoration).color,
      theme.colors.inputSurface,
    );
    final endDateField = tester.widget<Container>(
      find.byKey(const Key('plan-end-date')),
    );
    expect(
      (endDateField.decoration! as BoxDecoration).border,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('365 day jump and name search select the actual editable day',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final id = (await tester.runAsync(() => makePlan(db, length: 365)))!;
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/plan-edit/$id',
    );
    await settlePlan(tester);
    await tester.tap(find.byKey(const Key('day-jump')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('day-search')), '365');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-result-365')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'D365'), findsOneWidget);
    expect(find.byKey(const Key('day-tab-365')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('day-name')), '收官恢复');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await capturePlan(tester, 'day_365_360_1.0');
    await tester.tap(find.byKey(const Key('day-tab-364')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-jump')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('day-search')), '收官');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-result-365')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '收官恢复'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'picker returns to the same day draft and batch rows save individually',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    final id = (await tester.runAsync(() => makePlan(db)))!;
    await tester.runAsync(
      () => SqliteExerciseRepository(db)
          .save(catalogExercise(id: 'new-exercise', name: '高位下拉')),
    );
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/plan-edit/$id',
    );
    await settlePlan(tester);
    await tester.enterText(find.byKey(const Key('day-name')), '背部力量');
    await tester.tap(find.byKey(const Key('day-add-exercise')));
    await settlePlan(tester);
    await tester.tap(find.byKey(const Key('picker-exercise-new-exercise')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '背部力量'), findsOneWidget);
    await tester.tap(find.text('高位下拉'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-batch-sets')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('set-count')), '5');
    await tester.enterText(find.byKey(const Key('set-weight')), '32');
    await tester.enterText(find.byKey(const Key('set-reps')), '8');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await capturePlan(tester, 'batch_sets_390_1.0');
    await tester.tap(find.byKey(const Key('set-save')));
    await tester.pumpAndSettle();
    await capturePlan(tester, 'set_editor_390_1.0');
    await tester.tap(find.text(AppStrings.done).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-save')));
    await settlePlan(tester);
    final revision =
        (await tester.runAsync(() => SqlitePlanRepository(db).revisions(id)))!
            .last;
    expect(revision.days.first.name, '背部力量');
    expect(revision.days.first.exercises.last.sets, hasLength(5));
    expect(
      revision.days.first.exercises.last.sets.map((s) => s.id).toSet(),
      hasLength(5),
    );
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'plan pages fit $width scale $scale and keyboard leaves save reachable',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final db = (await tester.runAsync(openTestDatabase))!;
        addTearDown(db.close);
        final id = (await tester.runAsync(() => makePlan(db)))!;
        final router = await pumpFitnessApp(
          tester,
          database: db,
          initialLocation: '/plan',
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(Scaffold).first),
        );
        container.read(planControllerProvider.notifier).expand(id);
        await tester.pumpAndSettle();
        await capturePlan(tester, 'list_${width.toInt()}_$scale');
        expect(tester.takeException(), isNull);
        router.go('/edit-plan/$id');
        await settlePlan(tester);
        await capturePlan(tester, 'edit_${width.toInt()}_$scale');
        router.go('/create-plan');
        await settlePlan(tester);
        await tester.enterText(
          find.byKey(const Key('plan-name')),
          '力量与恢复交替训练计划',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await capturePlan(tester, 'create_${width.toInt()}_$scale');
        await tester.ensureVisible(find.byKey(const Key('plan-mode-cycles')));
        await tester.tap(find.byKey(const Key('plan-mode-cycles')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('plan-loop-count')));
        await tester.enterText(find.byKey(const Key('plan-loop-count')), '2');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await capturePlan(tester, 'cycles_${width.toInt()}_$scale');
        await tester
            .ensureVisible(find.byKey(const Key('plan-mode-dateRange')));
        await tester.tap(find.byKey(const Key('plan-mode-dateRange')));
        await tester.pumpAndSettle();
        await capturePlan(tester, 'range_${width.toInt()}_$scale');
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final save = find.byKey(const Key('plan-save'));
        expect(tester.getRect(save).bottom, lessThan(544));
        expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        await capturePlan(tester, 'keyboard_${width.toInt()}_$scale');
        await tester.tap(save);
        await settlePlan(tester);
        expect(router.state.uri.path, '/plan');
        tester.view.resetViewInsets();
        router.go('/plan-edit/$id');
        await settlePlan(tester);
        await capturePlan(tester, 'day_${width.toInt()}_$scale');
        await tester.tap(find.byKey(const Key('day-tab-2')));
        await tester.pumpAndSettle();
        await capturePlan(tester, 'rest_${width.toInt()}_$scale');
        expect(find.byKey(const Key('day-add-exercise')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<String> makePlan(AppDatabase db, {int length = 6}) async {
  final editor =
      PlanEditorController(SqlitePlanRepository(db), PlanTestClock());
  await editor.open(null);
  editor.updateBasics(name: '推拉基础计划', cycleLength: length);
  editor.addExercise(0, catalogExercise());
  editor.batchAddSets(
    0,
    editor.state.days.first.exercises.single.id,
    count: 4,
    weight: 32,
    unit: WeightUnit.kg,
    reps: 8,
  );
  editor.renameDay(0, '推力训练');
  editor.setDayRest(1, true);
  await editor.save(effectiveFrom: LocalDate.fromDateTime(DateTime.now()));
  final id = editor.state.planId!;
  editor.dispose();
  return id;
}

Future<void> capturePlan(WidgetTester tester, String name) async {
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(const Key('app-render')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final directory =
        Directory('../.superpowers/sdd/2026-09-15-flutter-rewrite/task-6-ui');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data.buffer.asUint8List());
    image.dispose();
  });
}
