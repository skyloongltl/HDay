package com.example.fitness_counter

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

object RestEffects {
    const val CHANNEL = "fitness_counter/rest_effects"
    const val ARG_SESSION_ID = "sessionId"
    const val ARG_REST_ID = "restId"
    const val ARG_DUE_AT_UTC_MILLIS = "dueAtUtcMillis"
    const val ARG_ENABLED = "enabled"
    const val ARG_NOTIFICATIONS_GRANTED = "notificationsGranted"
    const val ARG_EXACT_ALARMS_GRANTED = "exactAlarmsGranted"
    const val ACTION_VIBRATE = "com.example.fitness_counter.REST_VIBRATE"
    const val ACTION_NOTIFY = "com.example.fitness_counter.REST_NOTIFY"
    const val NOTIFICATION_CHANNEL_ID = "rest_complete_sound"
    const val NOTIFICATION_ID_OFFSET = 80_000
    private const val PREFS = "rest_effects"
    private const val VIBRATION_ACTIVE = "vibration_active"
    private const val NOTIFICATION_ACTIVE = "notification_active"
    private const val VIBRATION_DELIVERED = "vibration_delivered"
    private const val NOTIFICATION_DELIVERED = "notification_delivered"

    fun schedule(context: Context, action: String, sessionId: String, restId: String, dueAtMillis: Long) {
        if (delivered(context, action) == restId) return
        active(context, action, restId)
        val pending = pendingIntent(context, action, sessionId, restId)
        val alarm = context.getSystemService(AlarmManager::class.java)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarm.canScheduleExactAlarms()) {
            alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, dueAtMillis, pending)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, dueAtMillis, pending)
        } else {
            alarm.set(AlarmManager.RTC_WAKEUP, dueAtMillis, pending)
        }
    }

    fun cancel(context: Context, action: String, restId: String) {
        if (current(context, action) != restId) return
        val pending = pendingIntent(context, action, "", restId)
        context.getSystemService(AlarmManager::class.java).cancel(pending)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(activeKey(action)).apply()
    }

    fun isActive(context: Context, action: String, restId: String): Boolean =
        current(context, action) == restId && delivered(context, action) != restId

    fun markDelivered(context: Context, action: String, restId: String) {
        if (!isActive(context, action, restId)) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(deliveredKey(action), restId)
            .remove(activeKey(action))
            .apply()
    }

    fun notificationId(restId: String): Int = NOTIFICATION_ID_OFFSET + (restId.hashCode() and 0x3fffffff)

    fun deliveryState(context: Context, restId: String): Map<String, Boolean> {
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "notificationActive" to (preferences.getString(NOTIFICATION_ACTIVE, null) == restId),
            "vibrationActive" to (preferences.getString(VIBRATION_ACTIVE, null) == restId),
            "notificationDelivered" to (preferences.getString(NOTIFICATION_DELIVERED, null) == restId),
            "vibrationDelivered" to (preferences.getString(VIBRATION_DELIVERED, null) == restId),
        )
    }

    private fun active(context: Context, action: String, restId: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(activeKey(action), restId).apply()
    }

    private fun current(context: Context, action: String): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(activeKey(action), null)

    private fun delivered(context: Context, action: String): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(deliveredKey(action), null)

    private fun activeKey(action: String): String = if (action == ACTION_VIBRATE) VIBRATION_ACTIVE else NOTIFICATION_ACTIVE
    private fun deliveredKey(action: String): String = if (action == ACTION_VIBRATE) VIBRATION_DELIVERED else NOTIFICATION_DELIVERED

    private fun pendingIntent(context: Context, action: String, sessionId: String, restId: String): PendingIntent {
        val intent = Intent(context, if (action == ACTION_VIBRATE) RestVibrationReceiver::class.java else RestNotificationReceiver::class.java)
            .setAction(action)
            .setData(Uri.parse("fitness-counter://rest/$restId"))
            .putExtra(ARG_SESSION_ID, sessionId)
            .putExtra(ARG_REST_ID, restId)
        return PendingIntent.getBroadcast(
            context,
            restId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
