import '../../../core/domain/local_date.dart';
import 'plan.dart';
import 'plan_revision.dart';

abstract interface class PlanRepository {
  Future<List<Plan>> list();

  Future<Plan?> find(String id);

  Future<List<PlanRevision>> revisions(String id);

  Future<void> save(Plan plan, PlanRevision revision);

  Future<void> setEnabled(String id, bool enabled);

  Future<void> delete(String id);

  Future<Plan> duplicate(
    String id, {
    required String newId,
    required LocalDate startsOn,
  });
}
