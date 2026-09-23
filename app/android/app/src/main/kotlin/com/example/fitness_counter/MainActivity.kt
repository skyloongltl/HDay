package com.example.fitness_counter

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RestEffects.CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "permissionState" -> result.success(mapOf(
                        RestEffects.ARG_NOTIFICATIONS_GRANTED to notificationsGranted(),
                        RestEffects.ARG_EXACT_ALARMS_GRANTED to exactAlarmsGranted(),
                    ))
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2401)
                        result.success(null)
                    }
                    "requestExactAlarmPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
                        result.success(null)
                    }
                    "hasVibrator" -> result.success(vibrator().hasVibrator())
                    "debugDeliveryState" -> {
                        val restId = call.argument<String>(RestEffects.ARG_REST_ID) ?: throw IllegalArgumentException("Missing restId")
                        result.success(RestEffects.deliveryState(this, restId))
                    }
                    "pulseVibration" -> { pulse(); result.success(null) }
                    "setWakeLockEnabled" -> {
                        if (call.argument<Boolean>(RestEffects.ARG_ENABLED) == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    "scheduleNotificationRest" -> { schedule(call, RestEffects.ACTION_NOTIFY); result.success(null) }
                    "scheduleVibrationRest" -> { schedule(call, RestEffects.ACTION_VIBRATE); result.success(null) }
                    "cancelNotificationRest" -> { cancel(call, RestEffects.ACTION_NOTIFY); result.success(null) }
                    "cancelVibrationRest" -> { cancel(call, RestEffects.ACTION_VIBRATE); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error("rest_effects", error.message, null)
            }
        }
    }

    private fun schedule(call: MethodCall, action: String) {
        val sessionId = call.argument<String>(RestEffects.ARG_SESSION_ID) ?: throw IllegalArgumentException("Missing sessionId")
        val restId = call.argument<String>(RestEffects.ARG_REST_ID) ?: throw IllegalArgumentException("Missing restId")
        val dueAt = call.argument<Long>(RestEffects.ARG_DUE_AT_UTC_MILLIS) ?: throw IllegalArgumentException("Missing dueAtUtcMillis")
        RestEffects.schedule(this, action, sessionId, restId, dueAt)
    }

    private fun cancel(call: MethodCall, action: String) {
        val restId = call.argument<String>(RestEffects.ARG_REST_ID) ?: throw IllegalArgumentException("Missing restId")
        RestEffects.cancel(this, action, restId)
    }

    private fun notificationsGranted(): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    } else {
        NotificationManagerCompat.from(this).areNotificationsEnabled()
    }

    private fun exactAlarmsGranted(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
        getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    private fun vibrator(): Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) getSystemService(VibratorManager::class.java).defaultVibrator else {
        @Suppress("DEPRECATION") getSystemService(VIBRATOR_SERVICE) as Vibrator
    }

    private fun pulse() {
        val vibrator = vibrator()
        if (vibrator.hasVibrator()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION") vibrator.vibrate(100)
            }
        }
    }
}
