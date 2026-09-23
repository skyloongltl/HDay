import 'dart:convert';

import 'package:fitness_counter/core/platform/theme_package_source.dart';
import 'package:fitness_counter/theme/app_theme.dart';
import 'package:fitness_counter/theme/app_theme_definition.dart';
import 'package:fitness_counter/theme/breath_rhythm.dart';
import 'package:fitness_counter/theme/fitness_theme_extension.dart';
import 'package:fitness_counter/theme/theme_id.dart';
import 'package:fitness_counter/theme/theme_registry.dart';
import 'package:fitness_counter/widgets/app_bar.dart';
import 'package:fitness_counter/widgets/app_card.dart';
import 'package:fitness_counter/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_asset_bundle.dart';

const _manifestPath = 'assets/themes/breath-rhythm/manifest.json';
const _schemaPath = 'assets/themes/theme-package.schema.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('arbitrary future theme id resolves by registry without enum', () {
    final registry = ThemeRegistry([breathRhythmDefinition]);

    expect(
      registry.resolve(const ThemeId('future-pack')).manifest.id,
      const ThemeId('breath-rhythm'),
    );
    expect(
      registry.available.single.tokens['colors.coral'],
      '#C76F62',
    );
  });

  test('breath rhythm exposes the canonical semantic palette', () {
    expect(
      breathRhythmDefinition.tokens,
      containsPair('colors.coral', '#C76F62'),
    );
    expect(
      breathRhythmDefinition.tokens,
      containsPair('colors.fogBg', '#F4F7FA'),
    );
    expect(
      breathRhythmDefinition.tokens,
      containsPair('colors.deepBlue', '#19344C'),
    );
    expect(
      breathRhythmDefinition.tokens,
      containsPair('colors.mint', '#62E6CA'),
    );

    final theme = AppTheme.build(breathRhythmDefinition);
    final fitness = theme.extension<FitnessThemeExtension>()!;
    expect(theme.colorScheme.primary, const Color(0xffc76f62));
    expect(theme.scaffoldBackgroundColor, const Color(0xfff4f7fa));
    expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
    expect(theme.datePickerTheme.backgroundColor, fitness.colors.surface);
    expect(theme.datePickerTheme.surfaceTintColor, Colors.transparent);
    expect(theme.datePickerTheme.headerBackgroundColor, fitness.colors.hero);
    expect(theme.datePickerTheme.headerForegroundColor, fitness.colors.onHero);
    expect(fitness.hero, const Color(0xff19344c));
    expect(fitness.mint, const Color(0xff62e6ca));
    expect(fitness.minTapTarget, 48);
  });

  testWidgets('AppTheme.of returns the installed semantic extension',
      (tester) async {
    FitnessThemeExtension? captured;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(breathRhythmDefinition),
        home: Builder(
          builder: (context) {
            captured = AppTheme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(captured?.primaryAction, const Color(0xffc76f62));
    expect(captured?.page, const Color(0xfff4f7fa));
  });

  test('duplicate ids are rejected instead of silently shadowed', () {
    expect(
      () => ThemeRegistry([
        breathRhythmDefinition,
        breathRhythmDefinition,
      ]),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('breath-rhythm'),
        ),
      ),
    );
  });

  test('registry without the built-in fallback is rejected', () {
    final futureDefinition = breathRhythmDefinition.copyWith(
      id: const ThemeId('future-pack'),
    );

    expect(
      () => ThemeRegistry([futureDefinition]),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('breath-rhythm'),
        ),
      ),
    );
  });

  test('bundled data package loads manifest, tokens, and shared skins',
      () async {
    final definitions = await const BundledThemePackageSource().load();

    expect(definitions, hasLength(1));
    expect(definitions.single.manifest.id, const ThemeId('breath-rhythm'));
    expect(definitions.single.manifest.schemaVersion, 1);
    expect(definitions.single.tokens['colors.coral'], '#C76F62');
    expect(definitions.single.skins, contains('appCard'));
    expect(definitions.single.skins, contains('bottomNav'));
  });

  test('theme package missing a required semantic token is rejected', () async {
    final package = await _bundledPackage();
    final tokens = package['tokens']! as Map<String, Object?>;
    tokens.remove('colors.coral');
    final source = await _sourceFor(package);

    expect(
      source.load,
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('colors.coral'),
        ),
      ),
    );
  });

  final invalidPackages = <String, void Function(Map<String, Object?>)>{
    'unknown top-level fields': (package) {
      package['unknown'] = true;
    },
    'unknown manifest fields': (package) {
      final manifest = package['manifest']! as Map<String, Object?>;
      manifest['unknown'] = true;
    },
    'unsupported schema versions': (package) {
      final manifest = package['manifest']! as Map<String, Object?>;
      manifest['schemaVersion'] = 2;
    },
    'empty shared skins': (package) {
      package['skins'] = <String, Object?>{};
    },
    'invalid semantic token types': (package) {
      final tokens = package['tokens']! as Map<String, Object?>;
      tokens['colors.coral'] = 123;
    },
    'non-string skin values': (package) {
      final skins = package['skins']! as Map<String, Object?>;
      final appCard = skins['appCard']! as Map<String, Object?>;
      appCard['surface'] = 123;
    },
    'skin references to missing tokens': (package) {
      final skins = package['skins']! as Map<String, Object?>;
      final appCard = skins['appCard']! as Map<String, Object?>;
      appCard['surface'] = 'colors.missing';
    },
  };
  for (final invalidPackage in invalidPackages.entries) {
    test('theme package rejects ${invalidPackage.key}', () async {
      final package = await _bundledPackage();
      invalidPackage.value(package);
      final source = await _sourceFor(package);

      expect(source.load, throwsA(isA<FormatException>()));
    });
  }

  test('theme package accepts future string and numeric tokens', () async {
    final package = await _bundledPackage();
    final tokens = package['tokens']! as Map<String, Object?>;
    tokens['future.fontFamily'] = 'Noto Sans SC';
    tokens['future.density'] = 2;
    final source = await _sourceFor(package);

    final definitions = await source.load();

    expect(definitions.single.tokens['future.fontFamily'], 'Noto Sans SC');
    expect(definitions.single.tokens['future.density'], 2);
  });

  testWidgets('shared widgets render component skin token references',
      (tester) async {
    final definition = _definitionWithSkins({
      'appCard': {
        'surface': 'colors.mintSurface',
        'outline': 'colors.coralBorder',
        'radius': 'radius.xs',
        'shadow': 'shadow.cardColor',
      },
      'appBar': {
        'surface': 'colors.mintSurface',
        'outline': 'colors.coralBorder',
        'height': 'dimensions.primaryButtonHeight',
      },
      'bottomNav': {
        'surface': 'colors.white',
        'outline': 'colors.coralBorder',
        'indicator': 'colors.mintSurface',
        'height': 'dimensions.primaryButtonHeight',
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(definition),
        home: Scaffold(
          appBar: const PreferredSize(
            preferredSize: Size.fromHeight(50),
            child: FitnessAppBar(title: 'Skin test'),
          ),
          body: const AppCard(
            key: ValueKey('skin-card'),
            child: Text('Card'),
          ),
          bottomNavigationBar: BottomNav(
            selectedTabIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    final cardDecoration = tester
        .widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('skin-card')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .decoration as BoxDecoration;
    expect(cardDecoration.color, const Color(0xffdff5ee));
    expect(cardDecoration.borderRadius, BorderRadius.circular(6));

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xffdff5ee));
    expect(appBar.toolbarHeight, 50);

    final navigationBar =
        tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigationBar.backgroundColor, const Color(0xffffffff));
    final indicator = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('bottom-nav-indicator')),
    );
    expect(
      (indicator.decoration as BoxDecoration).color,
      const Color(0xffdff5ee),
    );
    expect(navigationBar.height, 50);
  });

  for (final forbiddenField in ['script', 'executable']) {
    test('theme package rejects $forbiddenField fields', () async {
      final package = await _bundledPackage();
      final skins = package['skins']! as Map<String, Object?>;
      skins[forbiddenField] = 'run arbitrary code';
      final source = await _sourceFor(package);

      expect(
        source.load,
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains(forbiddenField),
          ),
        ),
      );
    });
  }
}

Future<Map<String, Object?>> _bundledPackage() async {
  final json = await rootBundle.loadString(_manifestPath);
  return (jsonDecode(json) as Map<String, dynamic>).cast<String, Object?>();
}

Future<BundledThemePackageSource> _sourceFor(
  Map<String, Object?> package,
) async {
  final schema = await rootBundle.loadString(_schemaPath);
  return BundledThemePackageSource(
    bundle: MemoryAssetBundle({
      _manifestPath: jsonEncode(package),
      _schemaPath: schema,
    }),
  );
}

AppThemeDefinition _definitionWithSkins(
  Map<String, Object?> skins,
) =>
    AppThemeDefinition(
      manifest: breathRhythmDefinition.manifest,
      tokens: breathRhythmDefinition.tokens,
      skins: skins,
    );
