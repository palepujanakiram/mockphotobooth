# ExoPlayer ProGuard rules
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-dontwarn androidx.media3.**

# RTSP specific
-keep class androidx.media3.exoplayer.rtsp.** { *; }
-keep interface androidx.media3.exoplayer.rtsp.** { *; }

# Keep all ExoPlayer classes
-keepclassmembers class * implements androidx.media3.common.Player {
    *;
}
