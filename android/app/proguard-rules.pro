-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}

# Drift, Supabase and connectivity are reached from Dart over the platform
# channel, which R8 does not analyse, so they need no keep rules of their own.
# These are the remaining entry points that are only referenced by name.
-keep class androidx.startup.InitializationProvider { *; }

# Keep line numbers readable in Play Console crash reports while still
# obfuscating class and member names (the table also feeds de-obfuscation).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Google Mobile Ads (Play services Ads) requires its classes to survive R8.
-keep class com.google.android.gms.ads.** { *; }

# Flutter embedding entry point referenced from the AndroidManifest.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.learnlaw.app.MainActivity { *; }

# Flutter's deferred-components support references Play Core classes that are
# not bundled because this app does not use deferred components.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
