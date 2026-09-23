import 'package:fitness_counter/features/exercises/domain/exercise.dart';
import 'package:fitness_counter/features/settings/domain/app_settings.dart';
import 'package:fitness_counter/theme/theme_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings defaults match the first-release product choices', () {
    final settings = AppSettings();

    expect(settings.defaultUnit, WeightUnit.kg);
    expect(settings.defaultRestSeconds, 90);
    expect(settings.restReminder, isTrue);
    expect(settings.vibration, isTrue);
    expect(settings.screenAwake, isTrue);
    expect(settings.weekStart, WeekStart.monday);
    expect(settings.themeId, const ThemeId('breath-rhythm'));
  });

  test('copyWith returns changed settings without mutating the source', () {
    final settings = AppSettings();

    final changed = settings.copyWith(
      defaultUnit: WeightUnit.lb,
      defaultRestSeconds: 120,
      restReminder: false,
      vibration: false,
      screenAwake: false,
      weekStart: WeekStart.sunday,
      themeId: const ThemeId('future-pack'),
    );

    expect(settings.defaultRestSeconds, 90);
    expect(changed.defaultUnit, WeightUnit.lb);
    expect(changed.defaultRestSeconds, 120);
    expect(changed.restReminder, isFalse);
    expect(changed.vibration, isFalse);
    expect(changed.screenAwake, isFalse);
    expect(changed.weekStart, WeekStart.sunday);
    expect(changed.themeId, const ThemeId('future-pack'));
  });

  test('settings reject negative default rest seconds', () {
    expect(
      () => AppSettings(defaultRestSeconds: -1),
      throwsArgumentError,
    );
  });
}
