import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/application/settings_providers.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../theme/breath_rhythm.dart';
import '../theme/fitness_theme_extension.dart';
import 'providers.dart';

final class FitnessCounterApp extends ConsumerWidget {
  const FitnessCounterApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(themeRegistryProvider);
    return registry.when(
      data: (registry) {
        final settings = ref.watch(settingsControllerProvider);
        final definition = registry.resolve(
          settings.valueOrNull?.selectedTheme,
        );
        final theme = AppTheme.build(definition);
        final fitness = theme.extension<FitnessThemeExtension>()!;
        return MaterialApp.router(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: theme,
          themeAnimationDuration: fitness.motion.standard,
          themeAnimationCurve: fitness.motion.curve,
          builder: _systemUiBuilder,
          routerConfig: router,
        );
      },
      loading: () => _statusApp(
        child: const _ThemeLoadingScreen(),
      ),
      error: (error, stackTrace) => _statusApp(
        child: _ThemeLoadErrorScreen(
          onRetry: () {
            ref.invalidate(themeDefinitionsProvider);
            ref.invalidate(themeRegistryProvider);
            unawaited(() async {
              try {
                await ref.read(themeRegistryProvider.future);
                await ref.read(settingsControllerProvider.notifier).load();
              } on Object {
                // The rendered error state exposes the next retry.
              }
            }());
          },
        ),
      ),
    );
  }

  MaterialApp _statusApp({required Widget child}) => MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(breathRhythmDefinition),
        builder: _systemUiBuilder,
        home: child,
      );

  static Widget _systemUiBuilder(BuildContext context, Widget? child) {
    final theme = AppTheme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('app-system-ui'),
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
      ),
      child: ColoredBox(
        key: const ValueKey('app-system-bar-background'),
        color: theme.colors.surface,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

final class _ThemeLoadingScreen extends StatelessWidget {
  const _ThemeLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                // Spacer: spacing.16 -> SizedBox(height: spacing.16)
                SizedBox(height: theme.spacing.s16),
                Text(AppStrings.themeLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ThemeLoadErrorScreen extends StatelessWidget {
  const _ThemeLoadErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: theme.dimensions.emptyIconSize,
                  color: theme.colors.danger,
                ),
                // Spacer: spacing.12 -> SizedBox(height: spacing.12)
                SizedBox(height: theme.spacing.s12),
                Text(
                  AppStrings.themeLoadFailed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                // Spacer: spacing.6 -> SizedBox(height: spacing.6)
                SizedBox(height: theme.spacing.s6),
                Text(
                  AppStrings.themeLoadFailedHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                // Spacer: spacing.20 -> SizedBox(height: spacing.20)
                SizedBox(height: theme.spacing.s20),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text(AppStrings.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
