import 'package:flutter/material.dart';
import 'exercise_skin.dart';

/// Plan-specific Figma dimensions; colors/typography come from shared skin.
class PlanSkin extends ExerciseSkin {
  const PlanSkin(super.theme);
  static const dayTabWidth = 64.0;
  static const dayTabVisualHeight = 32.0;
  static const toggleWidth = 42.0;
  static const toggleHeight = 24.0;
  static const toggleThumb = 18.0;
  static const toggleInset = 3.0;
  static const expanded = 1.0;
  static const collapsed = 0.0;
  static const chevronTurns = .5;
  static const topAlignment = -1.0;
  static const dayTabHeight = 60.0;
  static const numberSize = 26.0;
  static const compactActionHeight = 32.0;
  static const menuItemHeight = 40.0;
  static const searchSheetFraction = .7;
  static const switchScale = .8;
  static const dayScrollDuration = Duration(milliseconds: 200);
  static const fieldFadeDuration = Duration(milliseconds: 200);
  static const dateFirstYear = 2000;
  static const dateLastYear = 2200;
  static const previewDayLimit = 7;
  static const notesLines = 2;
  BoxDecoration get statusBadge => BoxDecoration(
        color: theme.colors.primarySurface,
        borderRadius: BorderRadius.circular(theme.radii.full),
      );
  BoxDecoration get summaryPanel => BoxDecoration(
        color: theme.colors.inputSurface,
        borderRadius: BorderRadius.circular(theme.radii.md),
      );
  ButtonStyle get pill => textButton.copyWith(
        shape: WidgetStatePropertyAll(
          StadiumBorder(
            side: BorderSide(
              color: theme.colors.outline,
              width: theme.borders.thin,
            ),
          ),
        ),
        textStyle: WidgetStatePropertyAll(
          caption.copyWith(fontWeight: theme.typography.bold),
        ),
      );

  ButtonStyle get compactAction => textButton.copyWith(
        minimumSize: WidgetStatePropertyAll(
          Size(0, theme.minTapTarget),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStatePropertyAll(theme.colors.onHero),
        textStyle: WidgetStatePropertyAll(
          caption.copyWith(fontWeight: theme.typography.bold),
        ),
      );

  BoxDecoration get compactActionVisual => BoxDecoration(
        color: theme.colors.primaryAction,
        border: Border.all(
          color: theme.primaryAction,
          width: theme.borders.thin,
        ),
        borderRadius: BorderRadius.circular(theme.radii.full),
      );

  ShapeBorder get menuShape => RoundedRectangleBorder(
        side: BorderSide(
          color: theme.colors.outline,
          width: theme.borders.thin,
        ),
        borderRadius: BorderRadius.circular(theme.radii.md),
      );

  BoxConstraints get menuConstraints => BoxConstraints(
        minWidth: theme.spacing.s40 * 3.5,
        maxWidth: theme.spacing.s40 * 5.5,
      );

  EdgeInsets get menuPadding => EdgeInsets.symmetric(
        vertical: theme.spacing.s4,
      );
}
