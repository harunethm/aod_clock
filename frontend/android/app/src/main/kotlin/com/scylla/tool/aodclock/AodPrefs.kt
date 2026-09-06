package com.scylla.tool.aodclock

import android.content.Context

/**
 * Native-side source of truth for whether AOD is enabled. Read by
 * [AodForegroundService]'s screen-off receiver and [BootReceiver], neither
 * of which have a live Flutter engine to ask. Flutter's own SecureStorage
 * copy (see settings_datasource.dart) is for the UI only — this is what
 * actually gates the overlay launch.
 */
object AodPrefs {
    private const val PREFS_NAME = "aod_prefs"
    private const val KEY_ENABLED = "aod_enabled"
    private const val KEY_BRIGHTNESS = "brightness_level"

    fun isEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    fun brightnessLevel(context: Context): Float =
        prefs(context).getFloat(KEY_BRIGHTNESS, 0.12f)

    fun setBrightnessLevel(context: Context, value: Float) {
        prefs(context).edit().putFloat(KEY_BRIGHTNESS, value).apply()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
