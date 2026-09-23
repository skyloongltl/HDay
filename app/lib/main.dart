import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/router.dart';

void main() {
  runApp(
    ProviderScope(
      child: FitnessCounterApp(router: createRouter()),
    ),
  );
}
