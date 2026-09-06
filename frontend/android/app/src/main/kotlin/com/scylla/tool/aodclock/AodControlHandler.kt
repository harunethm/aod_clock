package com.scylla.tool.aodclock

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Shared handler for `com.scylla.tool.aodclock/aod_control`, wired up
 * identically by both [MainActivity] (settings UI) and [AodOverlayActivity]
 * (the AOD screen) — see `app_router.dart` for why there are two Activities
 * on one channel name. This Kotlin `when` is the source-of-truth wire
 * contract that `aod_control_channel.dart` mirrors.
 */
object AodControlHandler {
    fun handle(
        context: Context,
        activity: Activity?,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "setAodEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                AodPrefs.setEnabled(context, enabled)
                val intent = Intent(context, AodForegroundService::class.java)
                if (enabled) {
                    context.startForegroundService(intent)
                } else {
                    context.stopService(intent)
                }
                result.success(null)
            }

            "isAodEnabled" -> result.success(AodPrefs.isEnabled(context))

            "setBrightnessLevel" -> {
                // Was previously never called — the settings slider only
                // wrote to Flutter's own storage, so `AodOverlayActivity`
                // always read `AodPrefs`'s hardcoded 0.12f default no
                // matter what the slider showed. Found by the user
                // noticing AOD was always dim regardless of this setting.
                val level = call.argument<Double>("level")?.toFloat()
                if (level != null) AodPrefs.setBrightnessLevel(context, level)
                result.success(null)
            }

            "isNotificationListenerGranted" -> {
                val enabledListeners = Settings.Secure.getString(
                    context.contentResolver,
                    "enabled_notification_listeners",
                )
                val granted = enabledListeners?.contains(context.packageName) == true
                result.success(granted)
            }

            "openNotificationListenerSettings" -> {
                context.startActivity(
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            }

            "isBatteryOptimizationExempt" -> {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(context.packageName))
            }

            "requestBatteryOptimizationExemption" -> {
                val intent = Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }

            "isNotificationsPermissionGranted" -> {
                // The actual root cause behind AOD never triggering: on
                // API 33+ *every* notification this app posts — including
                // the full-screen-intent trigger, not just the visible
                // foreground-service one — is silently dropped by the OS
                // unless this is granted. No crash, no log, nothing;
                // confirmed via `adb shell cmd appops get ... POST_NOTIFICATION`
                // reading "ignore" on a fresh install. Below API 33 posting
                // notifications was never gated, so this is always granted.
                val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.POST_NOTIFICATIONS,
                    ) == PackageManager.PERMISSION_GRANTED
                } else {
                    true
                }
                result.success(granted)
            }

            "requestNotificationsPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && activity != null) {
                    ActivityCompat.requestPermissions(
                        activity,
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        REQUEST_CODE_POST_NOTIFICATIONS,
                    )
                }
                result.success(null)
            }

            "isFullScreenIntentGranted" -> {
                // Below API 34 this permission isn't gated at all — always
                // treat it as granted there so the UI doesn't show a
                // permanently-red tile on older Android.
                val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    val manager = context.getSystemService(NotificationManager::class.java)
                    manager.canUseFullScreenIntent()
                } else {
                    true
                }
                result.success(granted)
            }

            "openFullScreenIntentSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    context.startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                            Uri.parse("package:${context.packageName}"),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }
                result.success(null)
            }

            "dismissAodOverlay" -> {
                activity?.finish()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    const val REQUEST_CODE_POST_NOTIFICATIONS = 1001
}
