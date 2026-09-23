import 'package:flutter/material.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/plan_skin.dart';
import '../domain/plan_day.dart';

class PlanDayExpansionTile extends StatefulWidget {
  const PlanDayExpansionTile({
    required this.day,
    required this.isCurrent,
    super.key,
  });
  final PlanDay day;
  final bool isCurrent;
  @override
  State<PlanDayExpansionTile> createState() => _PlanDayExpansionTileState();
}

class _PlanDayExpansionTileState extends State<PlanDayExpansionTile> {
  bool isExpanded = false; // Flutter: setState
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    final day = widget.day;
    return DecoratedBox(
      key: ValueKey('plan-day-divider-${day.dayNumber}'),
      decoration: BoxDecoration(
        color: widget.isCurrent
            ? theme.colors.primarySurface
            : theme.colors.surface,
        border: Border(
          top: BorderSide(
            color: theme.colors.outline,
            width: theme.borders.thin,
          ),
        ),
      ),
      child: SizedBox(
        key: ValueKey('plan-day-${day.dayNumber}'),
        child: PlanExpansion(
          isExpanded: isExpanded && !day.isRest,
          title: '${AppStrings.dayLabel(day.dayNumber)} · ${day.name}',
          titleWidget: Row(
            children: [
              Expanded(
                child: Text(
                  '${AppStrings.dayLabel(day.dayNumber)} · ${day.name}',
                  style: skin.title.copyWith(
                    fontWeight: widget.isCurrent
                        ? theme.typography.bold
                        : theme.typography.medium,
                  ),
                ),
              ),
              if (widget.isCurrent) ...[
                SizedBox(width: theme.spacing.s10),
                SizedBox(
                  key: const Key('plan-current-day-dot'),
                  width: theme.spacing.s6,
                  height: theme.spacing.s6,
                  child: DecoratedBox(
                    key: ValueKey('plan-current-day-dot-${day.dayNumber}'),
                    decoration: BoxDecoration(
                      color: theme.primaryAction,
                      borderRadius: BorderRadius.circular(theme.radii.full),
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: day.isRest
              ? AppStrings.restDay
              : AppStrings.daySummary(
                  day.exercises.length,
                  day.exercises.fold(0, (n, e) => n + e.sets.length),
                ),
          onTap: day.isRest
              ? null
              : () => setState(() => isExpanded = !isExpanded),
          // Flutter: Column, mainAxis: start, crossAxis: stretch
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < day.exercises.length; index++)
                _PlanExerciseRow(
                  exercise: day.exercises[index],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlanExpansion extends StatefulWidget {
  const PlanExpansion({
    required this.isExpanded,
    required this.title,
    required this.onTap,
    required this.child,
    this.subtitle,
    this.titleWidget,
    this.headerKey,
    this.headerColor,
    this.showHeaderBorder = false,
    this.compactHeader = false,
    super.key,
  });
  final bool isExpanded;
  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Key? headerKey;
  final Color? headerColor;
  final bool showHeaderBorder;
  final bool compactHeader;
  final VoidCallback? onTap;
  final Widget child;
  @override
  State<PlanExpansion> createState() => _PlanExpansionState();
}

class _PlanExpansionState extends State<PlanExpansion>
    with SingleTickerProviderStateMixin {
  late final AnimationController expansion = AnimationController(
    vsync: this,
    duration: PlanSkin.dayScrollDuration,
    value: widget.isExpanded ? PlanSkin.expanded : PlanSkin.collapsed,
  );
  late final Animation<double> curve =
      CurvedAnimation(parent: expansion, curve: Curves.easeOut);
  @override
  void didUpdateWidget(covariant PlanExpansion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded) {
      expansion.forward();
    } else {
      expansion.reverse();
    }
  }

  @override
  void dispose() {
    expansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    // Animation: explicit height and chevron rotation 200ms easeOut.
    // Flutter: Column, mainAxis: start, crossAxis: stretch
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            key: widget.headerKey,
            color: widget.headerColor ?? Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                border: widget.showHeaderBorder
                    ? Border(
                        top: BorderSide(
                          color: theme.colors.outline,
                          width: theme.borders.thin,
                        ),
                      )
                    : null,
              ),
              child: ListTile(
                dense: true,
                minTileHeight: widget.compactHeader
                    ? theme.spacing.s40
                    : theme.minTapTarget,
                visualDensity: widget.compactHeader
                    ? const VisualDensity(vertical: -4)
                    : VisualDensity.compact,
                onTap: widget.onTap,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: theme.spacing.s14),
                title:
                    widget.titleWidget ?? Text(widget.title, style: skin.title),
                subtitle: widget.subtitle == null
                    ? null
                    : Text(widget.subtitle!, style: skin.caption),
                trailing: widget.onTap == null
                    ? null
                    : _ExpansionChevron(animation: curve),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: curve,
            alignment: Alignment.topCenter,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ExpansionChevron extends StatelessWidget {
  const _ExpansionChevron({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return RotationTransition(
      key: const Key('plan-expansion-chevron'),
      turns: Tween<double>(
        begin: PlanSkin.collapsed,
        end: PlanSkin.chevronTurns,
      ).animate(animation),
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: theme.typography.lg,
        color: theme.colors.textMuted,
      ),
    );
  }
}

class _PlanExerciseRow extends StatelessWidget {
  const _PlanExerciseRow({
    required this.exercise,
  });

  final PlanExercise exercise;

  String get summary {
    final sets = exercise.sets;
    if (sets.isEmpty) return AppStrings.setSummary(0);
    final variants = <String>{
      for (final set in sets)
        '${AppStrings.compactNumber(set.plannedWeight)}'
            '${AppStrings.weightUnitLabels[set.unit.code]}'
            '×${set.plannedReps}次',
    };
    if (variants.length == 1) {
      final set = sets.first;
      return AppStrings.planExerciseSummary(
        sets.length,
        set.plannedWeight,
        set.unit.code,
        set.plannedReps,
      );
    }
    return AppStrings.variedPlanExerciseSummary(
      sets.length,
      variants.join(' / '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final skin = PlanSkin(theme);
    return Container(
      key: ValueKey('plan-exercise-${exercise.id}'),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colors.outline,
            width: theme.borders.thin,
          ),
        ),
      ),
      child: ListTile(
        dense: true,
        minTileHeight: theme.spacing.s48,
        visualDensity: const VisualDensity(vertical: -3),
        contentPadding: EdgeInsets.symmetric(horizontal: theme.spacing.s14),
        title: Text(exercise.nameSnapshot, style: skin.title),
        subtitle: Text(summary, style: skin.caption),
      ),
    );
  }
}
