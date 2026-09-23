import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../theme/theme_id.dart';
import '../../exercises/domain/exercise.dart';
import '../domain/app_settings.dart';
import 'settings_providers.dart';

final class SettingsState {
  const SettingsState({
    required this.committedSettings,
    this.pendingSettings,
    this.isSaving = false,
    this.failure,
  });

  final AppSettings committedSettings;
  final AppSettings? pendingSettings;
  final bool isSaving;
  final Object? failure;

  WeightUnit get weightUnit => effectiveSettings.defaultUnit;
  int get defaultRest => effectiveSettings.defaultRestSeconds;
  bool get restReminder => effectiveSettings.restReminder;
  bool get vibration => effectiveSettings.vibration;
  bool get screenAwake => effectiveSettings.screenAwake;
  WeekStart get weekStart => effectiveSettings.weekStart;
  ThemeId get selectedTheme => effectiveSettings.themeId;

  /// During a write, controls render the latest intended value. Once a write
  /// fails, committedSettings is rendered again while pendingSettings remains
  /// available for an explicit retry.
  AppSettings get effectiveSettings =>
      isSaving ? (pendingSettings ?? committedSettings) : committedSettings;

  SettingsState copyWith({
    AppSettings? committedSettings,
    Object? pendingSettings = _unset,
    bool? isSaving,
    Object? failure = _unset,
  }) =>
      SettingsState(
        committedSettings: committedSettings ?? this.committedSettings,
        pendingSettings: identical(pendingSettings, _unset)
            ? this.pendingSettings
            : pendingSettings as AppSettings?,
        isSaving: isSaving ?? this.isSaving,
        failure: identical(failure, _unset) ? this.failure : failure,
      );
}

const _unset = Object();

/// Loads committed SQLite settings and keeps failed edits available for retry.
final class SettingsController
    extends StateNotifier<AsyncValue<SettingsState>> {
  SettingsController(this._ref) : super(const AsyncLoading());
  final Ref _ref;
  Future<void> _writeTail = Future<void>.value();

  Future<SettingsState> initialize() async {
    try {
      final value = await _read();
      state = AsyncData(value);
      return value;
    } catch (error, trace) {
      state = AsyncError(error, trace);
      rethrow;
    }
  }

  Future<void> load() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(await _read());
    } catch (error, trace) {
      state = AsyncError(error, trace);
    }
  }

  Future<SettingsState> _read() async {
    final repository = await _ref.read(settingsRepositoryProvider.future);
    final registry = await _ref.read(themeRegistryProvider.future);
    final persisted = await repository.read();
    final resolvedTheme = registry.resolve(persisted.themeId).manifest.id;
    return SettingsState(
      committedSettings: persisted.copyWith(themeId: resolvedTheme),
    );
  }

  Future<bool> update(AppSettings intended) async {
    // Keep writes ordered so rapid switch changes cannot be dropped.
    final result = Completer<bool>();
    _writeTail = _writeTail.catchError((_) {}).then((_) async {
      try {
        result.complete(await _performUpdate(intended));
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<bool> _performUpdate(AppSettings intended) async {
    final current = state.valueOrNull;
    if (current == null) await load();
    final committed = state.valueOrNull;
    if (committed == null) return false;
    final registry = await _ref.read(themeRegistryProvider.future);
    final normalized = intended.copyWith(
      themeId: registry.resolve(intended.themeId).manifest.id,
    );
    state = AsyncData(
      committed.copyWith(
        isSaving: true,
        failure: null,
        pendingSettings: normalized,
      ),
    );
    try {
      final repository = await _ref.read(settingsRepositoryProvider.future);
      await repository.save(normalized);
      state = AsyncData(SettingsState(committedSettings: normalized));
      return true;
    } catch (error) {
      state = AsyncData(
        committed.copyWith(
          isSaving: false,
          failure: error,
          pendingSettings: normalized,
        ),
      );
      return false;
    }
  }

  Future<bool> retry() async {
    final pending = state.valueOrNull?.pendingSettings;
    if (pending == null) return false;
    return update(pending);
  }
}
