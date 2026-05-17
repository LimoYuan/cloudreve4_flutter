plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

// 读取 android/key.properties；如果没有正式签名文件，就自动回退到 debug 签名，保证 release APK 能打出来。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun Any?.isNonBlankString(): Boolean = this?.toString()?.isNotBlank() == true

val releaseStoreFilePath = keystoreProperties["storeFile"]?.toString()
val releaseStoreFile = releaseStoreFilePath?.let { file(it) }

val hasReleaseKeystore =
    keystoreProperties["keyAlias"].isNonBlankString() &&
    keystoreProperties["keyPassword"].isNonBlankString() &&
    keystoreProperties["storePassword"].isNonBlankString() &&
    releaseStoreFile != null &&
    releaseStoreFile.exists()

android {
    namespace = "com.limo.cloudreve4_flutter"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = releaseStoreFile
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.limo.cloudreve4_flutter"

        // 兼容你现在这台 MIUI 13 / Android 12 设备，同时仍按 Android 13+ 规则适配高版本系统。
        // Android 13+ 专项适配靠 targetSdk=36 和运行时权限/前台服务类型，不靠 minSdk=33。
        minSdk = 31
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        resources {
            pickFirst("lib/**/libmpv.so")
            pickFirst("lib/**/libmediakitandroidhelper.so")
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }

        release {
            // 没有 android/key.properties 或正式 keystore 时，自动使用 debug 签名。
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // 先关闭 R8 混淆/资源压缩，避免 Play Core deferred components 缺失类导致打包失败。
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val appName = "mengling_netdisk"
            val versionName = variant.versionName
            val versionCode = variant.versionCode
            val abi = output.getFilter(com.android.build.OutputFile.ABI) ?: "universal"
            output.outputFileName = "${appName}_v${versionName}_${versionCode}_${abi}_${variant.name}.apk"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
