import '../../../theme/theme_id.dart';
import '../../exercises/domain/exercise.dart';

enum WeekStart { monday, sunday }

final class AppSettings {
  AppSettings({
    this.defaultUnit = WeightUnit.kg,
    this.defaultRestSeconds = 90,
    this.restReminder = true,
    this.vibration = true,
    this.screenAwake = true,
    this.weekStart = WeekStart.monday,
    this.themeId = const ThemeId('breath-rhythm'),
  }) {
    if (defaultRestSeconds < 0) {
      throw ArgumentError.value(
        defaultRestSeconds,
        'defaultRestSeconds',
        'Must not be negative.',
      );
    }
  }

  final WeightUnit defaultUnit;
  final int defaultRestSeconds;
  final bool restReminder;
  final bool vibration;
  final bool screenAwake;
  final WeekStart weekStart;
  final ThemeId themeId;

  AppSettings copyWith({
    WeightUnit? defaultUnit,
    int? defaultRestSeconds,
    bool? restReminder,
    bool? vibration,
    bool? screenAwake,
    WeekStart? weekStart,
    ThemeId? themeId,
  }) =>
      AppSettings(
        defaultUnit: defaultUnit ?? this.defaultUnit,
        defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
        restReminder: restReminder ?? this.restReminder,
        vibration: vibration ?? this.vibration,
        screenAwake: screenAwake ?? this.screenAwake,
        weekStart: weekStart ?? this.weekStart,
        themeId: themeId ?? this.themeId,
      );
}
