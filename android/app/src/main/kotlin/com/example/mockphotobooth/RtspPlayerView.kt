package com.example.mockphotobooth

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.media.MediaScannerConnection
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import android.view.Surface
import android.view.TextureView
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import java.io.File
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.net.Socket
import kotlin.concurrent.thread

class RtspPlayerView(
    context: Context,
    private val url: String
) : PlatformView {

    private val textureView = TextureView(context)
    private var libVLC: LibVLC? = null
    private var mediaPlayer: MediaPlayer? = null
    private var media: Media? = null
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    private val TAG = "RtspPlayerView"
    private val appContext = context.applicationContext
    
    companion object {
        private var activePlayerView: RtspPlayerView? = null
        
        private fun saveToGallery(context: Context, bitmap: Bitmap, timestamp: Long) {
            try {
                val displayName = "PhotoBooth_$timestamp.jpg"
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    // Android 10+ - Use MediaStore
                    val contentValues = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                        put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/PhotoBooth")
                    }
                    
                    val uri = context.contentResolver.insert(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        contentValues
                    )
                    
                    uri?.let {
                        context.contentResolver.openOutputStream(it)?.use { out ->
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
                        }
                        Log.d("RtspPlayerView", "✅ Photo saved to gallery: $displayName")
                    }
                } else {
                    // Android 9 and below - Use direct file access
                    val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                    val photoBoothDir = File(picturesDir, "PhotoBooth")
                    if (!photoBoothDir.exists()) {
                        photoBoothDir.mkdirs()
                    }
                    
                    val imageFile = File(photoBoothDir, displayName)
                    FileOutputStream(imageFile).use { out ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
                    }
                    
                    // Notify media scanner
                    MediaScannerConnection.scanFile(
                        context,
                        arrayOf(imageFile.absolutePath),
                        arrayOf("image/jpeg"),
                        null
                    )
                    Log.d("RtspPlayerView", "✅ Photo saved to gallery: ${imageFile.absolutePath}")
                }
            } catch (e: Exception) {
                Log.e("RtspPlayerView", "Failed to save to gallery: ${e.message}", e)
            }
        }
        
        fun captureSnapshot(context: Context): String? {
            val playerView = activePlayerView
            
            if (playerView == null) {
                Log.e("RtspPlayerView", "❌ No active player view")
                return null
            }
            
            if (playerView.mediaPlayer == null || !playerView.mediaPlayer!!.isPlaying) {
                Log.e("RtspPlayerView", "❌ Player not playing")
                return null
            }
            
            try {
                Log.d("RtspPlayerView", "📸 Capturing frame from TextureView...")
                
                // Get bitmap from TextureView - must be called on main thread
                var rawBitmap: Bitmap? = null
                val latch = java.util.concurrent.CountDownLatch(1)
                
                Handler(Looper.getMainLooper()).post {
                    try {
                        rawBitmap = playerView.textureView.bitmap
                        Log.d("RtspPlayerView", "✓ Raw bitmap captured: ${rawBitmap?.width}x${rawBitmap?.height}")
                    } catch (e: Exception) {
                        Log.e("RtspPlayerView", "❌ Failed to get bitmap: ${e.message}", e)
                    } finally {
                        latch.countDown()
                    }
                }
                
                // Wait for bitmap capture (max 2 seconds)
                if (!latch.await(2, java.util.concurrent.TimeUnit.SECONDS)) {
                    Log.e("RtspPlayerView", "❌ Timeout waiting for bitmap")
                    return null
                }
                
                if (rawBitmap == null) {
                    Log.e("RtspPlayerView", "❌ No bitmap available from TextureView")
                    return null
                }
                
                // Crop bitmap to actual video content (remove black bars)
                val croppedBitmap = cropToVideoContent(rawBitmap!!, playerView)
                
                // Save to cache directory
                val snapshotDir = File(context.cacheDir, "snapshots")
                if (!snapshotDir.exists()) {
                    snapshotDir.mkdirs()
                }
                
                val timestamp = System.currentTimeMillis()
                val snapshotFile = File(snapshotDir, "snapshot_$timestamp.jpg")
                
                FileOutputStream(snapshotFile).use { out ->
                    croppedBitmap.compress(Bitmap.CompressFormat.JPEG, 95, out)
                }
                
                // Save to gallery
                saveToGallery(context, croppedBitmap, timestamp)
                
                // Clean up both bitmaps (they're always different objects now)
                rawBitmap!!.recycle()
                croppedBitmap.recycle()
                
                Log.d("RtspPlayerView", "✅ Snapshot saved: ${snapshotFile.absolutePath}")
                
                return snapshotFile.absolutePath
                
            } catch (e: Exception) {
                Log.e("RtspPlayerView", "❌ Snapshot error: ${e.message}", e)
                return null
            }
        }
        
        private fun cropToVideoContent(rawBitmap: Bitmap, playerView: RtspPlayerView): Bitmap {
            val videoW = playerView.videoWidth
            val videoH = playerView.videoHeight
            val viewW = playerView.textureView.width
            val viewH = playerView.textureView.height
            val bitmapW = rawBitmap.width
            val bitmapH = rawBitmap.height
            
            Log.d("RtspPlayerView", "Crop calculation:")
            Log.d("RtspPlayerView", "  Video: ${videoW}x${videoH}")
            Log.d("RtspPlayerView", "  View: ${viewW}x${viewH}")
            Log.d("RtspPlayerView", "  Bitmap: ${bitmapW}x${bitmapH}")
            
            // If video dimensions are not available, return a copy
            if (videoW == 0 || videoH == 0) {
                Log.w("RtspPlayerView", "⚠️ Video dimensions not available, returning copy of original bitmap")
                return rawBitmap.copy(rawBitmap.config ?: Bitmap.Config.ARGB_8888, false)
            }
            
            // Calculate video aspect ratio and view aspect ratio
            val videoAspect = videoW.toFloat() / videoH.toFloat()
            val viewAspect = viewW.toFloat() / viewH.toFloat()
            
            // Calculate the actual video rectangle within the bitmap
            val cropX: Int
            val cropY: Int
            val cropWidth: Int
            val cropHeight: Int
            
            if (videoAspect > viewAspect) {
                // Video is wider than view - pillarboxing (black bars on sides)
                // Video fills full width, height is less
                cropWidth = bitmapW
                cropHeight = (bitmapW / videoAspect).toInt()
                cropX = 0
                cropY = (bitmapH - cropHeight) / 2
            } else {
                // Video is taller than view - letterboxing (black bars on top/bottom)
                // Video fills full height, width is less
                cropHeight = bitmapH
                cropWidth = (bitmapH * videoAspect).toInt()
                cropY = 0
                cropX = (bitmapW - cropWidth) / 2
            }
            
            Log.d("RtspPlayerView", "  Crop region: x=$cropX, y=$cropY, w=$cropWidth, h=$cropHeight")
            
            // Ensure crop dimensions are within bitmap bounds
            val safeCropX = cropX.coerceIn(0, bitmapW - 1)
            val safeCropY = cropY.coerceIn(0, bitmapH - 1)
            val safeCropWidth = cropWidth.coerceAtMost(bitmapW - safeCropX)
            val safeCropHeight = cropHeight.coerceAtMost(bitmapH - safeCropY)
            
            return try {
                Bitmap.createBitmap(rawBitmap, safeCropX, safeCropY, safeCropWidth, safeCropHeight)
            } catch (e: Exception) {
                Log.e("RtspPlayerView", "❌ Failed to crop bitmap: ${e.message}", e)
                // Return a copy so we can safely recycle both bitmaps
                rawBitmap.copy(rawBitmap.config ?: Bitmap.Config.ARGB_8888, false)
            }
        }
    }

    init {
        // Register this as the active player view
        activePlayerView = this
        
        Log.d(TAG, "═══════════════════════════════════")
        Log.d(TAG, "LibVLC RTSP Player")
        Log.d(TAG, "URL: $url")
        Log.d(TAG, "═══════════════════════════════════")
        
        // Network diagnostics
        thread {
            try {
                // Check WiFi status
                val connectivityManager = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                val activeNetwork = connectivityManager.activeNetwork
                val networkCapabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
                
                Log.d(TAG, "╔═══════════════════════════════╗")
                Log.d(TAG, "║   NETWORK DIAGNOSTICS         ║")
                Log.d(TAG, "╚═══════════════════════════════╝")
                
                if (networkCapabilities != null) {
                    val isWifi = networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
                    val isCellular = networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
                    Log.d(TAG, "Network type: ${if (isWifi) "WiFi ✓" else if (isCellular) "Cellular" else "Unknown"}")
                } else {
                    Log.e(TAG, "❌ No active network!")
                }
                
                // Parse camera address
                val uri = android.net.Uri.parse(url)
                val host = uri.host ?: "unknown"
                val port = uri.port.takeIf { it != -1 } ?: 554
                
                Log.d(TAG, "───────────────────────────────")
                Log.d(TAG, "Testing connection to camera...")
                Log.d(TAG, "Target: $host:$port")
                
                // Test TCP connection
                val socket = Socket()
                val startTime = System.currentTimeMillis()
                
                try {
                    socket.connect(InetSocketAddress(host, port), 5000)
                    val elapsed = System.currentTimeMillis() - startTime
                    socket.close()
                    
                    Log.d(TAG, "╔═══════════════════════════════╗")
                    Log.d(TAG, "║ ✅ NETWORK TEST PASSED! ✅    ║")
                    Log.d(TAG, "╚═══════════════════════════════╝")
                    Log.d(TAG, "Connection time: ${elapsed}ms")
                    
                } catch (e: java.net.SocketTimeoutException) {
                    Log.e(TAG, "╔═══════════════════════════════╗")
                    Log.e(TAG, "║ ❌ CONNECTION TIMEOUT ❌       ║")
                    Log.e(TAG, "╚═══════════════════════════════╝")
                    Log.e(TAG, "")
                    Log.e(TAG, "Possible causes:")
                    Log.e(TAG, "1. Phone and camera on different WiFi networks")
                    Log.e(TAG, "2. Camera is turned off/offline")
                    Log.e(TAG, "3. Firewall blocking port $port")
                    Log.e(TAG, "4. Camera IP address changed")
                    Log.e(TAG, "")
                    Log.e(TAG, "ACTION REQUIRED:")
                    Log.e(TAG, "→ Verify phone is on same WiFi as camera")
                    Log.e(TAG, "→ Ping $host from your computer")
                    Log.e(TAG, "→ Check camera is powered on")
                    
                } catch (e: java.net.ConnectException) {
                    Log.e(TAG, "❌ CONNECTION REFUSED")
                    Log.e(TAG, "→ Port $port is closed on camera")
                    
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Network error: ${e.javaClass.simpleName}")
                    Log.e(TAG, "   ${e.message}")
                }
                
                Log.d(TAG, "═══════════════════════════════")
                
            } catch (e: Exception) {
                Log.e(TAG, "Diagnostic error: ${e.message}")
            }
        }
        
        textureView.surfaceTextureListener = object : TextureView.SurfaceTextureListener {
            override fun onSurfaceTextureAvailable(surface: SurfaceTexture, width: Int, height: Int) {
                Log.d(TAG, "SurfaceTexture available: ${width}x${height}, starting playback")
                startPlayback(appContext, Surface(surface))
            }

            override fun onSurfaceTextureSizeChanged(surface: SurfaceTexture, width: Int, height: Int) {
                Log.d(TAG, "SurfaceTexture size changed: ${width}x${height}")
                // Update VLC output window size to match new texture size
                mediaPlayer?.vlcVout?.setWindowSize(width, height)
            }

            override fun onSurfaceTextureDestroyed(surface: SurfaceTexture): Boolean {
                Log.d(TAG, "SurfaceTexture destroyed")
                stopPlayback()
                return true
            }

            override fun onSurfaceTextureUpdated(surface: SurfaceTexture) {
                // Called on every frame - too noisy to log
            }
        }
    }

    private fun startPlayback(context: Context, surface: Surface) {
        try {
            // Valid LibVLC options for RTSP
            val options = ArrayList<String>().apply {
                add("--rtsp-tcp")  // Force TCP
                add("--network-caching=1000")  // 1s buffer
                add("--rtsp-timeout=15")  // 15s timeout
                add("--live-caching=300")  // Low latency
                add("-vvv")  // Verbose
            }
            
            Log.d(TAG, "Creating LibVLC...")
            options.forEach { Log.d(TAG, "  $it") }
            
            libVLC = LibVLC(context, options)
            Log.d(TAG, "✓ LibVLC created")
            
            mediaPlayer = MediaPlayer(libVLC).apply {
                setEventListener { event ->
                    when (event.type) {
                        MediaPlayer.Event.Opening -> 
                            Log.d(TAG, "━━━ Opening... ━━━")
                        MediaPlayer.Event.Buffering -> 
                            Log.d(TAG, "Buffering: ${event.buffering}%")
                        MediaPlayer.Event.Playing -> {
                            Log.d(TAG, "╔═══════════════════════════════╗")
                            Log.d(TAG, "║ 🎉 VIDEO PLAYING! 🎉          ║")
                            Log.d(TAG, "╚═══════════════════════════════╝")
                            // Set known video dimensions for Tapo C520WS (2K QHD)
                            videoWidth = 2560
                            videoHeight = 1440
                            Log.d(TAG, "✓ Video dimensions set to: ${videoWidth}x${videoHeight}")
                        }
                        MediaPlayer.Event.EncounteredError -> 
                            Log.e(TAG, "❌ VLC Error")
                        MediaPlayer.Event.Vout -> 
                            Log.d(TAG, "✓ Video output (vout: ${event.voutCount})")
                        else -> 
                            Log.d(TAG, "Event: ${event.type}")
                    }
                }
                
                // Attach the TextureView surface
                vlcVout.setVideoSurface(surface, null)
                vlcVout.setWindowSize(textureView.width, textureView.height)
                vlcVout.attachViews()
                Log.d(TAG, "✓ Video attached to TextureView (${textureView.width}x${textureView.height})")
            }
            
            media = Media(libVLC, android.net.Uri.parse(url)).apply {
                setHWDecoderEnabled(true, false)
                addOption(":network-caching=1000")
                addOption(":rtsp-tcp")
            }
            
            mediaPlayer?.media = media
            
            mediaPlayer?.play()
            Log.d(TAG, "✓ Playback started")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error: ${e.message}", e)
        }
    }

    private fun stopPlayback() {
        try {
            // Clear active player view reference
            if (activePlayerView == this) {
                activePlayerView = null
            }
            
            // Stop media player
            mediaPlayer?.apply {
                stop()
                vlcVout.detachViews()
                release()
            }
            mediaPlayer = null
            
            // Release media
            media?.release()
            media = null
            
            // Release LibVLC
            libVLC?.release()
            libVLC = null
            
            Log.d(TAG, "Released")
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing: ${e.message}")
        }
    }

    override fun getView(): View = textureView

    override fun dispose() {
        Log.d(TAG, "Disposing")
        stopPlayback()
    }
}

class RtspPlayerViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: Context,
        viewId: Int,
        args: Any?
    ): PlatformView {
        val params = args as Map<String, Any>
        val url = params["url"] as String
        return RtspPlayerView(context, url)
    }
}
