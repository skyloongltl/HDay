import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_strings.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_theme_definition.dart';
import '../../../theme/theme_id.dart';
import '../../../theme/theme_registry.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/app_card.dart';
import '../../exercises/application/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../history/application/history_providers.dart';
import '../../plans/application/plan_providers.dart';
import '../../today/application/today_providers.dart';
import '../../workout/application/rest_effects_controller.dart';
import '../../workout/application/workout_providers.dart';
import '../application/settings_controller.dart';
import '../application/settings_providers.dart';
import '../domain/app_settings.dart';

// PAGE: SettingsScreen
// ROUTE: /settings
// FLUTTER WIDGETS: Scaffold, AppBar, ListView, SwitchListTile, RadioListTile, Card
// STATE: weightUnit, defaultRest, restReminder, vibration, screenAwake, weekStart, selectedTheme
// ANIMATIONS: switch slide 200ms easeOut; theme selection 200ms easeOut
// NAVIGATION: back -> caller Home route; setting rows open in-page choices
final class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

final class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _actionTail = Future<void>.value();
  bool _isSeeding = false;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final settings = ref.watch(settingsControllerProvider);
    final effects = ref.watch(restEffectsStatusProvider);
    return SafeArea(
      child: Scaffold(
        key: const ValueKey('settings-screen'),
        backgroundColor: theme.page,
        appBar: AppBar(
          centerTitle: true,
          leading: CircularBackButton(onPressed: context.pop),
          actions: [SizedBox(width: theme.minTapTarget)],
          title: const Text(AppStrings.settings),
        ),
        body: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(
            onRetry: () => ref.read(settingsControllerProvider.notifier).load(),
          ),
          data: (value) => _SettingsList(
            state: value,
            effects: effects,
            onUpdate: _update,
            onPermission: _requestPermission,
            isSeeding: _isSeeding,
            onSeedTestData: _seedTestData,
            onRetry: value.pendingSettings == null
                ? null
                : () => ref.read(settingsControllerProvider.notifier).retry(),
          ),
        ),
      ),
    );
  }

  Future<bool> _update(AppSettings settings) async {
    final result = Completer<bool>();
    _actionTail = _actionTail.then((_) async {
      final saved =
          await ref.read(settingsControllerProvider.notifier).update(settings);
      // Every settings action reconciles committed rest effects; a failed
      // write therefore cannot leave a stale native schedule behind.
      await ref.read(workoutControllerProvider.notifier).refreshRestEffects();
      if (saved) {
        ref.invalidate(historyControllerProvider);
        ref.invalidate(todayOverviewProvider);
      }
      result.complete(saved);
    });
    return result.future;
  }

  Future<void> _requestPermission(bool exact) async {
    final effects = ref.read(restEffectsControllerProvider);
    Object? failure;
    try {
      if (exact) {
        await effects.requestExactAlarmPermission();
      } else {
        await effects.requestNotificationPermission();
      }
    } on Object catch (error) {
      failure = error;
    } finally {
      await ref.read(workoutControllerProvider.notifier).refreshRestEffects();
    }
    if (failure != null) {
      effects.status.value = effects.status.value.copyWith(hasFailure: true);
    }
  }

  Future<void> _seedTestData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.seedTestDataTitle),
        content: const Text(AppStrings.seedTestDataConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-seed-test-data'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.seedTestDataConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSeeding = true);
    String message;
    try {
      final seeder = await ref.read(testDataSeederProvider.future);
      final result = await seeder.seed();
      ref.invalidate(exerciseControllerProvider);
      ref.invalidate(exercisePickerControllerProvider);
      ref.invalidate(planControllerProvider);
      ref.invalidate(historyControllerProvider);
      ref.invalidate(recentHistoryProvider);
      ref.invalidate(todayOverviewProvider);
      message = result.historySkippedForActiveWorkout
          ? AppStrings.seedTestDataActiveWorkout
          : result.totalAdded == 0
              ? AppStrings.seedTestDataNoChanges
              : AppStrings.seedTestDataComplete;
    } on Object {
      message = AppStrings.seedTestDataFailed;
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

final class _SettingsList extends StatelessWidget {
  const _SettingsList({
    required this.state,
    required this.effects,
    required this.onUpdate,
    required this.onPermission,
    required this.isSeeding,
    required this.onSeedTestData,
    required this.onRetry,
  });

  final SettingsState state;
  final RestEffectsStatus effects;
  final Future<bool> Function(AppSettings) onUpdate;
  final Future<void> Function(bool exact) onPermission;
  final bool isSeeding;
  final Future<void> Function() onSeedTestData;
  final Future<bool> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return ListView(
      key: const ValueKey('settings-list'),
      padding: EdgeInsets.all(theme.spacing.s16),
      children: [
        if (state.failure != null) ...[
          _FailureBanner(onRetry: onRetry),
          SizedBox(height: theme.spacing.s12),
        ],
        _Section(
          title: AppStrings.trainingPreferences,
          children: [
            _ValueTile(
              key: const ValueKey('setting-weight-unit'),
              label: AppStrings.defaultWeightUnit,
              value: state.weightUnit.code.toUpperCase(),
              onTap: () => _chooseUnit(context),
            ),
            const _Rule(),
            _ValueTile(
              key: const ValueKey('setting-default-rest'),
              label: AppStrings.defaultRestDuration,
              value: AppStrings.defaultRestValue(state.defaultRest),
              onTap: () => _chooseRest(context),
            ),
          ],
        ),
        _Section(
          title: AppStrings.trainingExperience,
          children: [
            _SwitchTile(
              key: const ValueKey('setting-rest-reminder'),
              label: AppStrings.restReminder,
              value: state.restReminder,
              onChanged: (value) => onUpdate(
                state.effectiveSettings.copyWith(restReminder: value),
              ),
            ),
            const _Rule(),
            _SwitchTile(
              key: const ValueKey('setting-vibration'),
              label: AppStrings.vibrationFeedback,
              value: state.vibration,
              onChanged: (value) => onUpdate(
                state.effectiveSettings.copyWith(vibration: value),
              ),
            ),
            const _Rule(),
            _SwitchTile(
              key: const ValueKey('setting-screen-awake'),
              label: AppStrings.screenAwake,
              value: state.screenAwake,
              onChanged: (value) => onUpdate(
                state.effectiveSettings.copyWith(screenAwake: value),
              ),
            ),
          ],
        ),
        _PermissionSection(status: effects, onPermission: onPermission),
        _Section(
          title: AppStrings.calendarSettings,
          children: [
            _ValueTile(
              key: const ValueKey('setting-week-start'),
              label: AppStrings.weekStart,
              value: state.weekStart == WeekStart.monday
                  ? AppStrings.monday
                  : AppStrings.sunday,
              onTap: () => _chooseWeekStart(context),
            ),
          ],
        ),
        _ThemeSection(
          selected: state.selectedTheme,
          onSelected: (id) => onUpdate(
            state.effectiveSettings.copyWith(themeId: id),
          ),
        ),
        _Section(
          title: AppStrings.developerTools,
          children: [
            ListTile(
              key: const ValueKey('seed-test-data'),
              enabled: !isSeeding,
              leading: isSeeding
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined),
              title: Text(
                isSeeding
                    ? AppStrings.seedTestDataRunning
                    : AppStrings.seedTestData,
              ),
              subtitle: const Text(AppStrings.seedTestDataHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: isSeeding ? null : onSeedTestData,
            ),
          ],
        ),
        _Section(
          title: AppStrings.about,
          children: const [
            _ValueTile(
              label: AppStrings.version,
              value: AppStrings.versionValue,
            ),
            _Rule(),
            _ValueTile(label: AppStrings.privacyPolicy, showChevron: true),
            _Rule(),
            _ValueTile(label: AppStrings.userAgreement, showChevron: true),
          ],
        ),
        // Spacer: spacing.32 -> SizedBox(height: spacing.32)
        SizedBox(height: theme.spacing.s32),
      ],
    );
  }

  Future<void> _chooseUnit(BuildContext context) async {
    final chosen = await showModalBottomSheet<WeightUnit>(
      context: context,
      builder: (_) => _ChoiceSheet<WeightUnit>(
        title: AppStrings.defaultWeightUnit,
        value: state.weightUnit,
        options: const [WeightUnit.kg, WeightUnit.lb, WeightUnit.none],
        label: (value) => value.code.toUpperCase(),
      ),
    );
    if (chosen != null) {
      await onUpdate(state.effectiveSettings.copyWith(defaultUnit: chosen));
    }
  }

  Future<void> _chooseRest(BuildContext context) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => _ChoiceSheet<int>(
        title: AppStrings.defaultRestDuration,
        value: state.defaultRest,
        options: const [0, 30, 60, 90, 120],
        label: AppStrings.defaultRestValue,
      ),
    );
    if (chosen != null) {
      await onUpdate(
        state.effectiveSettings.copyWith(defaultRestSeconds: chosen),
      );
    }
  }

  Future<void> _chooseWeekStart(BuildContext context) async {
    final chosen = await showModalBottomSheet<WeekStart>(
      context: context,
      builder: (_) => _ChoiceSheet<WeekStart>(
        title: AppStrings.weekStart,
        value: state.weekStart,
        options: WeekStart.values,
        label: (value) =>
            value == WeekStart.monday ? AppStrings.monday : AppStrings.sunday,
      ),
    );
    if (chosen != null) {
      await onUpdate(state.effectiveSettings.copyWith(weekStart: chosen));
    }
  }
}

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: theme.spacing.s6),
            child: Text(title, style: Theme.of(context).textTheme.labelMedium),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(theme.appCard.radius),
              clipBehavior: Clip.antiAlias,
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ValueTile extends StatelessWidget {
  const _ValueTile({
    required this.label,
    this.value,
    this.onTap,
    this.showChevron = false,
    super.key,
  });
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool showChevron;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return ListTile(
      minVerticalPadding: theme.spacing.s12,
      onTap: onTap,
      title: Text(label),
      trailing: value == null && !showChevron
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  Text(value!, style: Theme.of(context).textTheme.bodyMedium),
                if (showChevron || onTap != null) ...[
                  SizedBox(width: theme.spacing.s4),
                  Icon(Icons.chevron_right, size: theme.typography.lg),
                ],
              ],
            ),
    );
  }
}

final class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
        contentPadding:
            EdgeInsets.symmetric(horizontal: AppTheme.of(context).spacing.s16),
      );
}

final class _Rule extends StatelessWidget {
  const _Rule();
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Divider(
      height: theme.borders.thin,
      indent: theme.spacing.s16,
      endIndent: theme.spacing.s16,
    );
  }
}

final class _PermissionSection extends StatelessWidget {
  const _PermissionSection({required this.status, required this.onPermission});
  final RestEffectsStatus status;
  final Future<void> Function(bool exact) onPermission;
  @override
  Widget build(BuildContext context) {
    final permission = status.permission;
    final unavailable = permission == null;
    final notificationGranted = permission?.notificationsGranted == true;
    final exactGranted = permission?.exactAlarmsGranted == true;
    final theme = AppTheme.of(context);
    final statusTitle = status.hasFailure
        ? AppStrings.permissionActionFailed
        : unavailable
            ? AppStrings.permissionUnavailable
            : null;
    return _Section(
      title: AppStrings.restReminder,
      children: [
        ListTile(
          key: const ValueKey('permission-notification-status'),
          title: Text(
            statusTitle ??
                (notificationGranted
                    ? AppStrings.notificationPermissionGranted
                    : AppStrings.notificationPermissionDenied),
          ),
          trailing: unavailable
              ? const Text(AppStrings.permissionRefreshing)
              : status.hasFailure
                  ? TextButton(
                      key: const ValueKey('request-notification-permission'),
                      onPressed: () => onPermission(false),
                      child: const Text(AppStrings.retryPermission),
                    )
                  : notificationGranted
                      ? Icon(Icons.check_circle, color: theme.colors.mintText)
                      : TextButton(
                          key:
                              const ValueKey('request-notification-permission'),
                          onPressed: () => onPermission(false),
                          child: const Text(
                            AppStrings.requestNotificationPermission,
                          ),
                        ),
        ),
        const _Rule(),
        ListTile(
          title: Text(
            unavailable
                ? AppStrings.permissionUnavailable
                : exactGranted
                    ? AppStrings.exactAlarmGranted
                    : AppStrings.exactAlarmDenied,
          ),
          trailing: unavailable
              ? TextButton(
                  onPressed: () => onPermission(true),
                  child: const Text(AppStrings.retryPermission),
                )
              : status.hasFailure
                  ? TextButton(
                      key: const ValueKey('request-exact-alarm-permission'),
                      onPressed: () => onPermission(true),
                      child: const Text(AppStrings.retryPermission),
                    )
                  : exactGranted
                      ? Icon(Icons.check_circle, color: theme.colors.mintText)
                      : TextButton(
                          key: const ValueKey('request-exact-alarm-permission'),
                          onPressed: () => onPermission(true),
                          child: const Text(
                            AppStrings.requestExactAlarmPermission,
                          ),
                        ),
        ),
        if (status.isTimingDegraded)
          ListTile(
            title: const Text(AppStrings.permissionTimingDegraded),
            leading: Icon(Icons.warning_amber, color: theme.colors.danger),
          ),
      ],
    );
  }
}

final class _ThemeSection extends ConsumerWidget {
  const _ThemeSection({required this.selected, required this.onSelected});
  final ThemeId selected;
  final ValueChanged<ThemeId> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(themeRegistryProvider).valueOrNull;
    final definitions = registry?.available ?? const <AppThemeDefinition>[];
    final theme = AppTheme.of(context);
    return _Section(
      title: AppStrings.appearance,
      children: [
        ListTile(title: Text(AppStrings.chooseTheme)),
        RadioGroup<ThemeId>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
          child: Column(
            children: [
              for (final definition in definitions)
                _ThemeTile(
                  definition: definition,
                  selected: definition.manifest.id == selected,
                  onTap: () => onSelected(definition.manifest.id),
                ),
            ],
          ),
        ),
        if (definitions.isEmpty)
          Padding(
            padding: EdgeInsets.all(theme.spacing.s16),
            child: Text(AppStrings.themeLoadFailed),
          ),
      ],
    );
  }
}

final class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.definition,
    required this.selected,
    required this.onTap,
  });
  final AppThemeDefinition definition;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final border = selected ? theme.primaryAction : theme.colors.outline;
    const previewKeys = <String>[
      'colors.deepBlue',
      'colors.coral',
      'colors.mint',
      'colors.fogBg',
    ];
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('theme-option-${definition.manifest.id.value}'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: theme.motion.standard,
          curve: theme.motion.curve,
          margin: EdgeInsets.symmetric(
            horizontal: theme.spacing.s16,
            vertical: theme.spacing.s4,
          ),
          padding: EdgeInsets.all(theme.spacing.s12),
          decoration: BoxDecoration(
            border: Border.all(
              color: border,
              width: selected ? theme.borders.strong : theme.borders.thin,
            ),
            borderRadius: BorderRadius.circular(theme.radii.md),
          ),
          child: Row(
            children: [
              for (final key in previewKeys)
                Padding(
                  padding: EdgeInsets.only(right: theme.spacing.s4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.colorToken(definition, key),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colors.outline),
                    ),
                    child: SizedBox.square(dimension: theme.spacing.s16),
                  ),
                ),
              SizedBox(width: theme.spacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            definition.manifest.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (definition.manifest.id == breathRhythmThemeId)
                          Text(
                            AppStrings.builtInTheme,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                      ],
                    ),
                    Text(
                      AppStrings.themeVersion(definition.manifest.version),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              Radio<ThemeId>(
                key: selected
                    ? ValueKey(
                        'theme-selected-${definition.manifest.id.value}',
                      )
                    : null,
                value: definition.manifest.id,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.value,
    required this.options,
    required this.label,
  });
  final String title;
  final T value;
  final List<T> options;
  final String Function(T) label;
  @override
  Widget build(BuildContext context) => SafeArea(
        child: RadioGroup<T>(
          groupValue: value,
          onChanged: (selected) => Navigator.pop(context, selected),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(AppTheme.of(context).spacing.s16),
                child:
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final option in options)
                RadioListTile<T>(
                  value: option,
                  title: Text(label(option)),
                ),
            ],
          ),
        ),
      );
}

final class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.onRetry});
  final Future<bool> Function()? onRetry;
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AppCard(
      color: theme.colors.dangerSurface,
      child: Row(
        children: [
          Expanded(child: Text(AppStrings.settingsSaveFailed)),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text(AppStrings.settingsRetry),
            ),
        ],
      ),
    );
  }
}

final class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: ElevatedButton(
          onPressed: onRetry,
          child: const Text(AppStrings.retry),
        ),
      );
}
