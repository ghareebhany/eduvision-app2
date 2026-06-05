# Keep Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep JSON models (prevent R8 from stripping fields)
-keepattributes *Annotation*
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Flutter engine
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep Riverpod
-keep class dev.rikka.tools.refine.** { *; }

# Keep secure storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep video_player ExoPlayer
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
