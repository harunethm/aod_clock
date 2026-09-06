package com.scylla.tool.aodclock

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Wires every platform channel identically for [MainActivity] and
 * [AodOverlayActivity] — the two `FlutterActivity`s that share this app's
 * whole platform-channel contract (see `app_router.dart` for why there are
 * two). Extracted here once a third channel would otherwise mean
 * triplicated boilerplate across both files.
 */
object AodChannels {
    fun configure(flutterEngine: FlutterEngine, context: Context, activity: Activity?) {
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "com.scylla.tool.aodclock/aod_control")
            .setMethodCallHandler { call, result ->
                AodControlHandler.handle(context, activity, call, result)
            }

        MethodChannel(messenger, "com.scylla.tool.aodclock/now_playing/control")
            .setMethodCallHandler { call, result -> NowPlayingControlHandler.handle(call, result) }

        EventChannel(messenger, "com.scylla.tool.aodclock/now_playing/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var attachedSink: EventChannel.EventSink? = null

                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    attachedSink = sink
                    NowPlayingBridge.attach(sink)
                }

                override fun onCancel(arguments: Any?) {
                    attachedSink?.let { NowPlayingBridge.detach(it) }
                    attachedSink = null
                }
            })

        EventChannel(messenger, "com.scylla.tool.aodclock/notification_count/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var attachedSink: EventChannel.EventSink? = null

                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    attachedSink = sink
                    NotificationCountBridge.attach(sink)
                }

                override fun onCancel(arguments: Any?) {
                    attachedSink?.let { NotificationCountBridge.detach(it) }
                    attachedSink = null
                }
            })
    }
}
