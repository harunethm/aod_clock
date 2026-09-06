package com.scylla.tool.aodclock

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Handler for `com.scylla.tool.aodclock/now_playing/control`. */
object NowPlayingControlHandler {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val transportControls = NowPlayingBridge.activeController?.transportControls
        if (transportControls == null) {
            result.success(null)
            return
        }
        when (call.method) {
            "play" -> transportControls.play()
            "pause" -> transportControls.pause()
            "skipNext" -> transportControls.skipToNext()
            "skipPrevious" -> transportControls.skipToPrevious()
            else -> {
                result.notImplemented()
                return
            }
        }
        result.success(null)
    }
}
