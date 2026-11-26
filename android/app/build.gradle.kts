import com.android.build.api.variant.FilterConfiguration
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (gitignored) points at the keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "io.github.wladikrin.grain"
    // permission_handler_android 14.x requires compiling against SDK 37.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Native libraries stored compressed: MapLibre's 11 MB library makes the
    // download about a third smaller. Android extracts them on install, so
    // the installed size grows by about as much.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    defaultConfig {
        applicationId = "io.github.wladikrin.grain"
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // The build number from pubspec.yaml; the APKs get grainVersionCode()
        // (androidComponents below), not this value.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                fun key(name: String): String =
                    requireNotNull(keystoreProperties.getProperty(name)) {
                        "android/key.properties lacks $name"
                    }
                val (path, pass, alias, keyPass) =
                    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").map(::key)
                val store = file(path)
                require(store.exists()) {
                    "android/key.properties: storeFile ${store.path} does not exist"
                }
                storeFile = store
                storePassword = pass
                keyAlias = alias
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        release {
            // No key.properties: debug-signed so `flutter build apk` installs. F-Droid and reproducibility checks build unsigned with GRAIN_UNSIGNED=1 ./gradlew :app:assembleRelease. Never commit key.properties or the keystore (both gitignored).
            signingConfig = when {
                System.getenv("GRAIN_UNSIGNED") == "1" -> null
                hasKeystore -> signingConfigs.getByName("release")
                else -> signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// versionCode = build number * 1000 + ABI code, ABI last as F-Droid wants it:
// build 5 gives 5001 (armeabi-v7a), 5002 (arm64-v8a) and 5004 (x86_64); an
// APK without an ABI filter (no --split-per-abi) gets 5000. This replaces
// Flutter's own split scheme (1000 * ABI + build): Flutter sets the per-ABI
// versionCode in its onVariants callback, registered when the plugin is
// applied in plugins {}, and this callback runs after it, so it wins. The
// recipe's versionCodes and VercodeOperation must follow the same scheme
// (test/release/version_code_test.dart, docs/release.md).
val grainAbiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 4)

fun grainVersionCode(build: Int, abi: String?): Int {
    require(build in 1..2_000_000) { "build number $build: versionCode would overflow" }
    val abiCode = if (abi == null) 0 else requireNotNull(grainAbiCodes[abi]) { "no versionCode for ABI $abi" }
    return build * 1000 + abiCode
}

androidComponents {
    onVariants { variant ->
        val build = flutter.versionCode
        variant.outputs.forEach { output ->
            val abi = output.filters.find { it.filterType == FilterConfiguration.FilterType.ABI }?.identifier
            output.versionCode.set(grainVersionCode(build, abi))
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

dependencies {
    implementation("com.google.zxing:core:3.5.4")
    // MapNetPlugin sets the HTTP client MapLibre loads the map with: the
    // versions maplibre_gl brings (test/android/maplibre_versions_test.dart).
    implementation("org.maplibre.gl:android-sdk-opengl:13.7.1")
    implementation("com.squareup.okhttp3:okhttp:5.4.0")
    testImplementation("junit:junit:4.13.2")
}
