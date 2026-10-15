import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingValues = Properties().apply {
    val input = rootProject.file("key.properties")
    if (input.exists()) input.inputStream().use { load(it) }
}
val configuredAppId = providers.gradleProperty("SANAD_APPLICATION_ID").orNull
    ?: System.getenv("SANAD_APPLICATION_ID")
val releaseRequested = gradle.startParameter.taskNames.any {
    val task = it.substringAfterLast(":").lowercase()
    task.contains("release") || task in listOf("assemble", "build", "bundle", "publish")
}
val hasReleaseSigning = listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
    !signingValues.getProperty(it).isNullOrBlank()
}
if (releaseRequested) {
    require(configuredAppId != null && configuredAppId.matches(Regex("[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z][a-zA-Z0-9_]*)+")) && !configuredAppId.startsWith("com.example.")) {
        "Set SANAD_APPLICATION_ID to the registered production application ID."
    }
    require(hasReleaseSigning && rootProject.file(signingValues.getProperty("storeFile")).isFile) {
        "Configure a release keystore in ignored android/key.properties. Debug signing is prohibited for release."
    }
}

android {
    namespace = "com.example.mobile_app_project"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = configuredAppId ?: "com.example.mobile_app_project"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) create("release") {
            storeFile = rootProject.file(signingValues.getProperty("storeFile"))
            storePassword = signingValues.getProperty("storePassword")
            keyAlias = signingValues.getProperty("keyAlias")
            keyPassword = signingValues.getProperty("keyPassword")
        }
    }
    buildTypes {
        release {
            isDebuggable = false
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

flutter {
    source = "../.."
}
