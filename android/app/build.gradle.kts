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

// 1. 加载 key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.limo.cloudreve4_flutter"
    compileSdk = getLocalProperty("flutter.compileSdkVersion", 34)
    ndkVersion = flutter.ndkVersion

    // 2. 配置签名选项
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

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

    packaging {
        resources {
            // 如果遇到重复的 .so 文件，优先取第一个
            pickFirst("lib/**/libmpv.so")
            pickFirst("lib/**/libmediakitandroidhelper.so")
        }
    }

    buildTypes {
        release {
            // 1. 将原来的 getByName("debug") 替换为 getByName("release")
            signingConfig = signingConfigs.getByName("release")
            
            // 2. 建议同时开启混淆，这能大幅减小网盘应用的体积并保护代码
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val appName = "cloudreve4_flutter"
            val versionName = variant.versionName
            val versionCode = variant.versionCode
            val type = variant.name // release 或 debug

            val abi = output.getFilter(com.android.build.OutputFile.ABI) ?: "universal"
            
            output.outputFileName = "${appName}_v${versionName}_${versionCode}_${abi}_release.apk"
        }
    }
}

flutter {
    source = "../.."
}
