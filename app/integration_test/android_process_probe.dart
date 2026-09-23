// Test-only entry point: the host installs/launches this without a Flutter
// runner, whose cleanup would otherwise force-stop the app and cancel alarms.
import 'package:fitness_counter/core/platform/android_notification_gateway.dart';
import 'package:fitness_counter/core/platform/android_vibration_gateway.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notification = AndroidNotificationGateway();
  final vibration = AndroidVibrationGateway();
  final permission = await notification.permissionState();
  final restId = 'process-${DateTime.now().microsecondsSinceEpoch}';
  final due = DateTime.now().toUtc().add(const Duration(seconds: 30));
  for (final id in ['cancelled-$restId', restId]) {
    if (permission.notificationsGranted) {
      await notification.scheduleRest(
        sessionId: 'process-probe',
        restId: id,
        dueAtUtc: due,
      );
    }
    await vibration.scheduleRest(
      sessionId: 'process-probe',
      restId: id,
      dueAtUtc: due,
    );
    if (id.startsWith('cancelled-')) {
      await notification.cancelRest(id);
      await vibration.cancelRest(id);
    }
  }
  // ignore: avoid_print
  print(
    'PROCESS_PROBE_READY $restId notifications=${permission.notificationsGranted} exact=${permission.exactAlarmsGranted}',
  );
}
