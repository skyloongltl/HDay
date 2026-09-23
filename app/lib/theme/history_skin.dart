import 'package:flutter/material.dart';
import 'fitness_theme_extension.dart';

/// Figma history/calendar geometry and motion, shared by the three workflows.
abstract final class HistorySkin {
  static const completed = Color(0xff414852);
  static const unfinishedSurface = Color(0xffFEF3C7);
  static const unfinishedText = Color(0xff92400E);
  static const unfinishedBorder = Color(0xffF59E0B);
  static const monthDuration = Duration(milliseconds: 250);
  static const selectionDuration = Duration(milliseconds: 150);
  static const expansionDuration = Duration(milliseconds: 200);
  static const sheetDuration = Duration(milliseconds: 280);
  static const chartHeight = 80.0;
  static const chartMinimum = 10.0;
  static const chartMaximum = 50.0;
  static const sheetFraction = .85;
  static const iconSize = 52.0;
  static const monthSlide = Offset(.08, 0);
  static const restOffset = Offset.zero;
  static const halfTurn = .5;
  static const zero = 0.0;
  static const one = 1.0;
  static const dialogScale = .7;
  static const noteLines = 2;
  static const chipVerticalPadding = 3.0;
  static const previewExerciseLimit = 4;
  static const recentDividerHeight = 36.0;
  static BoxDecoration card(FitnessThemeExtension theme, {bool hero = false}) =>
      BoxDecoration(
        color: hero ? theme.hero : theme.colors.surface,
        border: hero
            ? null
            : Border.all(
                color: theme.colors.outline,
                width: theme.borders.thin,
              ),
        borderRadius:
            BorderRadius.circular(hero ? theme.radii.hero : theme.radii.lg),
      );
  static ButtonStyle button(FitnessThemeExtension theme) =>
      TextButton.styleFrom(
        minimumSize: Size.square(theme.minTapTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radii.sm),
        ),
      );
}
