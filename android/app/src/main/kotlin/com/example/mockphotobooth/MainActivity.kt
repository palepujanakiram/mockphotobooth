package com.example.mockphotobooth

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mockphotobooth/snapshot"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register platform view for RTSP player
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "rtsp_player_view",
                RtspPlayerViewFactory()
            )
        
        // Register method channel for snapshot capture
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "captureSnapshot" -> {
                    Log.d("MainActivity", "📸 Snapshot requested")
                    try {
                        val snapshotPath = RtspPlayerView.captureSnapshot(this)
                        if (snapshotPath != null) {
                            Log.d("MainActivity", "✅ Snapshot saved: $snapshotPath")
                            result.success(snapshotPath)
                        } else {
                            Log.e("MainActivity", "❌ Snapshot failed")
                            result.error("CAPTURE_FAILED", "Failed to capture snapshot. Make sure video is playing.", null)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "❌ Snapshot error: ${e.message}", e)
                        result.error("CAPTURE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
