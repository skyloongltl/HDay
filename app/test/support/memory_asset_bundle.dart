import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class MemoryAssetBundle extends CachingAssetBundle {
  MemoryAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) {
      throw FlutterError('Missing test asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
