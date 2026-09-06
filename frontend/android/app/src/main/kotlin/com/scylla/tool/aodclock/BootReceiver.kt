package com.scylla.tool.aodclock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!AodPrefs.isEnabled(context)) return
        context.startForegroundService(Intent(context, AodForegroundService::class.java))
    }
}
