package com.scylla.tool.aodclock

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Shown instead of letting the screen turn off (launched by
 * [AodForegroundService] on `ACTION_SCREEN_OFF`). `setShowWhenLocked`/
 * `setTurnScreenOn` display over the lockscreen without disabling it —
 * tapping or a real unlock (`ACTION_USER_PRESENT`) finishes back to the
 * normal PIN/biometric prompt. No `SYSTEM_ALERT_WINDOW`, no
 * `DISABLE_KEYGUARD` — see this project's CLAUDE.md for why.
 *
 * ponytail: this spins up a fresh FlutterEngine on every screen-off rather
 * than reusing a pre-warmed cached engine (`FlutterEngineCache`). That costs
 * a few hundred ms of CPU at launch, not a continuous drain — negligible
 * next to keeping the screen on for hours. Revisit with a cached engine if
 * that launch latency/CPU spike ever measurably matters.
 */
class AodOverlayActivity : FlutterActivity() {

    private val userPresentReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_USER_PRESENT) finish()
        }
    }

    override fun getInitialRoute(): String = "/aod"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.attributes = window.attributes.apply {
            screenBrightness = AodPrefs.brightnessLevel(this@AodOverlayActivity)
        }

        // Immersive: hide status + nav bars, swipe-revealable rather than
        // gone-for-good — a real AOD panel has no status bar either.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).let { controller ->
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }

        // Best-effort hint to drop to the panel's lowest supported refresh
        // rate — only actually honored on LTPO-capable panels (Samsung S22
        // Ultra+/S23/24/25/Note20 Ultra); a no-op fixed-refresh-rate panel
        // just ignores it. `View.setRequestedFrameRate` (API 35+) is the
        // simple per-View hint API, versus the older `Surface.setFrameRate`
        // which needs direct access to the rendering Surface — Flutter
        // doesn't expose that from app code, so this is the only frame-rate
        // control actually reachable here. Genuinely a no-op below API 35.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            window.decorView.setRequestedFrameRate(View.REQUESTED_FRAME_RATE_CATEGORY_LOW)
        }
        val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(userPresentReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(userPresentReceiver, filter)
        }

        // Dismiss the full-screen-intent trigger notification now that it's
        // done its job — otherwise it lingers in the shade even though this
        // screen already took over.
        getSystemService(NotificationManager::class.java)
            .cancel(AodForegroundService.TRIGGER_NOTIFICATION_ID)
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(userPresentReceiver)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AodChannels.configure(flutterEngine, applicationContext, this)
    }
}
