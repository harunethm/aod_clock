package com.scylla.tool.aodclock

import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.io.ByteArrayOutputStream

/**
 * Reads whatever media session is currently active system-wide (Spotify,
 * YouTube Music, etc.) via [MediaSessionManager] — this service's only job
 * is being an enabled notification listener, which is the permission
 * [MediaSessionManager.getActiveSessions] requires. Actual notification
 * *content* is never read; `onNotificationPosted`/`onNotificationRemoved`
 * mainly exist to prompt a session refresh — they're also reused to publish
 * a live count of other apps' active notifications (see
 * [NotificationCountBridge]), which piggybacks on the same permission
 * rather than needing a separate one.
 */
class MediaNotificationListenerService : NotificationListenerService() {

    private var controllerCallback: MediaController.Callback? = null
    private var observedController: MediaController? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val sessionsChangedListener =
        MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
            refreshSessions(controllers)
        }

    override fun onListenerConnected() {
        super.onListenerConnected()
        val manager = getSystemService(MediaSessionManager::class.java)
        val component = ComponentName(this, MediaNotificationListenerService::class.java)
        manager.addOnActiveSessionsChangedListener(sessionsChangedListener, component)
        refreshSessions(manager.getActiveSessions(component))
        publishNotificationCount()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        val manager = getSystemService(MediaSessionManager::class.java)
        manager.removeOnActiveSessionsChangedListener(sessionsChangedListener)
        detachCallback()
        NowPlayingBridge.publish(null, null)
        NotificationCountBridge.publish(0)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) = publishNotificationCount()

    override fun onNotificationRemoved(sbn: StatusBarNotification) = publishNotificationCount()

    /** Excludes this app's own notifications (foreground-service + AOD trigger) from the count. */
    private fun publishNotificationCount() {
        val count = try {
            activeNotifications.count { it.packageName != packageName }
        } catch (e: SecurityException) {
            0
        }
        NotificationCountBridge.publish(count)
    }

    private fun refreshSessions(controllers: List<MediaController>?) {
        detachCallback()
        val controller = controllers?.firstOrNull { it.playbackState != null }
        if (controller == null) {
            NowPlayingBridge.publish(null, null)
            return
        }

        observedController = controller
        val callback = object : MediaController.Callback() {
            override fun onMetadataChanged(metadata: MediaMetadata?) = publishFrom(controller)
            override fun onPlaybackStateChanged(state: PlaybackState?) = publishFrom(controller)
            override fun onSessionDestroyed() = refreshSessions(null)
        }
        controllerCallback = callback
        controller.registerCallback(callback)
        publishFrom(controller)
    }

    private fun detachCallback() {
        controllerCallback?.let { observedController?.unregisterCallback(it) }
        controllerCallback = null
        observedController = null
    }

    private fun publishFrom(controller: MediaController) {
        val metadata = controller.metadata
        val state = controller.playbackState

        fun publish(albumArtBytes: ByteArray?) {
            val event = mapOf(
                "title" to metadata?.getString(MediaMetadata.METADATA_KEY_TITLE),
                "artist" to metadata?.getString(MediaMetadata.METADATA_KEY_ARTIST),
                "albumArt" to albumArtBytes,
                "isPlaying" to (state?.state == PlaybackState.STATE_PLAYING),
                "positionMs" to (state?.position ?: 0L).toInt(),
                "durationMs" to (metadata?.getLong(MediaMetadata.METADATA_KEY_DURATION) ?: 0L).toInt(),
            )
            NowPlayingBridge.publish(controller, event)
        }

        // Many apps (Spotify, YouTube Music) never embed a bitmap in
        // MediaMetadata at all — only a content:// URI, to avoid Binder
        // transaction size limits. Checking only the two bitmap keys (the
        // original implementation) silently showed no art for exactly
        // those apps. Embedded bitmap still wins when present — it's free.
        val embeddedBitmap = metadata?.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
            ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_ART)
            ?: metadata?.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)
        if (embeddedBitmap != null) {
            publish(compress(embeddedBitmap))
            return
        }

        publish(null)

        val artUri = metadata?.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_ART_URI)
            ?: metadata?.getString(MediaMetadata.METADATA_KEY_DISPLAY_ICON_URI)
            ?: return

        // MediaController.Callback (the only caller of this function) runs
        // on the thread that registered it — main, here — so resolving a
        // content:// URI (disk/IPC) has to move off it to avoid an ANR.
        Thread {
            val bytes = try {
                contentResolver.openInputStream(Uri.parse(artUri))?.use { stream ->
                    BitmapFactory.decodeStream(stream)?.let { compress(it) }
                }
            } catch (e: Exception) {
                null
            }
            if (bytes != null) mainHandler.post { publish(bytes) }
        }.start()
    }

    private fun compress(bitmap: Bitmap): ByteArray {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
        return stream.toByteArray()
    }
}
