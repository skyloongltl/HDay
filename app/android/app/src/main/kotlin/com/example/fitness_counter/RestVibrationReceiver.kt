package com.example.fitness_counter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

class RestVibrationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val restId = intent.getStringExtra(RestEffects.ARG_REST_ID) ?: return
        if (!RestEffects.isActive(context, RestEffects.ACTION_VIBRATE, restId)) return
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION") context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (vibrator.hasVibrator()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(350, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION") vibrator.vibrate(350)
            }
        }
        RestEffects.markDelivered(context, RestEffects.ACTION_VIBRATE, restId)
    }
}
