// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:fitness_counter/app/app.dart';
import 'package:fitness_counter/app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(child: FitnessCounterApp(router: createRouter())),
    );
    await tester.pump();
    expect(find.byType(FitnessCounterApp), findsOneWidget);
  });
}
