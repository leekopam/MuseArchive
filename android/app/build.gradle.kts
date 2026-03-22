import java.util.Properties

val defaultAndroidPackage = "com.example.my_album_app"
val configuredNamespace =
    providers.gradleProperty("musearchive.namespace").orNull?.trim()
val configuredApplicationId =
    providers.gradleProperty("musearchive.applicationId").orNull?.trim()
val requireReleaseSigning =
    providers.gradleProperty("musearchive.requireReleaseSigning")
        .orNull
        ?.equals("true", ignoreCase = true) == true
val resolvedApplicationId = configuredApplicationId?.takeIf { it.isNotEmpty() }
    ?: defaultAndroidPackage
val resolvedNamespace = configuredNamespace?.takeIf { it.isNotEmpty() }
    ?: resolvedApplicationId

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val releaseStoreFilePath = keystoreProperties.getProperty("storeFile")?.trim()
val releaseStoreFile = releaseStoreFilePath
    ?.takeIf { it.isNotEmpty() }
    ?.let { rootProject.file(it) }
val hasReleaseSigning =
    releaseStoreFile?.exists() == true &&
    listOf("storePassword", "keyAlias", "keyPassword").all {
        !keystoreProperties.getProperty(it).isNullOrBlank()
    }

if (requireReleaseSigning && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is required, but android/key.properties is missing " +
            "or incomplete. Fill android/key.properties from " +
            "android/key.properties.example before building a signed release.",
    )
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = resolvedNamespace
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = resolvedApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Use release signing when key.properties is configured; otherwise
            // keep the debug fallback so local release builds still work.
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
