plugins {
    id("com.android.application")
    // Flutter Gradle 插件必须在 Android 插件之后应用。
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.railyw.anime_mobile_torrent"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 应用 ID 与当前 Android namespace 保持一致，后续上架前再评估是否调整。
        applicationId = "com.railyw.anime_mobile_torrent"
        // SDK 与版本号由 Flutter 配置注入，避免 Android 与 Dart 侧版本漂移。
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 当前没有发布签名，release 暂用 debug 签名，等发布渠道确认后再替换。
            signingConfig = signingConfigs.getByName("debug")
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
