package com.scylla.tool.aodclock

import io.flutter.plugin.common.EventChannel

/** Same attach/detach/cache pattern as [NowPlayingBridge], one Int instead of a track map. */
object NotificationCountBridge {
    private var eventSink: EventChannel.EventSink? = null
    private var lastCount = 0

    fun attach(sink: EventChannel.EventSink) {
        eventSink = sink
        sink.success(lastCount)
    }

    fun detach(sink: EventChannel.EventSink) {
        if (eventSink === sink) eventSink = null
    }

    fun publish(count: Int) {
        lastCount = count
        eventSink?.success(count)
    }
}
