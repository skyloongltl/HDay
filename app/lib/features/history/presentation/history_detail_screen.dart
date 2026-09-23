import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/domain/local_date.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/history_skin.dart';
import '../../../widgets/app_bar.dart';
import '../../workout/domain/workout_draft.dart';
import '../../workout/domain/workout_session.dart';
import '../application/history_providers.dart';
import 'session_expansion_tile.dart';

// PAGE: HistoryDetailScreen
// ROUTE: /history/:date
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, Card, ExpansionTile, AlertDialog
// STATE: expandedSessionIdx(int?), showDeleteConfirm(bool), isLoading(bool), deleteFailedId(String?)
// ANIMATIONS: explicit expansion 200ms easeOut; delete overlay fade + scale .7 -> 1 250ms easeOut
// NAVIGATION: back -> caller/calendar; correction -> HistorySetEditorSheet
final class HistoryDetailScreen extends ConsumerStatefulWidget {
  const HistoryDetailScreen({
    required this.date,
    this.initialSessionId,
    super.key,
  });
  final LocalDate date;
  final String? initialSessionId;
  @override
  ConsumerState<HistoryDetailScreen> createState() =>
      _HistoryDetailScreenState();
}

final class _HistoryDetailScreenState
    extends ConsumerState<HistoryDetailScreen> {
  int? expandedSessionIdx = 0; // Flutter: setState
  bool showDeleteConfirm = false; // Flutter: setState
  bool isLoading = true; // Flutter: setState
  String? deleteFailedId; // Flutter: setState
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant HistoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      isLoading = true;
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() async {
    try {
      await ref.read(historyControllerProvider.future);
      await ref.read(historyControllerProvider.notifier).loadDay(widget.date);
      if (!mounted) return;
      final sessions =
          ref.read(historyControllerProvider).requireValue.sessions;
      final index = sessions.indexWhere((s) => s.id == widget.initialSessionId);
      setState(() {
        isLoading = false;
        expandedSessionIdx = index < 0 ? 0 : index;
      });
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _delete(String id) async {
    setState(() => showDeleteConfirm = true);
    final theme = AppTheme.of(context);
    final qualifying = ref
        .read(historyControllerProvider)
        .requireValue
        .sessions
        .where((s) => s.phase == WorkoutPhase.saved && s.hasCompletedSet)
        .length;
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierColor:
          theme.colors.text.withValues(alpha: theme.opacities.overlay),
      transitionDuration: HistorySkin.monthDuration,
      pageBuilder: (dialogContext, _, __) => AlertDialog(
        title: const Text(AppStrings.deleteHistoryTitle),
        content: Text(
          qualifying == 1
              ? AppStrings.deleteLastHistoryHint
              : AppStrings.deleteHistoryHint,
        ),
        actions: [
          TextButton(
            style: HistorySkin.button(theme),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            style: HistorySkin.button(theme).copyWith(
              foregroundColor: WidgetStatePropertyAll(theme.colors.danger),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.confirmDelete),
          ),
        ],
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: HistorySkin.dialogScale,
            end: HistorySkin.one,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
          ),
          child: child,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => showDeleteConfirm = false);
    if (confirmed != true) return;
    final result =
        await ref.read(historyControllerProvider.notifier).deleteSession(id);
    if (mounted) {
      setState(() {
        deleteFailedId = result ? null : id;
        if (result) expandedSessionIdx = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final view = ref.watch(historyControllerProvider);
    return SafeArea(
      child: Scaffold(
        key: const ValueKey('history-day-detail'),
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            '${AppStrings.historyDate(widget.date.month, widget.date.day)} · ${AppStrings.historySnapshot}',
          ),
          leading: CircularBackButton(
            key: const ValueKey('history-back'),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.calendar),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : view.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  // Flutter: Column, mainAxis: center, crossAxis: center
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(AppStrings.historyLoadFailed),
                      TextButton(
                        onPressed: () {
                          ref.invalidate(historyRepositoryProvider);
                          ref.invalidate(historyControllerProvider);
                          _load();
                        },
                        child: const Text(AppStrings.retry),
                      ),
                    ],
                  ),
                ),
                // Flutter: ListView, mainAxis: start, crossAxis: stretch
                data: (value) => ListView(
                  padding: EdgeInsets.all(theme.spacing.s16),
                  children: [
                    if (value.isSaving) const LinearProgressIndicator(),
                    if (deleteFailedId != null) ...[
                      Text(
                        AppStrings.historyDeleteFailed,
                        style: TextStyle(color: theme.colors.danger),
                      ),
                      TextButton(
                        onPressed: () => _delete(deleteFailedId!),
                        child: const Text(AppStrings.retry),
                      ),
                    ],
                    if (value.failure != null &&
                        deleteFailedId == null &&
                        value.sessions.isEmpty)
                      TextButton(
                        onPressed: _load,
                        child: const Text(AppStrings.historyLoadFailed),
                      ),
                    _summary(value.sessions),
                    // Spacer: spacing.16 -> SizedBox(height: spacing.16)
                    SizedBox(height: theme.spacing.s16),
                    Text(
                      AppStrings.sessionCount(value.sessions.length),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (value.sessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.zero,
                        child: Text(AppStrings.noDateHistory),
                      ),
                    for (final entry in value.sessions.indexed)
                      Padding(
                        padding: EdgeInsets.only(top: theme.spacing.s12),
                        child: SessionExpansionTile(
                          key: ValueKey(entry.$2.id),
                          session: entry.$2,
                          index: entry.$1,
                          isExpanded: expandedSessionIdx == entry.$1,
                          onToggle: () => setState(
                            () => expandedSessionIdx =
                                expandedSessionIdx == entry.$1
                                    ? null
                                    : entry.$1,
                          ),
                          onDelete: () => _delete(entry.$2.id),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summary(List<WorkoutSession> sessions) {
    final theme = AppTheme.of(context);
    final sets = sessions.expand((s) => s.exercises).expand((e) => e.sets);
    final completed = sets.where((s) => s.status == SetStatus.completed).length;
    final duration =
        sessions.fold(0, (n, s) => n + s.timer.accumulatedActiveSeconds);
    final exerciseCount = sessions
        .expand((s) => s.exercises)
        .map((e) => e.exerciseId)
        .toSet()
        .length;
    return DecoratedBox(
      decoration: HistorySkin.card(theme, hero: true),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.s20,
          vertical: theme.spacing.s18,
        ),
        // Flutter: Row, mainAxis: spaceBetween, crossAxis: center
        child: Row(
          children: [
            for (final stat in [
              (
                AppStrings.historyDuration(duration),
                AppStrings.totalTrainingDuration
              ),
              ('$completed/${sets.length}', AppStrings.completedSets),
              ('$exerciseCount', AppStrings.completedExercises),
            ])
              Expanded(
                // Flutter: Column, mainAxis: start, crossAxis: center
                child: Column(
                  children: [
                    Text(
                      stat.$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colors.onHero,
                        fontSize: theme.typography.xl,
                        fontWeight: theme.typography.heavy,
                      ),
                    ),
                    Text(
                      stat.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colors.onHeroMuted,
                        fontSize: theme.typography.xxs,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
