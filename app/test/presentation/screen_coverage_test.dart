import 'package:flutter_test/flutter_test.dart';
import '../support/history_test_support.dart';
import '../support/task13_fixtures.dart';

void main() {
  setUpAll(loadHistoryFonts);
  // A registered URI alone is insufficient: every case opens the production
  // router and waits for populated/empty content from the typed repositories.
  for (final screen in [task13EmptyHome, ...task13Screens]) {
    testWidgets(
        '${screen.route} ${screen.name} renders through a real route entry',
        (tester) async {
      await pumpTask13(tester, screen);
      await assertTask13Targets(tester, screen, 390);
    });
  }
}
