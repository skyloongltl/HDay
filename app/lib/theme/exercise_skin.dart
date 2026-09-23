import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'fitness_theme_extension.dart';

/// Catalog component skin: Figma's compact visual controls retain 48px hit areas.
class ExerciseSkin {
  const ExerciseSkin(this.theme);
  final FitnessThemeExtension theme;
  static const avatarSize = 36.0;
  static const chipHeight = 30.0;
  static const sheetFraction = .75;
  static const pressedScale = .98;
  static const restingScale = 1.0;
  static const dialogStartScale = .7;
  static const chipDuration = Duration(milliseconds: 150);
  static const sheetDuration = Duration(milliseconds: 280);
  static const dialogDuration = Duration(milliseconds: 250);
  static const notesLines = 3;

  TextStyle get title => TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: theme.typography.base,
        fontWeight: theme.typography.semibold,
        color: theme.colors.text,
      );
  TextStyle get caption => TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: theme.typography.xxs,
        color: theme.colors.textMuted,
      );
  TextStyle get label => caption.copyWith(
        fontWeight: theme.typography.semibold,
        color: theme.colors.textSubtle,
      );
  BoxDecoration panel({
    bool error = false,
    Color? color,
    bool compact = false,
  }) =>
      BoxDecoration(
        color: color ?? theme.appCard.surface,
        border: Border.all(
          color: error ? theme.colors.danger : theme.appCard.outline,
          width: theme.borders.thin,
        ),
        borderRadius: BorderRadius.circular(
          compact ? theme.radii.md : theme.appCard.radius,
        ),
      );
  InputDecoration input(String hint, {Widget? prefix, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.colors.textSubtle,
          fontSize: theme.typography.base,
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: theme.spacing.s12),
        prefixIcon: prefix,
        suffixIcon: suffix,
      );
  ButtonStyle get textButton => TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radii.sm),
        ),
        minimumSize: Size.square(theme.minTapTarget),
        foregroundColor: theme.primaryAction,
        textStyle: title.copyWith(fontWeight: theme.typography.bold),
      );
}

final class ExerciseDashedBorder extends CustomPainter {
  const ExerciseDashedBorder(this.theme);
  final FitnessThemeExtension theme;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(theme.radii.md),
        ),
      );
    final paint = Paint()
      ..color = theme.colors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.borders.thin;
    for (final metric in path.computeMetrics()) {
      for (double start = 0;
          start < metric.length;
          start += theme.spacing.s6 + theme.spacing.s4) {
        canvas.drawPath(
          metric.extractPath(start, start + theme.spacing.s6),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ExerciseDashedBorder oldDelegate) =>
      oldDelegate.theme != theme;
}
