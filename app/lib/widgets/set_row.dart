import 'package:flutter/material.dart';

import '../features/exercises/domain/exercise.dart';
import '../features/workout/domain/workout_draft.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../theme/fitness_theme_extension.dart';
import '../theme/workout_skin.dart';

// Flutter: ListTile (custom), Row, AnimatedBuilder
// Animation: scale 0.97 on press (100ms, easeOut); status colors (200ms, easeOut)
final class SetRow extends StatefulWidget {
  const SetRow({
    required this.index,
    required this.set,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final int index;
  final WorkoutSet set;
  final bool selected;
  final Future<void> Function()? onSelect;

  @override
  State<SetRow> createState() => _SetRowState();
}

final class _SetRowState extends State<SetRow> with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _statusController;
  late final AnimationController _pulseController;
  late final Animation<double> _scale;
  late final Animation<double> _pulse;
  late SetStatus _previousStatus;
  late bool _previousSelected;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: WorkoutSkin.pressDuration,
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
    _statusController = AnimationController(
      vsync: this,
      duration: WorkoutSkin.setStatusDuration,
      value: 1,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: WorkoutSkin.activeSetPulseDuration,
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1).chain(
          CurveTween(curve: WorkoutSkin.activeSetPulseCurve),
        ),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0).chain(
          CurveTween(curve: WorkoutSkin.activeSetPulseCurve),
        ),
        weight: 30,
      ),
    ]).animate(_pulseController);
    _previousStatus = widget.set.status;
    _previousSelected = widget.selected;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.set.status != widget.set.status ||
        oldWidget.selected != widget.selected) {
      _previousStatus = oldWidget.set.status;
      _previousSelected = oldWidget.selected;
      _statusController.forward(from: 0);
      _syncPulse();
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _statusController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final set = widget.set;
    final interactive = widget.onSelect != null;
    final selected = widget.selected;
    final actualReps = set.actualReps ?? set.plannedReps;
    final weight = set.actualWeight ?? set.plannedWeight;
    final weightLabel = set.unit == WeightUnit.bodyweight
        ? AppStrings.bodyweight
        : '${AppStrings.compactNumber(weight)} ${AppStrings.weightUnitLabels[set.unit.code]}';
    return Semantics(
      button: interactive,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: interactive
            ? (_) {
                _pressController.forward();
              }
            : null,
        onTapCancel: interactive ? _release : null,
        onTapUp: interactive ? (_) => _release() : null,
        onTap: widget.onSelect,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _scale,
            _statusController,
            _pulseController,
          ]),
          builder: (context, _) {
            final transition = Curves.easeOut.transform(
              _statusController.value,
            );
            final background = Color.lerp(
              _rowBackground(theme, _previousSelected),
              _rowBackground(theme, selected),
              transition,
            );
            final border = Color.lerp(
              _rowBorder(theme, _previousSelected),
              _rowBorder(theme, selected),
              transition,
            );
            return Transform.scale(
              scale: _scale.value,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: theme.minTapTarget),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(theme.radii.sm),
                    border: Border.all(
                      color: border!,
                      width: theme.borders.strong,
                    ),
                  ),
                  // Flutter: Row, mainAxis: start, crossAxis: center
                  child: Row(
                    children: [
                      SizedBox(width: theme.spacing.s10),
                      _StatusDot(
                        fromStatus: _previousStatus,
                        status: set.status,
                        transition: transition,
                        pulse: _pulse.value,
                      ),
                      SizedBox(width: theme.spacing.s8),
                      SizedBox(
                        width: theme.spacing.s16,
                        child: Text(
                          '${widget.index}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: theme.spacing.s8),
                      Expanded(child: Text(weightLabel)),
                      Text(AppStrings.setReps(actualReps)),
                      SizedBox(width: theme.spacing.s8),
                      SizedBox(
                        width: theme.spacing.s40,
                        child: Text(
                          _statusLabel(set.status),
                          textAlign: TextAlign.end,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Color.lerp(
                                      _statusColor(
                                        theme,
                                        _previousStatus,
                                        _previousSelected,
                                      ),
                                      _statusColor(theme, set.status, selected),
                                      transition,
                                    ),
                                  ),
                        ),
                      ),
                      SizedBox(width: theme.spacing.s10),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _release() {
    _pressController.reverse();
  }

  void _syncPulse() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.set.status == SetStatus.inProgress && !reduceMotion) {
      if (!_pulseController.isAnimating) _pulseController.repeat();
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }
}

final class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.fromStatus,
    required this.status,
    required this.transition,
    required this.pulse,
  });
  final SetStatus fromStatus;
  final SetStatus status;
  final double transition;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final visibleStatus = transition < 0.5 ? fromStatus : status;
    final active = visibleStatus == SetStatus.inProgress;
    final skipped = visibleStatus == SetStatus.skipped;
    return SizedBox.square(
      dimension: theme.spacing.s18,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (active)
            OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxWidth: theme.spacing.s32,
              maxHeight: theme.spacing.s32,
              child: SizedBox.square(
                key: const ValueKey('active-set-pulse'),
                dimension: theme.spacing.s18 + theme.spacing.s12 * pulse,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colors.primaryAction.withValues(
                        alpha: 0.35 * (1 - pulse),
                      ),
                      width: theme.borders.thin,
                    ),
                  ),
                ),
              ),
            ),
          SizedBox.square(
            dimension: theme.spacing.s18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  _dotFill(theme, fromStatus),
                  _dotFill(theme, status),
                  transition,
                ),
                border: Border.all(
                  color: Color.lerp(
                    _dotBorder(theme, fromStatus),
                    _dotBorder(theme, status),
                    transition,
                  )!,
                  width: active || skipped
                      ? theme.borders.strong
                      : theme.borders.thin,
                ),
              ),
              child: skipped
                  ? Icon(Icons.close, size: theme.spacing.s10)
                  : active
                      ? Center(
                          child: SizedBox.square(
                            dimension: theme.spacing.s8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.colors.primaryAction,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}

Color _rowBackground(FitnessThemeExtension theme, bool selected) =>
    selected ? theme.colors.primarySurface : theme.colors.inputSurface;

Color _rowBorder(FitnessThemeExtension theme, bool selected) =>
    selected ? theme.colors.primaryAction : Colors.transparent;

Color _statusColor(
  FitnessThemeExtension theme,
  SetStatus status,
  bool selected,
) =>
    selected
        ? theme.colors.primaryAction
        : status == SetStatus.skipped
            ? theme.colors.textSubtle
            : theme.colors.mintText;

Color _dotFill(FitnessThemeExtension theme, SetStatus status) =>
    status == SetStatus.completed
        ? theme.colors.textMuted
        : status == SetStatus.inProgress
            ? theme.colors.primarySurface
            : Colors.transparent;

Color _dotBorder(FitnessThemeExtension theme, SetStatus status) =>
    status == SetStatus.inProgress
        ? theme.colors.primaryAction
        : status == SetStatus.completed
            ? theme.colors.textMuted
            : theme.colors.outlineStrong;

String _statusLabel(SetStatus status) => switch (status) {
      SetStatus.pending => AppStrings.pendingSet,
      SetStatus.inProgress => AppStrings.activeSet,
      SetStatus.completed => AppStrings.doneSet,
      SetStatus.skipped => AppStrings.skippedSet,
    };
