import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/local_date.dart';
import '../domain/plan.dart';
import '../domain/plan_revision.dart';
import 'plan_editor_controller.dart';
import 'plan_providers.dart';

class PlanListItem {
  const PlanListItem(this.plan, this.revisions);
  final Plan plan;
  final List<PlanRevision> revisions;
  PlanRevision get revision => revisions.last;
  PlanRevision? revisionOn(LocalDate date) {
    for (final revision in revisions.reversed) {
      if (revision.effectiveFrom.compareTo(date) <= 0) return revision;
    }
    return null;
  }

  PlanRevision? revisionAfter(LocalDate date) {
    for (final revision in revisions) {
      if (revision.effectiveFrom.compareTo(date) > 0) return revision;
    }
    return null;
  }
}

class PlanListState {
  const PlanListState({
    this.items = const [],
    this.searchQuery = '',
    this.expandedPlanId,
    this.isSaving = false,
    this.failure,
  });
  final List<PlanListItem> items;
  final String searchQuery;
  final String? expandedPlanId;
  final bool isSaving;
  final AppFailure? failure;
  Set<String> get enabledPlanIds =>
      items.where((e) => e.plan.enabled).map((e) => e.plan.id).toSet();
  List<PlanListItem> get visibleItems => items
      .where(
        (e) => e.plan.name.toLowerCase().contains(searchQuery.toLowerCase()),
      )
      .toList();
}

class PlanController extends AsyncNotifier<PlanListState> {
  String searchQuery = ''; // Flutter: Riverpod state
  String? expandedPlanId; // Flutter: Riverpod state
  bool _disposed = false;
  @override
  Future<PlanListState> build() async {
    ref.onDispose(() => _disposed = true);
    return _read();
  }

  Future<PlanListState> _read() async {
    final repo = await ref.read(planRepositoryProvider.future);
    final plans = await repo.list();
    final items = <PlanListItem>[];
    for (final plan in plans) {
      items.add(PlanListItem(plan, await repo.revisions(plan.id)));
    }
    return PlanListState(
      items: items,
      searchQuery: searchQuery,
      expandedPlanId: expandedPlanId,
    );
  }

  Future<void> load() async {
    final next = await AsyncValue.guard(_read);
    if (!_disposed) state = next;
  }

  void _publish({bool isSaving = false, AppFailure? failure}) {
    state = AsyncData(
      PlanListState(
        items: state.valueOrNull?.items ?? [],
        searchQuery: searchQuery,
        expandedPlanId: expandedPlanId,
        isSaving: isSaving,
        failure: failure,
      ),
    );
  }

  void search(String query) {
    searchQuery = query;
    _publish();
  }

  void expand(String? id) {
    expandedPlanId = id;
    _publish();
  }

  Future<bool> _write(Future<void> Function() action) async {
    if (state.valueOrNull?.isSaving ?? false) return false;
    _publish(isSaving: true);
    try {
      await action();
      await load();
      return true;
    } catch (error) {
      if (!_disposed) {
        _publish(
          failure: error is AppFailure
              ? error
              : const AppFailure(FailureCode.persistence),
        );
      }
      return false;
    }
  }

  Future<bool> setEnabled(String id, bool value) => _write(
        () async => (await ref.read(planRepositoryProvider.future))
            .setEnabled(id, value),
      );
  Future<bool> duplicate(String id) => _write(() async {
        await (await ref.read(planRepositoryProvider.future)).duplicate(
          id,
          newId: newPlanId(),
          startsOn: ref.read(clockProvider).today(),
        );
      });
  Future<bool> delete(String id) => _write(
        () async => (await ref.read(planRepositoryProvider.future)).delete(id),
      );
}
