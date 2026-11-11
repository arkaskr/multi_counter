# Proguard / R8 rules for Daily Counter

# Suppress Play Core warnings in Flutter
-dontwarn com.google.android.play.core.**
-dontwarn **
-ignorewarnings

# Keep Flutter Wrapper & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep App Package & Native Classes
-keep class com.dailycounter.app.daily_counter.** { *; }
-keepclassmembers class com.dailycounter.app.daily_counter.** { *; }

# Keep Jetpack Glance Components and Actions
-keep class androidx.glance.** { *; }
-keep interface androidx.glance.** { *; }
-keep class androidx.glance.appwidget.** { *; }
-keep class androidx.glance.appwidget.action.** { *; }
-keep class androidx.glance.appwidget.action.ActionCallback { *; }
-keep public class * extends androidx.glance.appwidget.action.ActionCallback {
    public <init>();
}
-keep public class * extends androidx.glance.appwidget.GlanceAppWidget {
    public <init>();
}
-keep public class * extends androidx.glance.appwidget.GlanceAppWidgetReceiver {
    public <init>();
}

# Keep WorkManager (used by Glance for widget updates and background tasks)
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }

# Keep Coroutines
-keepnames class kotlinx.coroutines.** { *; }

# Keep SQLite
-keep class com.tekartik.sqflite.** { *; }

# Keep FileProvider and PackageInfo for In-App Updates
-keep class androidx.core.content.FileProvider { *; }
-keep class androidx.core.content.pm.PackageInfoCompat { *; }
