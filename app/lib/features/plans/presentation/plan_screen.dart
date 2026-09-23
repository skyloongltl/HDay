import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/plan_skin.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/app_scaffold.dart';
import '../application/plan_controller.dart';
import '../application/plan_providers.dart';
import '../domain/plan_schedule.dart';
import 'plan_day_expansion_tile.dart';
import 'plan_form_widgets.dart';

// PAGE: PlanScreen
// ROUTE: /plan (tab)
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, ExpansionTile, Switch, BottomNav
// STATE: expandedPlanId(String?), searchQuery(String), enabledPlanIds(Set<String> derived from SQLite)
// ANIMATIONS: explicit expansion 200ms easeOut; platform switch
// NAVIGATION: add -> create-plan; edit -> plan-edit/:id; menu -> edit-plan/:id
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});
  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  final searchQuery = TextEditingController(); // Flutter: TextEditingController
  Future<bool> Function()? _retry; // Flutter: setState
  @override
  void dispose() {
    searchQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppScaffold(
      selectedTabIndex: 1,
      onDestinationSelected: (index) => context.go(AppRoutes.primary[index]),
      appBar: FitnessAppBar(
        title: AppStrings.plansTitle,
        actions: [
          IconButton(
            tooltip: AppStrings.createPlan,
            onPressed: () => context.push(AppRoutes.createPlan),
            icon: CircleAvatar(
              backgroundColor: theme.primaryAction,
              radius: theme.spacing.s16,
              child: Icon(
                Icons.add,
                color: theme.colors.onHero,
                size: theme.typography.xl,
              ),
            ),
          ),
        ],
      ),
      body: ref.watch(planControllerProvider).when(
            loading: () => const PlanStatus(),
            error: (_, __) => PlanStatus(
              message: AppStrings.planLoadFailed,
              onRetry: () => ref.read(planControllerProvider.notifier).load(),
            ),
            data: _list,
          ),
    );
  }

  Widget _list(PlanListState state) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    final controller = ref.read(planControllerProvider.notifier);
    // Flutter: ListView, mainAxis: start, crossAxis: stretch
    return ListView(
      key: const Key('plan-screen'),
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.s16,
        vertical: theme.spacing.s12,
      ),
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: theme.spacing.s14),
          child: SizedBox(
            height: theme.minTapTarget,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  key: const Key('plan-search-surface'),
                  decoration: skin.panel(compact: true),
                  child: SizedBox(
                    width: double.infinity,
                    height: theme.spacing.s40,
                  ),
                ),
                Positioned.fill(
                  child: TextField(
                    key: const Key('plan-search'),
                    controller: searchQuery,
                    onChanged: controller.search,
                    textAlignVertical: TextAlignVertical.center,
                    style: skin.title,
                    decoration: skin
                        .input(
                          AppStrings.searchPlan,
                          prefix: Padding(
                            padding: EdgeInsets.only(
                              left: theme.spacing.s14,
                              right: theme.spacing.s8,
                            ),
                            child: Icon(
                              Icons.search,
                              size: theme.typography.md,
                              color: theme.colors.textSubtle,
                            ),
                          ),
                        )
                        .copyWith(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.only(
                            right: theme.spacing.s14,
                          ),
                          prefixIconConstraints: BoxConstraints.tightFor(
                            height: theme.minTapTarget,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.failure != null)
          PlanFailureTile(
            message: AppStrings.exerciseWriteFailed,
            onRetry: () {
              if (_retry != null) _retry!();
            },
          ),
        if (state.visibleItems.isEmpty)
          Padding(
            padding: EdgeInsets.all(theme.spacing.s32),
            // Flutter: Column, mainAxis: start, crossAxis: center
            child: Column(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: theme.dimensions.emptyIconSize,
                  color: theme.colors.textSubtle,
                ),
                // Spacer: spacing.14 -> SizedBox(height: spacing.14)
                SizedBox(height: theme.spacing.s14),
                Text(
                  state.searchQuery.isEmpty
                      ? AppStrings.noPlans
                      : AppStrings.noMatchingPlans,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: theme.spacing.s12),
                  child: Text(
                    state.searchQuery.isEmpty
                        ? AppStrings.noPlansHint
                        : AppStrings.tryOtherQuery,
                    textAlign: TextAlign.center,
                    style: skin.caption,
                  ),
                ),
                if (state.searchQuery.isEmpty)
                  ElevatedButton(
                    onPressed: () => context.push(AppRoutes.createPlan),
                    child: const Text(AppStrings.createPlan),
                  ),
              ],
            ),
          ),
        for (final item in state.visibleItems) _planCard(item, state),
      ],
    );
  }

  Widget _planCard(PlanListItem item, PlanListState state) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    final controller = ref.read(planControllerProvider.notifier);
    final plan = item.plan;
    final today = ref.read(clockProvider).today();
    final scheduled = PlanSchedule.dayFor(
      plan,
      item.revisions,
      today,
    );
    final activeRevision = item.revisionOn(today);
    final upcomingRevision = item.revisionAfter(today);
    final revision = activeRevision ?? upcomingRevision ?? item.revision;
    final currentDay =
        scheduled?.revision.id == revision.id ? scheduled?.day.dayNumber : null;
    return Container(
      key: ValueKey('plan-${plan.id}'),
      margin: EdgeInsets.only(bottom: theme.spacing.s10),
      decoration: skin.panel(),
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: theme.appCard.outline,
          width: theme.borders.thin,
        ),
        borderRadius: BorderRadius.circular(theme.appCard.radius),
      ),
      clipBehavior: Clip.antiAlias,
      // Flutter: Column, mainAxis: start, crossAxis: stretch
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacing.s14,
              theme.spacing.s8,
              theme.spacing.s6,
              theme.spacing.s8,
            ),
            // Flutter: Row, mainAxis: start, crossAxis: start
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  // Flutter: Column, mainAxis: start, crossAxis: start
                  child: Column(
                    key: ValueKey('plan-summary-${plan.id}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Flutter: Wrap, mainAxis: start, crossAxis: center
                      Wrap(
                        spacing: theme.spacing.s8,
                        runSpacing: theme.spacing.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            plan.name,
                            style: skin.title.copyWith(
                              fontWeight: theme.typography.bold,
                            ),
                          ),
                          if (scheduled != null)
                            Container(
                              key: ValueKey('plan-status-badge-${plan.id}'),
                              padding: EdgeInsets.symmetric(
                                horizontal: theme.spacing.s8,
                                vertical: theme.spacing.s2,
                              ),
                              decoration: skin.statusBadge,
                              child: Text(
                                AppStrings.inProgress,
                                style: skin.caption.copyWith(
                                  color: theme.primaryAction,
                                  fontWeight: theme.typography.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        AppStrings.cycleSummary(
                          revision.cycleDays,
                          currentDay,
                        ),
                        style: skin.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('plan-edit-${plan.id}'),
                  tooltip: AppStrings.cycleConfig,
                  onPressed: () => context.push(AppRoutes.planEdit(plan.id)),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(
                    width: theme.minTapTarget,
                    height: theme.minTapTarget,
                  ),
                  icon: Container(
                    key: ValueKey('plan-edit-visual-${plan.id}'),
                    width: theme.spacing.s28,
                    height: theme.spacing.s28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colors.iconSurface,
                      borderRadius: BorderRadius.circular(theme.radii.sm),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: theme.typography.sm,
                      color: theme.colors.textMuted,
                    ),
                  ),
                ),
                PlanToggle(
                  key: ValueKey('plan-enabled-${plan.id}'),
                  value: plan.enabled,
                  onChanged: state.isSaving
                      ? null
                      : (value) {
                          _retry = () => controller.setEnabled(plan.id, value);
                          _retry!();
                        },
                ),
              ],
            ),
          ),
          PlanExpansion(
            isExpanded: state.expandedPlanId == plan.id,
            title: AppStrings.viewDays(revision.cycleDays),
            headerKey: ValueKey('plan-expansion-header-${plan.id}'),
            headerColor: theme.colors.inputSurface,
            showHeaderBorder: true,
            compactHeader: true,
            onTap: () => controller
                .expand(state.expandedPlanId == plan.id ? null : plan.id),
            // Flutter: Column, mainAxis: start, crossAxis: stretch
            child: Column(
              children: [
                for (final day in revision.days)
                  PlanDayExpansionTile(
                    day: day,
                    isCurrent: day.dayNumber == currentDay,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
