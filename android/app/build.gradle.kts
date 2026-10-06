plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.salahly.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.salahly.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // From `version:` in pubspec.yaml (name+build), via the Flutter plugin.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        resValues = true
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "صلحلي Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "صلحلي Staging")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "صلحلي")
        }
    }

    // The release key comes from the environment (CI secrets or the
    // developer's shell), never from a file in the repository. On a
    // developer machine a missing key falls back to the debug key so the
    // build still runs; in CI a release build without the full key fails,
    // so a debug-signed bundle can never be produced there.
    val releaseKeystore = System.getenv("ANDROID_KEYSTORE_PATH")
    val missingKeyInputs = listOf(
        "ANDROID_KEYSTORE_PATH",
        "ANDROID_KEYSTORE_PASSWORD",
        "ANDROID_KEY_ALIAS",
        "ANDROID_KEY_PASSWORD",
    ).filter { System.getenv(it).isNullOrBlank() }
    val hasReleaseKey = missingKeyInputs.isEmpty() &&
        file(releaseKeystore!!).exists()
    if (System.getenv("CI") == "true" && !hasReleaseKey) {
        gradle.taskGraph.whenReady {
            if (allTasks.any { it.name.contains("Release") }) {
                throw GradleException(
                    "Release signing is incomplete in CI (missing: " +
                        "${missingKeyInputs.joinToString()}, or the keystore file does not exist).",
                )
            }
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(releaseKeystore!!)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKey) "release" else "debug",
            )
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
