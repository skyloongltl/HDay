import 'package:fitness_counter/core/domain/local_date.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:fitness_counter/l10n/app_strings.dart';
import 'package:fitness_counter/theme/app_theme.dart';
import 'package:fitness_counter/theme/plan_skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/pump_app.dart';
import '../../../support/test_database.dart';

void main() {
  testWidgets('canceling nested base edit discards the shared draft changes',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(
      () => SqlitePlanRepository(db).save(
        catalogPlan(),
        catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
      ),
    );
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/plan-edit/p1',
    );
    router.push('/edit-plan/p1');
    await settlePlan(tester);
    await tester.enterText(find.byKey(const Key('plan-name')), '不应保留的修改');
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-action')));
    await settlePlan(tester);
    expect(router.state.uri.path, '/plan-edit/p1');
    expect(find.text('不应保留的修改'), findsNothing);
    expect(find.text('三日训练计划'), findsOneWidget);
  });
  testWidgets('changed cycle length requires an explicit date before saving',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(
      () => SqlitePlanRepository(db).save(
        catalogPlan(),
        catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
      ),
    );
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/edit-plan/p1',
    );
    await tester.enterText(find.byKey(const Key('plan-cycle-length')), '4');
    await tester.tap(find.byKey(const Key('plan-save')));
    await settlePlan(tester);
    expect(router.state.uri.path, '/edit-plan/p1');
    expect(find.text(AppStrings.chooseEffectiveDate), findsOneWidget);
    expect(
      (await tester.runAsync(() => SqlitePlanRepository(db).revisions('p1')))!
          .last
          .cycleDays,
      3,
    );
  });
  testWidgets('failed delete retries deletion rather than saving the plan',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(() async {
      await SqlitePlanRepository(db).save(
        catalogPlan(),
        catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
      );
      await db.database.execute(
        "CREATE TRIGGER fail_delete BEFORE DELETE ON plans BEGIN SELECT RAISE(ABORT, 'disk'); END",
      );
    });
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/edit-plan/p1',
    );
    await tester.tap(find.text(AppStrings.deletePlan));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-action')));
    await settlePlan(tester);
    expect(router.state.uri.path, '/edit-plan/p1');
    await tester
        .runAsync(() => db.database.execute('DROP TRIGGER fail_delete'));
    await tester.tap(find.text(AppStrings.retry));
    await settlePlan(tester);
    expect(
      await tester.runAsync(() => SqlitePlanRepository(db).find('p1')),
      isNull,
    );
    expect(router.state.uri.path, '/plan');
  });
  // Catches the missing plan-create navigation and disconnected save action.
  testWidgets('empty plan library opens a real create form', (tester) async {
    final router = await pumpFitnessApp(tester, initialLocation: '/plan');
    await tester.tap(find.byTooltip(AppStrings.createPlan));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/create-plan');
    expect(find.byKey(const Key('plan-name')), findsOneWidget);
  });
  testWidgets('whole-plan duplicate keeps dirty draft and copies saved version',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(
      () => SqlitePlanRepository(db).save(
        catalogPlan(),
        catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
      ),
    );
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/plan',
    );
    await settlePlan(tester);

    await tester.tap(find.byKey(const ValueKey('plan-edit-p1')));
    await settlePlan(tester);
    expect(router.state.uri.path, '/plan-edit/p1');
    await tester.enterText(
      find.byKey(const Key('day-name')),
      '未保存的周期日草稿',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(AppStrings.moreActions).first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.duplicatePlan), findsOneWidget);
    expect(find.text(AppStrings.editPlan), findsOneWidget);
    await tester.tap(find.text(AppStrings.duplicatePlan));
    await settlePlan(tester);
    expect(router.state.uri.path, '/plan-edit/p1');
    expect(
      find.widgetWithText(TextField, '未保存的周期日草稿'),
      findsOneWidget,
    );
    expect(find.text(AppStrings.duplicateSavedPlanSuccess), findsOneWidget);
    final plans =
        (await tester.runAsync(() => SqlitePlanRepository(db).list()))!;
    expect(plans, hasLength(2));
    final copy = plans.singleWhere((plan) => plan.id != 'p1');
    final copiedRevisions = (await tester.runAsync(
      () => SqlitePlanRepository(db).revisions(copy.id),
    ))!;
    expect(copiedRevisions.single.days.first.name, 'D1');

    await tester.tap(find.byTooltip(AppStrings.moreActions).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.editPlan));
    await settlePlan(tester);
    expect(router.state.uri.path, '/edit-plan/p1');
    expect(find.text(AppStrings.deletePlan), findsOneWidget);
  });
  testWidgets('failed whole-plan duplicate keeps dirty draft on editor',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(() async {
      await SqlitePlanRepository(db).save(
        catalogPlan(),
        catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
      );
      await db.database.execute(
        "CREATE TRIGGER fail_duplicate BEFORE INSERT ON plans BEGIN SELECT RAISE(ABORT, 'disk'); END",
      );
    });
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/plan-edit/p1',
    );
    await settlePlan(tester);
    await tester.enterText(
      find.byKey(const Key('day-name')),
      '失败后仍保留的草稿',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(AppStrings.moreActions).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.duplicatePlan));
    await settlePlan(tester);

    expect(router.state.uri.path, '/plan-edit/p1');
    expect(
      find.widgetWithText(TextField, '失败后仍保留的草稿'),
      findsOneWidget,
    );
    expect(find.text(AppStrings.exerciseWriteFailed), findsOneWidget);
    expect(
      (await tester.runAsync(() => SqlitePlanRepository(db).list()))!.length,
      1,
    );
  });
  testWidgets('save failure keeps name draft and retry commits the plan',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(
      () => db.database.execute(
        "CREATE TRIGGER fail_plan BEFORE INSERT ON plans BEGIN SELECT RAISE(ABORT, 'disk'); END",
      ),
    );
    final router = await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/create-plan',
    );
    await settlePlan(tester);
    expect(find.byKey(const Key('plan-name')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('plan-name')), '保留计划草稿');
    await tester.tap(find.byKey(const Key('plan-save')));
    await settlePlan(tester);
    expect(router.state.uri.path, '/create-plan');
    expect(find.widgetWithText(TextField, '保留计划草稿'), findsOneWidget);
    expect(find.text(AppStrings.exerciseWriteFailed), findsOneWidget);
    await tester.runAsync(() => db.database.execute('DROP TRIGGER fail_plan'));
    await tester.tap(find.text(AppStrings.retry));
    await settlePlan(tester);
    expect(router.state.uri.path, '/plan');
    expect(
      (await tester.runAsync(() => SqlitePlanRepository(db).list()))!
          .single
          .name,
      '保留计划草稿',
    );
  });
  testWidgets(
      'rest conversion confirms destruction and cancellation keeps content',
      (tester) async {
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(
      () => SqlitePlanRepository(db).save(
        catalogPlan(),
        catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
      ),
    );
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/plan-edit/p1',
    );
    await settlePlan(tester);
    expect(find.byKey(const Key('day-rest')), findsOneWidget);
    await tester.tap(find.byKey(const Key('day-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-rest')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    expect(find.text('哑铃卧推'), findsOneWidget);
    await tester.tap(find.byKey(const Key('day-rest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-action')));
    await tester.pumpAndSettle();
    expect(find.text('哑铃卧推'), findsNothing);
    expect(find.byKey(const Key('day-add-exercise')), findsNothing);
    await tester.tap(find.byKey(const Key('plan-save')));
    await settlePlan(tester);
    expect(
      (await tester.runAsync(() => SqlitePlanRepository(db).revisions('p1')))!
          .last
          .days
          .first
          .isRest,
      isTrue,
    );
  });

  testWidgets('plan day editor uses compact themed controls and summaries',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = (await tester.runAsync(openTestDatabase))!;
    addTearDown(db.close);
    await tester.runAsync(
      () => SqlitePlanRepository(db).save(
        catalogPlan(),
        catalogRevision(effectiveFrom: LocalDate(2026, 9, 1)),
      ),
    );
    await pumpFitnessApp(
      tester,
      database: db,
      initialLocation: '/plan-edit/p1',
    );
    await settlePlan(tester);

    final theme = AppTheme.of(tester.element(find.byType(Scaffold).first));
    expect(find.text('1组 · 20kg'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('pe1'))).height,
      lessThan(64),
    );

    expect(
      tester.getSize(find.byKey(const Key('day-add-exercise'))).height,
      theme.minTapTarget,
    );
    expect(
      tester.getSize(find.byKey(const Key('day-add-exercise-visual'))).height,
      PlanSkin.compactActionHeight,
    );
    final addButtonVisual = tester.widget<Container>(
      find.byKey(const Key('day-add-exercise-visual')),
    );
    expect(
      (addButtonVisual.decoration! as BoxDecoration).color,
      theme.colors.primaryAction,
    );

    final exerciseMenu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const ValueKey('exercise-menu-pe1')),
    );
    expect(exerciseMenu.color, theme.colors.surface);
    expect(exerciseMenu.surfaceTintColor, Colors.transparent);

    await tester.tap(find.byKey(const ValueKey('day-exercise-pe1')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('plan-set-s1'))).height,
      lessThan(64),
    );
    final setMenu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const ValueKey('set-menu-s1')),
    );
    expect(setMenu.color, theme.colors.surface);
    expect(setMenu.surfaceTintColor, Colors.transparent);
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    final dayMenu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('day-menu')),
    );
    expect(dayMenu.color, theme.colors.surface);
    expect(dayMenu.surfaceTintColor, Colors.transparent);
    await tester.tap(find.byKey(const Key('day-menu')));
    await tester.pumpAndSettle();
    final firstMenuItem = tester.widget<PopupMenuItem<String>>(
      find.widgetWithText(PopupMenuItem<String>, AppStrings.copyDay),
    );
    expect(firstMenuItem.height, PlanSkin.menuItemHeight);
    await tester.tap(find.text(AppStrings.copyDay));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('day-jump')));
    await tester.pumpAndSettle();
    final pickerSurface = tester.widget<Material>(
      find.byKey(const Key('day-picker-surface')),
    );
    expect(pickerSurface.color, theme.colors.page);
    expect(find.byKey(const Key('day-result-divider')), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('day-result-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('day-rest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('day-kind-inline')), findsOneWidget);
    final headingCenter =
        tester.getCenter(find.byKey(const Key('day-heading')));
    final restCenter =
        tester.getCenter(find.byKey(const Key('day-kind-inline')));
    expect((headingCenter.dy - restCenter.dy).abs(), lessThan(2));
  });
}

Future<void> settlePlan(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}
