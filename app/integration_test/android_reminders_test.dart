import 'dart:io';
import 'package:fitness_counter/core/platform/android_notification_gateway.dart';
import 'package:fitness_counter/core/platform/android_vibration_gateway.dart';
import 'package:fitness_counter/core/platform/android_wake_lock_gateway.dart';
import 'package:fitness_counter/core/platform/rest_effects_channel.dart';
import 'package:fitness_counter/features/settings/domain/app_settings.dart';
import 'package:fitness_counter/features/workout/application/rest_effects_controller.dart';
import 'package:fitness_counter/features/workout/domain/workout_event.dart';
import 'package:fitness_counter/features/workout/domain/workout_machine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/workout_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android receivers deliver independently, cancel and deduplicate recovery',
      (tester) async {
    expect(Platform.isAndroid, isTrue);
    final notification = AndroidNotificationGateway();
    final vibration = AndroidVibrationGateway();
    final permission = await notification.permissionState();
    final hasVibrator = await vibration.hasVibrator();
    // ignore: avoid_print
    print('permissionState notifications=${permission.notificationsGranted} '
        'exact=${permission.exactAlarmsGranted} vibrator=$hasVibrator');
    final now = DateTime.now().toUtc();
    var resting = WorkoutMachine.start(
      id: 'integration-${now.microsecondsSinceEpoch}',
      draft: twoSetDraft(),
      nowUtc: now,
    );
    resting = WorkoutMachine.transition(resting, const StartSet('s1'), now);
    resting = WorkoutMachine.transition(
      resting,
      const CompleteSet('s1', actualWeight: 20, actualReps: 8),
      now,
    ).copyWith(restTargetSeconds: 0);
    final restId = '${resting.id}${resting.restStartedAt!.toIso8601String()}';
    Future<void> schedule(String id, DateTime due) async {
      if (permission.notificationsGranted) {
        await notification.scheduleRest(
          sessionId: 'integration-session',
          restId: id,
          dueAtUtc: due,
        );
      }
      if (hasVibrator) {
        await vibration.scheduleRest(
          sessionId: 'integration-session',
          restId: id,
          dueAtUtc: due,
        );
      }
    }

    final cancelledId = 'cancelled-$restId';
    await schedule(
      cancelledId,
      DateTime.now().toUtc().add(const Duration(seconds: 3)),
    );
    await notification.cancelRest(cancelledId);
    if (hasVibrator) {
      expect(
        (await _state(cancelledId))['vibrationActive'],
        isTrue,
        reason:
            'Notification cancellation must not cancel independent vibration',
      );
    }
    await vibration.cancelRest(cancelledId);
    await Future<void>.delayed(const Duration(seconds: 5));
    final cancelled = await _state(cancelledId);
    expect(cancelled['notificationActive'], isFalse);
    expect(cancelled['vibrationActive'], isFalse);
    expect(cancelled['notificationDelivered'], isFalse);
    expect(cancelled['vibrationDelivered'], isFalse);

    final background = const bool.fromEnvironment('BACKGROUND_PROBE');
    await schedule(
      restId,
      DateTime.now().toUtc().add(Duration(seconds: background ? 20 : 2)),
    );
    if (background) {
      // ignore: avoid_print
      print('BACKGROUND_READY');
    }
    // Exact mode has a bounded prompt-delivery assertion. The denied path only
    // observes delivery, without imposing an exact deadline on inexact alarms.
    final deadline = DateTime.now()
        .add(Duration(seconds: permission.exactAlarmsGranted ? 40 : 75));
    var delivery = await _state(restId);
    bool delivered() =>
        (!permission.notificationsGranted ||
            delivery['notificationDelivered'] == true) &&
        (!hasVibrator || delivery['vibrationDelivered'] == true);
    while (!delivered() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      delivery = await _state(restId);
    }
    // ignore: avoid_print
    print(
      'receiverState mode=${permission.exactAlarmsGranted ? 'exact' : 'inexact'} $delivery',
    );
    if (permission.exactAlarmsGranted) {
      expect(delivered(), isTrue);
    } else {
      expect(
        delivery['vibrationActive'] == true ||
            delivery['vibrationDelivered'] == true,
        hasVibrator,
      );
    }
    if (delivered()) {
      final restored = RestEffectsController(
        notificationGateway: AndroidNotificationGateway(),
        vibrationGateway: AndroidVibrationGateway(),
        wakeLockGateway: AndroidWakeLockGateway(),
      );
      await restored.reconcile(resting, AppSettings(screenAwake: false));
      final recovered = await _state(restId);
      expect(recovered['notificationActive'], isFalse);
      expect(recovered['vibrationActive'], isFalse);
      // ignore: avoid_print
      print('RECOVERY_NOT_REARMED $recovered');
      await restored.dispose();
    }
    await notification.cancelRest(restId);
    await vibration.cancelRest(restId);
  });
}

Future<Map<String, dynamic>> _state(String restId) async =>
    (await RestEffectsChannel.methodChannel.invokeMapMethod<String, dynamic>(
      'debugDeliveryState',
      {RestEffectsChannel.restId: restId},
    ))!;
