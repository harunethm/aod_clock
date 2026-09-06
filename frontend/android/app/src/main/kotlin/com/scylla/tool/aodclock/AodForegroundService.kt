package com.scylla.tool.aodclock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder

/**
 * Persistent low-priority foreground service whose only job is keeping a
 * screen-off/on receiver alive. Android 14+ requires a declared
 * `foregroundServiceType` for any long-running service — this one is
 * `specialUse` (see the manifest) since none of the built-in types
 * (location, media playback, etc.) describe "watch for screen-off and show
 * an overlay".
 */
class AodForegroundService : Service() {

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF && AodPrefs.isEnabled(context)) {
                launchAodOverlay(context)
            }
        }
    }

    /**
     * A plain `context.startActivity()` from here is exactly what Android's
     * background-activity-launch restrictions (Android 10+) block — it
     * fails silently, no crash, the screen just turns off normally. A
     * full-screen-intent notification is the Android-sanctioned way to
     * launch an Activity over the lockscreen from the background (the same
     * mechanism incoming-call/alarm apps use). `AodOverlayActivity` is
     * `launchMode="singleInstance"`, so firing this while it's already
     * showing just re-focuses it — safe to call unconditionally.
     */
    private fun launchAodOverlay(context: Context) {
        val overlayIntent = Intent(context, AodOverlayActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            0,
            overlayIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                TRIGGER_CHANNEL_ID,
                "AOD Trigger",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Launches the always-on display over the lockscreen" }
            manager.createNotificationChannel(channel)
        }

        val notification = Notification.Builder(context, TRIGGER_CHANNEL_ID)
            .setContentTitle("AOD Clock")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCategory(Notification.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setAutoCancel(true)
            .build()

        manager.notify(TRIGGER_NOTIFICATION_ID, notification)
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, buildNotification())
        val filter = IntentFilter(Intent.ACTION_SCREEN_OFF)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screenReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(screenReceiver)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AOD Clock",
                NotificationManager.IMPORTANCE_MIN,
            ).apply { description = "Keeps the always-on display active" }
            manager.createNotificationChannel(channel)
        }

        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )

        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("AOD Clock is active")
            .setContentText("Tap to open settings")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "aod_service"
        private const val NOTIFICATION_ID = 1
        private const val TRIGGER_CHANNEL_ID = "aod_trigger"
        const val TRIGGER_NOTIFICATION_ID = 2
    }
}
