import 'package:flutter/foundation.dart';

import 'theme_id.dart';

@immutable
final class ThemeManifest {
  const ThemeManifest({
    required this.id,
    required this.name,
    required this.schemaVersion,
    required this.version,
  });

  final ThemeId id;
  final String name;
  final int schemaVersion;
  final String version;

  ThemeManifest copyWith({ThemeId? id}) => ThemeManifest(
        id: id ?? this.id,
        name: name,
        schemaVersion: schemaVersion,
        version: version,
      );
}
