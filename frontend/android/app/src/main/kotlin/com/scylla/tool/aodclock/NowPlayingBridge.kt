package com.scylla.tool.aodclock

import android.media.session.MediaController
import io.flutter.plugin.common.EventChannel

/**
 * Connects [MediaNotificationListenerService] (runs independently of any
 * Activity/engine) to whichever Flutter engine is currently listening.
 * Caches the last event so a freshly attached sink (e.g. AodOverlayActivity
 * launching after the listener service already found a session) gets the
 * current state immediately instead of waiting for the next change.
 */
object NowPlayingBridge {
    private var eventSink: EventChannel.EventSink? = null
    private var lastEvent: Map<String, Any?>? = null
    var activeController: MediaController? = null
        private set

    fun attach(sink: EventChannel.EventSink) {
        eventSink = sink
        sink.success(lastEvent)
    }

    fun detach(sink: EventChannel.EventSink) {
        if (eventSink === sink) eventSink = null
    }

    fun publish(controller: MediaController?, event: Map<String, Any?>?) {
        activeController = controller
        lastEvent = event
        eventSink?.success(event)
    }
}
