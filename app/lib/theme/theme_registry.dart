import 'app_theme_definition.dart';
import 'theme_id.dart';

const breathRhythmThemeId = ThemeId('breath-rhythm');

final class ThemeRegistry {
  ThemeRegistry(Iterable<AppThemeDefinition> definitions) {
    final byId = <ThemeId, AppThemeDefinition>{};
    for (final definition in definitions) {
      final id = definition.manifest.id;
      if (byId.containsKey(id)) {
        throw FormatException('Duplicate theme id: ${id.value}');
      }
      byId[id] = definition;
    }
    final fallback = byId[breathRhythmThemeId];
    if (fallback == null) {
      throw const FormatException(
        'Theme registry requires the breath-rhythm fallback.',
      );
    }
    _byId = Map.unmodifiable(byId);
    _available = List.unmodifiable(byId.values);
    _fallback = fallback;
  }

  late final Map<ThemeId, AppThemeDefinition> _byId;
  late final List<AppThemeDefinition> _available;
  late final AppThemeDefinition _fallback;

  List<AppThemeDefinition> get available => _available;

  AppThemeDefinition resolve(ThemeId? id) => _byId[id] ?? _fallback;
}
