package com.example.fitness_counter

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class RestNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val restId = intent.getStringExtra(RestEffects.ARG_REST_ID) ?: return
        if (!RestEffects.isActive(context, RestEffects.ACTION_NOTIFY, restId)) return
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                RestEffects.NOTIFICATION_CHANNEL_ID,
                context.getString(R.string.rest_reminder_channel),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                enableVibration(false)
                vibrationPattern = null
                setSound(Settings.System.DEFAULT_NOTIFICATION_URI, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
            }
            manager.createNotificationChannel(channel)
        }
        manager.notify(
            RestEffects.notificationId(restId),
            NotificationCompat.Builder(context, RestEffects.NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle(context.getString(R.string.rest_complete_title))
                .setContentText(context.getString(R.string.rest_complete_body))
                .setSound(Settings.System.DEFAULT_NOTIFICATION_URI)
                .setVibrate(null)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .build(),
        )
        RestEffects.markDelivered(context, RestEffects.ACTION_NOTIFY, restId)
    }
}
