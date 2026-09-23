import 'package:fitness_counter/app/providers.dart';
import 'package:fitness_counter/features/plans/application/plan_providers.dart';
import 'package:fitness_counter/features/plans/data/sqlite_plan_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/catalog_fixtures.dart';
import '../../../support/test_database.dart';
import 'plan_editor_test.dart';

void main() {
  // Catches disconnected actions, optimistic false-success and stale query rows.
  test('list search toggle duplicate delete use committed SQLite identities',
      () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    final repo = SqlitePlanRepository(db);
    await repo.save(
      catalogPlan(),
      catalogRevision(effectiveFrom: PlanTestClock().today()),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => db),
        clockProvider.overrideWithValue(PlanTestClock()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(planControllerProvider.future);
    final controller = container.read(planControllerProvider.notifier);
    await controller.setEnabled('p1', false);
    expect((await repo.find('p1'))!.enabled, isFalse);
    expect(
      container.read(planControllerProvider).requireValue.enabledPlanIds,
      isEmpty,
    );
    await controller.duplicate('p1');
    final copy = (await repo.list()).last;
    expect(copy.id, isNot('p1'));
    expect(
      (await repo.revisions(copy.id))
          .single
          .days
          .first
          .exercises
          .first
          .sets
          .first
          .id,
      isNot('s1'),
    );
    controller.search('副本');
    expect(
      container
          .read(planControllerProvider)
          .requireValue
          .visibleItems
          .single
          .plan
          .id,
      copy.id,
    );
    await db.database.execute(
      "CREATE TRIGGER fail_delete BEFORE DELETE ON plans BEGIN SELECT RAISE(ABORT, 'disk'); END",
    );
    expect(await controller.delete(copy.id), isFalse);
    expect(
      container.read(planControllerProvider).requireValue.visibleItems,
      hasLength(1),
    );
    await db.database.execute('DROP TRIGGER fail_delete');
    expect(await controller.delete(copy.id), isTrue);
    expect(
      container.read(planControllerProvider).requireValue.visibleItems,
      isEmpty,
    );
    expect(await repo.find('p1'), isNotNull);
  });
}
