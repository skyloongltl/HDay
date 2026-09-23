import 'package:flutter/material.dart';

@immutable
final class FitnessColors {
  const FitnessColors({
    required this.page,
    required this.hero,
    required this.primaryAction,
    required this.primarySurface,
    required this.mint,
    required this.mintSurface,
    required this.mintText,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.onHero,
    required this.onHeroMuted,
    required this.outline,
    required this.outlineStrong,
    required this.iconSurface,
    required this.navOutline,
    required this.inputSurface,
    required this.danger,
    required this.dangerSurface,
  });

  final Color page;
  final Color hero;
  final Color primaryAction;
  final Color primarySurface;
  final Color mint;
  final Color mintSurface;
  final Color mintText;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color onHero;
  final Color onHeroMuted;
  final Color outline;
  final Color outlineStrong;
  final Color iconSurface;
  final Color navOutline;
  final Color inputSurface;
  final Color danger;
  final Color dangerSurface;
}

@immutable
final class FitnessSpacing {
  const FitnessSpacing({
    required this.s2,
    required this.s4,
    required this.s6,
    required this.s8,
    required this.s10,
    required this.s12,
    required this.s14,
    required this.s16,
    required this.s18,
    required this.s20,
    required this.s24,
    required this.s28,
    required this.s32,
    required this.s40,
    required this.s48,
  });

  final double s2;
  final double s4;
  final double s6;
  final double s8;
  final double s10;
  final double s12;
  final double s14;
  final double s16;
  final double s18;
  final double s20;
  final double s24;
  final double s28;
  final double s32;
  final double s40;
  final double s48;
}

@immutable
final class FitnessRadii {
  const FitnessRadii({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.hero,
    required this.button,
    required this.full,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double hero;
  final double button;
  final double full;
}

@immutable
final class FitnessTypeScale {
  const FitnessTypeScale({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.base,
    required this.md,
    required this.lg,
    required this.xl,
    required this.title,
    required this.restTimer,
    required this.regular,
    required this.medium,
    required this.semibold,
    required this.bold,
    required this.heavy,
  });

  final double xxs;
  final double xs;
  final double sm;
  final double base;
  final double md;
  final double lg;
  final double xl;
  final double title;
  final double restTimer;
  final FontWeight regular;
  final FontWeight medium;
  final FontWeight semibold;
  final FontWeight bold;
  final FontWeight heavy;
}

@immutable
final class FitnessBorders {
  const FitnessBorders({required this.thin, required this.strong});

  final double thin;
  final double strong;
}

@immutable
final class FitnessDimensions {
  const FitnessDimensions({
    required this.zero,
    required this.appBarHeight,
    required this.bottomNavHeight,
    required this.primaryButtonHeight,
    required this.iconButtonSize,
    required this.emptyIconSize,
    required this.compactWidth,
    required this.standardWidth,
    required this.wideWidth,
    required this.maxContentWidth,
  });

  final double zero;
  final double appBarHeight;
  final double bottomNavHeight;
  final double primaryButtonHeight;
  final double iconButtonSize;
  final double emptyIconSize;
  final double compactWidth;
  final double standardWidth;
  final double wideWidth;
  final double maxContentWidth;
}

@immutable
final class FitnessMotion {
  const FitnessMotion({
    required this.fast,
    required this.standard,
    required this.route,
    required this.curve,
  });

  final Duration fast;
  final Duration standard;
  final Duration route;
  final Curve curve;
}

@immutable
final class FitnessOpacities {
  const FitnessOpacities({required this.disabled, required this.overlay});

  final double disabled;
  final double overlay;
}

@immutable
final class FitnessAppCardSkin {
  const FitnessAppCardSkin({
    required this.surface,
    required this.outline,
    required this.radius,
    required this.shadow,
  });

  final Color surface;
  final Color outline;
  final double radius;
  final List<BoxShadow> shadow;
}

@immutable
final class FitnessAppBarSkin {
  const FitnessAppBarSkin({
    required this.surface,
    required this.outline,
    required this.height,
  });

  final Color surface;
  final Color outline;
  final double height;
}

@immutable
final class FitnessBottomNavSkin {
  static const indicatorWidth = 44.0;
  static const indicatorHeight = 3.0;
  static const indicatorDuration = Duration(milliseconds: 250);
  const FitnessBottomNavSkin({
    required this.surface,
    required this.outline,
    required this.indicator,
    required this.height,
  });

  final Color surface;
  final Color outline;
  final Color indicator;
  final double height;
}

@immutable
final class FitnessThemeExtension
    extends ThemeExtension<FitnessThemeExtension> {
  const FitnessThemeExtension({
    required this.colors,
    required this.spacing,
    required this.radii,
    required this.typography,
    required this.borders,
    required this.dimensions,
    required this.motion,
    required this.opacities,
    required this.appCard,
    required this.appBar,
    required this.bottomNav,
    required this.minTapTarget,
  });

  final FitnessColors colors;
  final FitnessSpacing spacing;
  final FitnessRadii radii;
  final FitnessTypeScale typography;
  final FitnessBorders borders;
  final FitnessDimensions dimensions;
  final FitnessMotion motion;
  final FitnessOpacities opacities;
  final FitnessAppCardSkin appCard;
  final FitnessAppBarSkin appBar;
  final FitnessBottomNavSkin bottomNav;
  final double minTapTarget;

  Color get page => colors.page;
  Color get hero => colors.hero;
  Color get primaryAction => colors.primaryAction;
  Color get mint => colors.mint;

  @override
  FitnessThemeExtension copyWith() => this;

  @override
  FitnessThemeExtension lerp(
    covariant FitnessThemeExtension? other,
    double t,
  ) =>
      other == null || t < 0.5 ? this : other;
}
