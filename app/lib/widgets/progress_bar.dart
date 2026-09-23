import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/workout_skin.dart';

// Flutter: AnimatedBuilder, FractionallySizedBox
// Animation: progress width 300ms, easeOut
final class ProgressBar extends StatefulWidget {
  const ProgressBar({required this.progress, super.key});
  final double progress;

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

final class _ProgressBarState extends State<ProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: WorkoutSkin.progressDuration,
    );
    _animation = AlwaysStoppedAnimation(widget.progress.clamp(0, 1));
  }

  @override
  void didUpdateWidget(covariant ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation = Tween<double>(
      begin: oldWidget.progress.clamp(0, 1),
      end: widget.progress.clamp(0, 1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      height: theme.spacing.s6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.xs),
        child: ColoredBox(
          color: theme.colors.outline,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: _animation.value,
                child: ColoredBox(color: theme.colors.primaryAction),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
