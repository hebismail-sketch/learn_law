import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.learnlaw.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.learnlaw.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                val properties = Properties()
                properties.load(FileInputStream(keyPropertiesFile))
                storeFile = file(properties.getProperty("storeFile", "upload-keystore.jks"))
                storePassword = properties.getProperty("storePassword", "")
                keyAlias = properties.getProperty("keyAlias", "")
                keyPassword = properties.getProperty("keyPassword", "")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("upload")
            // Kept off on purpose. R8 shrinking is switched on by adding
            // `isMinifyEnabled = true` together with the rules in
            // proguard-rules.pro; that change must be followed by a full
            // on-device test pass (Drift, Supabase, AdMob all use reflection),
            // so it is not flipped here as part of a security review.
            isDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // A release build must never be signed with a debug key: Google Play
    // rejects it, and a build that fell back silently would look fine locally.
    // The check runs only for release tasks so `flutter run` keeps working.
    val signsRelease = gradle.startParameter.taskNames.any {
        it.contains("Release", ignoreCase = true) || it.contains("bundle", ignoreCase = true)
    }
    if (signsRelease) {
        require(rootProject.file("key.properties").exists()) {
            "Missing android/key.properties. A release build must be signed with the upload keystore."
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
