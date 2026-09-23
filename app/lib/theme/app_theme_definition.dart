import 'package:flutter/foundation.dart';

import 'theme_id.dart';
import 'theme_manifest.dart';

@immutable
final class AppThemeDefinition {
  AppThemeDefinition({
    required this.manifest,
    required Map<String, Object?> tokens,
    required Map<String, Object?> skins,
  })  : tokens = Map.unmodifiable(tokens),
        skins = Map.unmodifiable(skins);

  final ThemeManifest manifest;
  final Map<String, Object?> tokens;
  final Map<String, Object?> skins;

  AppThemeDefinition copyWith({ThemeId? id}) => AppThemeDefinition(
        manifest: manifest.copyWith(id: id),
        tokens: tokens,
        skins: skins,
      );
}
