import 'dart:convert';

import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_theme_definition.dart';
import '../../theme/theme_id.dart';
import '../../theme/theme_manifest.dart';

const bundledThemeManifestPath = 'assets/themes/breath-rhythm/manifest.json';
const bundledThemeSchemaPath = 'assets/themes/theme-package.schema.json';
const supportedThemeSchemaVersion = 1;

abstract interface class ThemePackageSource {
  Future<List<AppThemeDefinition>> load();
}

final class BundledThemePackageSource implements ThemePackageSource {
  const BundledThemePackageSource({
    AssetBundle? bundle,
    this.packageAssetPaths = const [bundledThemeManifestPath],
    this.schemaAssetPath = bundledThemeSchemaPath,
  }) : _bundle = bundle;

  final AssetBundle? _bundle;
  final List<String> packageAssetPaths;
  final String schemaAssetPath;

  AssetBundle get _assets => _bundle ?? rootBundle;

  @override
  Future<List<AppThemeDefinition>> load() async {
    final schema = _decodeObject(
      await _assets.loadString(schemaAssetPath),
      schemaAssetPath,
    );
    final definitions = <AppThemeDefinition>[];
    for (final path in packageAssetPaths) {
      final package = _decodeObject(await _assets.loadString(path), path);
      definitions.add(_parsePackage(package, schema, path));
    }
    return List.unmodifiable(definitions);
  }

  AppThemeDefinition _parsePackage(
    Map<String, Object?> package,
    Map<String, Object?> schema,
    String path,
  ) {
    final forbidden = _stringList(
      schema['x-forbiddenFields'],
      'schema.x-forbiddenFields',
    ).map((field) => field.toLowerCase()).toSet();
    _rejectForbidden(package, forbidden, path);
    _validateAgainstSchema(package, schema, path);

    final manifest = _object(package['manifest'], '$path.manifest');
    final tokens = _object(package['tokens'], '$path.tokens');
    final skins = _object(package['skins'], '$path.skins');
    _validateSemanticTokenTypes(tokens, path);
    _validateSkinReferences(skins, tokens, path);

    final id = _requiredString(manifest, 'id', '$path.manifest');
    final name = _requiredString(manifest, 'name', '$path.manifest');
    final version = _requiredString(manifest, 'version', '$path.manifest');
    final schemaVersion = manifest['schemaVersion'];
    if (schemaVersion is! int) {
      throw FormatException('$path.manifest.schemaVersion must be an integer.');
    }
    if (schemaVersion != supportedThemeSchemaVersion) {
      throw FormatException(
        '$path.manifest.schemaVersion $schemaVersion is not supported.',
      );
    }

    final definition = AppThemeDefinition(
      manifest: ThemeManifest(
        id: ThemeId(id),
        name: name,
        schemaVersion: schemaVersion,
        version: version,
      ),
      tokens: tokens,
      skins: skins,
    );
    AppTheme.build(definition);
    return definition;
  }

  static void _validateAgainstSchema(
    Object? value,
    Map<String, Object?> schema,
    String path,
  ) {
    final types = switch (schema['type']) {
      final String type => [type],
      final List<Object?> typeList => typeList.cast<String>(),
      _ => const <String>[],
    };
    if (types.isNotEmpty && !types.any((type) => _matchesType(value, type))) {
      throw FormatException('$path must have type ${types.join(' or ')}.');
    }
    if (schema.containsKey('const') && value != schema['const']) {
      throw FormatException('$path must equal ${schema['const']}.');
    }

    if (value is String) {
      final minLength = schema['minLength'];
      if (minLength is int && value.length < minLength) {
        throw FormatException('$path must not be empty.');
      }
    }
    if (value is! Map<String, dynamic>) {
      return;
    }

    final object = value.cast<String, Object?>();
    if (schema['required'] case final Object required) {
      for (final key in _stringList(required, '$path schema.required')) {
        if (!object.containsKey(key)) {
          throw FormatException('$path is missing required property $key.');
        }
      }
    }
    final properties = schema['properties'] == null
        ? const <String, Object?>{}
        : _object(schema['properties'], '$path schema.properties');
    final additionalProperties = schema['additionalProperties'];
    for (final entry in object.entries) {
      final propertySchema = properties[entry.key];
      if (propertySchema != null) {
        _validateAgainstSchema(
          entry.value,
          _object(propertySchema, '$path schema.properties.${entry.key}'),
          '$path.${entry.key}',
        );
      } else if (additionalProperties == false) {
        throw FormatException('$path contains unknown property ${entry.key}.');
      } else if (additionalProperties is Map<String, dynamic>) {
        _validateAgainstSchema(
          entry.value,
          additionalProperties.cast<String, Object?>(),
          '$path.${entry.key}',
        );
      }
    }
  }

  static bool _matchesType(Object? value, String type) => switch (type) {
        'object' => value is Map<String, dynamic>,
        'array' => value is List<Object?>,
        'string' => value is String,
        'number' => value is num,
        'integer' => value is int,
        'boolean' => value is bool,
        'null' => value == null,
        _ => throw FormatException('Unsupported schema type $type.'),
      };

  static void _validateSemanticTokenTypes(
    Map<String, Object?> tokens,
    String path,
  ) {
    for (final entry in tokens.entries) {
      final expectsString = entry.key.startsWith('colors.') ||
          entry.key == 'shadow.cardColor' ||
          entry.key == 'animation.curve';
      final expectsNumber = entry.key.startsWith('radius.') ||
          entry.key.startsWith('fontSize.') ||
          entry.key.startsWith('fontWeight.') ||
          entry.key.startsWith('spacing.') ||
          entry.key.startsWith('border.') ||
          entry.key.startsWith('dimensions.') ||
          entry.key.startsWith('opacity.') ||
          entry.key == 'minTap.target' ||
          entry.key == 'animation.fastMs' ||
          entry.key == 'animation.standardMs' ||
          entry.key == 'animation.routeMs' ||
          entry.key == 'shadow.cardBlur' ||
          entry.key == 'shadow.cardOffsetY';
      if (expectsString && entry.value is! String) {
        throw FormatException('$path.tokens.${entry.key} must be a string.');
      }
      if (expectsNumber && entry.value is! num) {
        throw FormatException('$path.tokens.${entry.key} must be numeric.');
      }
    }
  }

  static void _validateSkinReferences(
    Map<String, Object?> skins,
    Map<String, Object?> tokens,
    String path,
  ) {
    for (final skinEntry in skins.entries) {
      final skin = _object(skinEntry.value, '$path.skins.${skinEntry.key}');
      for (final property in skin.entries) {
        final reference = property.value;
        if (reference is! String || !tokens.containsKey(reference)) {
          throw FormatException(
            '$path.skins.${skinEntry.key}.${property.key} must reference '
            'an existing token.',
          );
        }
      }
    }
  }

  static Map<String, Object?> _decodeObject(String source, String path) {
    try {
      return _object(jsonDecode(source), path);
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Unable to parse $path: $error');
    }
  }

  static Map<String, Object?> _object(Object? value, String path) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$path must be a JSON object.');
    }
    return value.cast<String, Object?>();
  }

  static List<String> _stringList(Object? value, String path) {
    if (value is! List<Object?> || value.any((item) => item is! String)) {
      throw FormatException('$path must be a string array.');
    }
    return value.cast<String>();
  }

  static String _requiredString(
    Map<String, Object?> object,
    String key,
    String path,
  ) {
    final value = object[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$path.$key must be a non-empty string.');
    }
    return value;
  }

  static void _rejectForbidden(
    Object? value,
    Set<String> forbidden,
    String path,
  ) {
    if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        if (forbidden.contains(entry.key.toLowerCase())) {
          throw FormatException('$path contains forbidden field ${entry.key}.');
        }
        _rejectForbidden(entry.value, forbidden, '$path.${entry.key}');
      }
      return;
    }
    if (value is List<Object?>) {
      for (var index = 0; index < value.length; index += 1) {
        _rejectForbidden(value[index], forbidden, '$path[$index]');
      }
    }
  }
}
