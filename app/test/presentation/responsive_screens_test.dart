import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/history_test_support.dart';
import '../support/task13_fixtures.dart';

void main() {
  setUpAll(loadHistoryFonts);
  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final screen in [...task13Screens, ...task13ExtraScreens]) {
        testWidgets(
            '${screen.name} renders without overflow at $width x $scale with 48px targets',
            (tester) async {
          await pumpTask13(tester, screen, width: width, scale: scale);
          await assertTask13Targets(tester, screen, width);
          if (screen.name == 'pre_workout') {
            expect(
              tester.widget<AppBar>(find.byType(AppBar)).centerTitle,
              isTrue,
            );
          }
        });
      }
    }
  }
  for (final (name, field, save) in [
    ('plan_create', 'plan-name', 'plan-primary-save'),
    ('exercise_create', 'exercise-name', 'exercise-primary-save'),
  ]) {
    testWidgets('$name save stays reachable above keyboard at 360 x 1.3',
        (tester) async {
      final screen = task13Screens.firstWhere((screen) => screen.name == name);
      await pumpTask13(tester, screen, width: 360, scale: 1.3);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byKey(ValueKey(field)), '中文训练名称');
      await tester.pump();
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      final action = find.byKey(ValueKey(save));
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      final bounds = tester.getRect(action);
      expect(bounds.shortestSide, greaterThanOrEqualTo(48));
      expect(bounds.bottom, lessThanOrEqualTo(544));
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
