package com.example.fitness_counter

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowAlarmManager

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 25, 30, 33])
class RestEffectsTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    @Test fun modernExactAuthorizationControlsTheActualAlarmWindow() {
        if (Build.VERSION.SDK_INT < 31) return
        val alarm = shadowOf(context.getSystemService(AlarmManager::class.java))
        ShadowAlarmManager.setCanScheduleExactAlarms(false)
        RestEffects.schedule(context, RestEffects.ACTION_VIBRATE, "session", "denied", 2000)
        assertEquals(-1L, alarm.nextScheduledAlarm!!.windowLengthMs)
        ShadowAlarmManager.setCanScheduleExactAlarms(true)
        RestEffects.schedule(context, RestEffects.ACTION_VIBRATE, "session", "granted", 2000)
        assertEquals(0L, alarm.nextScheduledAlarm!!.windowLengthMs)
    }

    @Test fun foregroundPulseSupportsTheMinimumAndroidVersion() {
        val vibrator = if (Build.VERSION.SDK_INT >= 31) context.getSystemService(VibratorManager::class.java).defaultVibrator
            else context.getSystemService(Vibrator::class.java)
        shadowOf(vibrator).setHasVibrator(true)
        val activity = MainActivity()
        val attach = ContextWrapper::class.java.getDeclaredMethod("attachBaseContext", Context::class.java)
        attach.isAccessible = true
        attach.invoke(activity, context)
        val pulse = MainActivity::class.java.getDeclaredMethod("pulse")
        pulse.isAccessible = true
        pulse.invoke(activity)
        assertTrue(shadowOf(vibrator).isVibrating)
    }

    @Test fun disabledAppNotificationsAreReportedBeforeRuntimePermissionApi() {
        if (Build.VERSION.SDK_INT >= 33) return
        val manager = context.getSystemService(NotificationManager::class.java)
        shadowOf(manager).setNotificationsEnabled(false)
        val activity = MainActivity()
        val attach = ContextWrapper::class.java.getDeclaredMethod("attachBaseContext", Context::class.java)
        attach.isAccessible = true
        attach.invoke(activity, context)
        val permission = MainActivity::class.java.getDeclaredMethod("notificationsGranted")
        permission.isAccessible = true
        assertEquals(false, permission.invoke(activity))
        shadowOf(manager).setNotificationsEnabled(true)
        assertEquals(true, permission.invoke(activity))
    }

    @Test fun deliveredIdentityCannotBeRearmedOrDeliveredAgain() {
        for (action in listOf(RestEffects.ACTION_NOTIFY, RestEffects.ACTION_VIBRATE)) {
            RestEffects.schedule(context, action, "session", "delivered", 2000)
            RestEffects.markDelivered(context, action, "delivered")
            RestEffects.schedule(context, action, "session", "delivered", 2000)
            assertFalse(RestEffects.isActive(context, action, "delivered"))
        }
    }

    @Test fun cancelOneEffectPreservesTheOtherIdentity() {
        RestEffects.schedule(context, RestEffects.ACTION_NOTIFY, "session", "rest", 2000)
        RestEffects.schedule(context, RestEffects.ACTION_VIBRATE, "session", "rest", 2000)
        RestEffects.cancel(context, RestEffects.ACTION_NOTIFY, "rest")
        assertFalse(RestEffects.isActive(context, RestEffects.ACTION_NOTIFY, "rest"))
        assertTrue(RestEffects.isActive(context, RestEffects.ACTION_VIBRATE, "rest"))
    }

    @Test fun supportedOldAndroidSchedulesExactly() {
        if (Build.VERSION.SDK_INT >= 31) return
        RestEffects.schedule(context, RestEffects.ACTION_VIBRATE, "session", "rest", 2000)
        val alarm = shadowOf(context.getSystemService(AlarmManager::class.java)).nextScheduledAlarm
        assertNotNull(alarm)
        assertEquals(0L, alarm!!.windowLengthMs)
    }

    @Test fun notificationHasSoundButNeverVibrationOnSupportedVersions() {
        shadowOf(RuntimeEnvironment.getApplication()).grantPermissions("android.permission.POST_NOTIFICATIONS")
        RestEffects.schedule(context, RestEffects.ACTION_NOTIFY, "session", "rest", 2000)
        RestNotificationReceiver().onReceive(context, Intent().putExtra(RestEffects.ARG_REST_ID, "rest"))
        val manager = context.getSystemService(NotificationManager::class.java)
        val notification = shadowOf(manager).getNotification(RestEffects.notificationId("rest"))
        assertNotNull(notification)
        if (Build.VERSION.SDK_INT >= 26) {
            assertFalse(manager.getNotificationChannel(RestEffects.NOTIFICATION_CHANNEL_ID).shouldVibrate())
        } else {
            assertEquals(Settings.System.DEFAULT_NOTIFICATION_URI, notification.sound)
            assertNull(notification.vibrate)
        }
    }

    @Test fun vibrationReceiverWorksWithoutNotificationPermission() {
        val vibrator = if (Build.VERSION.SDK_INT >= 31) context.getSystemService(VibratorManager::class.java).defaultVibrator
            else context.getSystemService(Vibrator::class.java)
        shadowOf(vibrator).setHasVibrator(true)
        RestEffects.schedule(context, RestEffects.ACTION_VIBRATE, "session", "rest", 2000)
        RestVibrationReceiver().onReceive(context, Intent().putExtra(RestEffects.ARG_REST_ID, "rest"))
        assertTrue(shadowOf(vibrator).isVibrating)
        assertEquals(true, RestEffects.deliveryState(context, "rest")["vibrationDelivered"])
    }
}
