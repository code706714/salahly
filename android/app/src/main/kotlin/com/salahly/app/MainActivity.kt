package com.salahly.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    // Pushes name these channels (see supabase/functions/send-push/fcm.ts).
    // Without them Android files every push under a quiet default channel:
    // no pop-up and, for a call, no ring.
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)

        val general = NotificationChannel(
            "salahly_general",
            "إشعارات صلحلي",
            NotificationManager.IMPORTANCE_HIGH,
        )

        val calls = NotificationChannel(
            "salahly_calls",
            "المكالمات",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 600, 400, 600, 400, 600)
        }

        manager.createNotificationChannels(listOf(general, calls))
    }
}
