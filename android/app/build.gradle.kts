plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.session_based_tracking_app"
    // Keep 36 if you have the latest SDK, but 34/35 is more standard for 2026.
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring to support Java 8+ features on older SDKs
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.session_based_tracking_app"
        // Ensure minSdk is at least 21 for modern plugins
        minSdk = flutter.minSdkVersion 
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Optional: Add shrinker/minify if you want a smaller APK
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Upgraded to 2.1.4 to satisfy flutter_local_notifications requirement
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}