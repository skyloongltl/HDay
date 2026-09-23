import 'package:flutter/material.dart';

import 'app_theme_definition.dart';
import 'fitness_theme_extension.dart';

abstract final class AppTheme {
  static const fontFamily = 'Noto Sans SC';

  static Color colorToken(AppThemeDefinition definition, String key) =>
      _color(definition.tokens, key);
  static FitnessThemeExtension of(BuildContext context) {
    final extension = Theme.of(context).extension<FitnessThemeExtension>();
    if (extension == null) {
      throw StateError('FitnessThemeExtension is not installed.');
    }
    return extension;
  }

  static ThemeData build(AppThemeDefinition definition) {
    final tokens = definition.tokens;
    final skins = definition.skins;
    final colors = FitnessColors(
      page: _color(tokens, 'colors.fogBg'),
      hero: _color(tokens, 'colors.deepBlue'),
      primaryAction: _color(tokens, 'colors.coral'),
      primarySurface: _color(tokens, 'colors.coralSurface'),
      mint: _color(tokens, 'colors.mint'),
      mintSurface: _color(tokens, 'colors.mintSurface'),
      mintText: _color(tokens, 'colors.mintText'),
      surface: _color(tokens, 'colors.white'),
      text: _color(tokens, 'colors.text'),
      textMuted: _color(tokens, 'colors.textMuted'),
      textSubtle: _color(tokens, 'colors.textSubtle'),
      onHero: _color(tokens, 'colors.onDeep'),
      onHeroMuted: _color(tokens, 'colors.onDeepMuted'),
      outline: _color(tokens, 'colors.border'),
      outlineStrong: _color(tokens, 'colors.borderStrong'),
      iconSurface: _color(tokens, 'colors.iconBtn'),
      navOutline: _color(tokens, 'colors.navBorder'),
      inputSurface: _color(tokens, 'colors.inputBg'),
      danger: _color(tokens, 'colors.danger'),
      dangerSurface: _color(tokens, 'colors.dangerSurface'),
    );
    final spacing = FitnessSpacing(
      s2: _number(tokens, 'spacing.2'),
      s4: _number(tokens, 'spacing.4'),
      s6: _number(tokens, 'spacing.6'),
      s8: _number(tokens, 'spacing.8'),
      s10: _number(tokens, 'spacing.10'),
      s12: _number(tokens, 'spacing.12'),
      s14: _number(tokens, 'spacing.14'),
      s16: _number(tokens, 'spacing.16'),
      s18: _number(tokens, 'spacing.18'),
      s20: _number(tokens, 'spacing.20'),
      s24: _number(tokens, 'spacing.24'),
      s28: _number(tokens, 'spacing.28'),
      s32: _number(tokens, 'spacing.32'),
      s40: _number(tokens, 'spacing.40'),
      s48: _number(tokens, 'spacing.48'),
    );
    final radii = FitnessRadii(
      xs: _number(tokens, 'radius.xs'),
      sm: _number(tokens, 'radius.sm'),
      md: _number(tokens, 'radius.md'),
      lg: _number(tokens, 'radius.lg'),
      xl: _number(tokens, 'radius.xl'),
      hero: _number(tokens, 'radius.hero'),
      button: _number(tokens, 'radius.btn'),
      full: _number(tokens, 'radius.full'),
    );
    final type = FitnessTypeScale(
      xxs: _number(tokens, 'fontSize.xxs'),
      xs: _number(tokens, 'fontSize.xs'),
      sm: _number(tokens, 'fontSize.sm'),
      base: _number(tokens, 'fontSize.base'),
      md: _number(tokens, 'fontSize.md'),
      lg: _number(tokens, 'fontSize.lg'),
      xl: _number(tokens, 'fontSize.xl'),
      title: _number(tokens, 'fontSize.title'),
      restTimer: _number(tokens, 'fontSize.restTimer'),
      regular: _weight(tokens, 'fontWeight.regular'),
      medium: _weight(tokens, 'fontWeight.medium'),
      semibold: _weight(tokens, 'fontWeight.semibold'),
      bold: _weight(tokens, 'fontWeight.bold'),
      heavy: _weight(tokens, 'fontWeight.heavy'),
    );
    final appCard = FitnessAppCardSkin(
      surface: _skinColor(tokens, skins, 'appCard', 'surface'),
      outline: _skinColor(tokens, skins, 'appCard', 'outline'),
      radius: _skinNumber(tokens, skins, 'appCard', 'radius'),
      shadow: [
        BoxShadow(
          color: _skinColor(tokens, skins, 'appCard', 'shadow'),
          blurRadius: _number(tokens, 'shadow.cardBlur'),
          offset: Offset(
            _number(tokens, 'dimensions.zero'),
            _number(tokens, 'shadow.cardOffsetY'),
          ),
        ),
      ],
    );
    final appBar = FitnessAppBarSkin(
      surface: _skinColor(tokens, skins, 'appBar', 'surface'),
      outline: _skinColor(tokens, skins, 'appBar', 'outline'),
      height: _skinNumber(tokens, skins, 'appBar', 'height'),
    );
    final bottomNav = FitnessBottomNavSkin(
      surface: _skinColor(tokens, skins, 'bottomNav', 'surface'),
      outline: _skinColor(tokens, skins, 'bottomNav', 'outline'),
      indicator: _skinColor(tokens, skins, 'bottomNav', 'indicator'),
      height: _skinNumber(tokens, skins, 'bottomNav', 'height'),
    );
    final extension = FitnessThemeExtension(
      colors: colors,
      spacing: spacing,
      radii: radii,
      typography: type,
      borders: FitnessBorders(
        thin: _number(tokens, 'border.thin'),
        strong: _number(tokens, 'border.strong'),
      ),
      dimensions: FitnessDimensions(
        zero: _number(tokens, 'dimensions.zero'),
        appBarHeight: _number(tokens, 'dimensions.appBarHeight'),
        bottomNavHeight: _number(tokens, 'dimensions.bottomNavHeight'),
        primaryButtonHeight: _number(tokens, 'dimensions.primaryButtonHeight'),
        iconButtonSize: _number(tokens, 'dimensions.iconButtonSize'),
        emptyIconSize: _number(tokens, 'dimensions.emptyIconSize'),
        compactWidth: _number(tokens, 'dimensions.compactWidth'),
        standardWidth: _number(tokens, 'dimensions.standardWidth'),
        wideWidth: _number(tokens, 'dimensions.wideWidth'),
        maxContentWidth: _number(tokens, 'dimensions.maxContentWidth'),
      ),
      motion: FitnessMotion(
        fast: Duration(
          milliseconds: _number(tokens, 'animation.fastMs').round(),
        ),
        standard: Duration(
          milliseconds: _number(tokens, 'animation.standardMs').round(),
        ),
        route: Duration(
          milliseconds: _number(tokens, 'animation.routeMs').round(),
        ),
        curve: Curves.easeOut,
      ),
      opacities: FitnessOpacities(
        disabled: _number(tokens, 'opacity.disabled'),
        overlay: _number(tokens, 'opacity.overlay'),
      ),
      appCard: appCard,
      appBar: appBar,
      bottomNav: bottomNav,
      minTapTarget: _number(tokens, 'minTap.target'),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primaryAction,
      surface: colors.surface,
    ).copyWith(
      primary: colors.primaryAction,
      onPrimary: colors.onHero,
      secondary: colors.mint,
      onSecondary: colors.text,
      error: colors.danger,
      surface: colors.surface,
      onSurface: colors.text,
      outline: colors.outline,
    );
    final textTheme = TextTheme(
      headlineLarge: TextStyle(
        color: colors.text,
        fontSize: type.title,
        fontWeight: type.heavy,
      ),
      titleLarge: TextStyle(
        color: colors.text,
        fontSize: type.xl,
        fontWeight: type.bold,
      ),
      titleMedium: TextStyle(
        color: colors.text,
        fontSize: type.md,
        fontWeight: type.bold,
      ),
      bodyLarge: TextStyle(
        color: colors.text,
        fontSize: type.base,
        fontWeight: type.regular,
      ),
      bodyMedium: TextStyle(
        color: colors.textMuted,
        fontSize: type.sm,
        fontWeight: type.regular,
      ),
      labelLarge: TextStyle(
        color: colors.text,
        fontSize: type.md,
        fontWeight: type.bold,
      ),
      labelMedium: TextStyle(
        color: colors.textMuted,
        fontSize: type.xxs,
        fontWeight: type.medium,
      ),
    ).apply(fontFamily: fontFamily);

    return ThemeData(
      fontFamily: fontFamily,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.page,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: appBar.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.text,
        elevation: extension.dimensions.zero,
        scrolledUnderElevation: extension.dimensions.zero,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: colors.hero,
        headerForegroundColor: colors.onHero,
        todayBorder: BorderSide(
          color: colors.primaryAction,
          width: extension.borders.thin,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primaryAction
              : Colors.transparent,
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onHero
              : colors.text,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primaryAction
              : Colors.transparent,
        ),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onHero
              : colors.text,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: bottomNav.height,
        backgroundColor: bottomNav.surface,
        indicatorColor: bottomNav.indicator,
        elevation: extension.dimensions.zero,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size.square(extension.minTapTarget),
          ),
          foregroundColor: WidgetStatePropertyAll(colors.textMuted),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: WidgetStatePropertyAll(extension.dimensions.zero),
          minimumSize: WidgetStatePropertyAll(
            Size.fromHeight(extension.dimensions.primaryButtonHeight),
          ),
          backgroundColor: WidgetStatePropertyAll(colors.primaryAction),
          foregroundColor: WidgetStatePropertyAll(colors.onHero),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radii.button),
            ),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      extensions: [extension],
    );
  }

  static double _number(Map<String, Object?> tokens, String key) {
    final value = tokens[key];
    if (value is! num) {
      throw FormatException('Theme token $key must be numeric.');
    }
    return value.toDouble();
  }

  static double _skinNumber(
    Map<String, Object?> tokens,
    Map<String, Object?> skins,
    String skin,
    String property,
  ) =>
      _number(tokens, _skinReference(tokens, skins, skin, property));

  static Color _skinColor(
    Map<String, Object?> tokens,
    Map<String, Object?> skins,
    String skin,
    String property,
  ) =>
      _color(tokens, _skinReference(tokens, skins, skin, property));

  static String _skinReference(
    Map<String, Object?> tokens,
    Map<String, Object?> skins,
    String skin,
    String property,
  ) {
    final skinValue = skins[skin];
    if (skinValue is! Map<String, Object?>) {
      throw FormatException('Theme skin $skin must be an object.');
    }
    final reference = skinValue[property];
    if (reference is! String || !tokens.containsKey(reference)) {
      throw FormatException(
        'Theme skin $skin.$property must reference an existing token.',
      );
    }
    return reference;
  }

  static FontWeight _weight(Map<String, Object?> tokens, String key) =>
      FontWeight.values.firstWhere(
        (weight) => weight.value == _number(tokens, key).round(),
        orElse: () => throw FormatException(
          'Theme token $key is not a supported font weight.',
        ),
      );

  static Color _color(Map<String, Object?> tokens, String key) {
    final value = tokens[key];
    if (value is! String) {
      throw FormatException('Theme token $key must be a color string.');
    }
    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return Color(int.parse('ff${value.substring(1)}', radix: 16));
    }
    final match = RegExp(
      r'^rgba\((\d+),(\d+),(\d+),(0(?:\.\d+)?|1(?:\.0+)?)\)$',
    ).firstMatch(value);
    if (match == null) {
      throw FormatException('Theme token $key is not a supported color.');
    }
    return Color.fromRGBO(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      double.parse(match.group(4)!),
    );
  }
}
