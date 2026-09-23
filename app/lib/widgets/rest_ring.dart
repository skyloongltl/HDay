import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../theme/workout_skin.dart';

// Flutter: CustomPaint, Stack, AnimatedBuilder
// Animation: ring stroke 1000ms linear; overtime color 300ms easeOut
final class RestRing extends StatefulWidget {
  const RestRing({
    required this.elapsedSeconds,
    required this.targetSeconds,
    super.key,
  });
  final int elapsedSeconds;
  final int targetSeconds;

  @override
  State<RestRing> createState() => _RestRingState();
}

final class _RestRingState extends State<RestRing>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _overtimeController;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: WorkoutSkin.restRingDuration,
    );
    _overtimeController = AnimationController(
      vsync: this,
      duration: WorkoutSkin.overtimeDuration,
      value: widget.elapsedSeconds >= widget.targetSeconds ? 1 : 0,
    );
    _progress = AlwaysStoppedAnimation(_value(widget));
  }

  @override
  void didUpdateWidget(covariant RestRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _progress = Tween<double>(begin: _value(oldWidget), end: _value(widget))
        .animate(_controller);
    _controller.forward(from: 0);
    if ((oldWidget.elapsedSeconds >= oldWidget.targetSeconds) !=
        (widget.elapsedSeconds >= widget.targetSeconds)) {
      if (widget.elapsedSeconds >= widget.targetSeconds) {
        _overtimeController.forward();
      } else {
        _overtimeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _overtimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final isOver = widget.elapsedSeconds >= widget.targetSeconds;
    final remaining =
        (widget.targetSeconds - widget.elapsedSeconds).clamp(0, 1 << 31);
    return SizedBox.square(
      dimension: WorkoutSkin.restRingSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([_progress, _overtimeController]),
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CustomPaint(
                painter: _RestRingPainter(
                  progress: _progress.value,
                  strokeWidth: theme.spacing.s10,
                  trackColor: theme.colors.outline,
                  progressColor: Color.lerp(
                    theme.colors.primaryAction,
                    theme.colors.mint,
                    _overtimeController.value,
                  )!,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _format(widget.elapsedSeconds),
                    maxLines: 1,
                    style: TextStyle(
                      color: Color.lerp(
                        theme.colors.text,
                        theme.colors.mintText,
                        _overtimeController.value,
                      ),
                      fontSize: theme.typography.restTimer,
                      fontWeight: theme.typography.heavy,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: theme.spacing.s8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isOver
                          ? AppStrings.restTargetReached
                          : AppStrings.restRemaining(_format(remaining)),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _value(RestRing value) =>
      (value.elapsedSeconds / value.targetSeconds.clamp(1, 1 << 31))
          .clamp(0, 1);
}

final class _RestRingPainter extends CustomPainter {
  const _RestRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = progressColor;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RestRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      progressColor != oldDelegate.progressColor ||
      trackColor != oldDelegate.trackColor ||
      strokeWidth != oldDelegate.strokeWidth;
}

String _format(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
