plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// 1. Create a Properties object
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")

// 2. Load the file if it exists
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

// 3. Helper function to read the value as an Int
fun getLocalProperty(key: String, defaultValue: Int): Int {
    val value = localProperties.getProperty(key)
    return value?.toIntOrNull() ?: defaultValue
}

android {
    namespace = "com.limo.cloudreve4_flutter"
    compileSdk = getLocalProperty("flutter.compileSdkVersion", 34)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.limo.cloudreve4_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = getLocalProperty("flutter.minSdkVersion", 34)
        targetSdk = getLocalProperty("flutter.targetSdkVersion", 34)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
