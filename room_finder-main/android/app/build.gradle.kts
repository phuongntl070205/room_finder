import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ngocvy.room_finder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.ngocvy.room_finder"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            pickFirsts += listOf(
                "lib/*/libflutter.so",
                "lib/*/libVkLayer_khronos_validation.so"
            )
        }
    }
}

val localProperties =
    Properties().apply {
        rootProject.file("local.properties").inputStream().use { load(it) }
    }
val flutterSdkPath =
    localProperties.getProperty("flutter.sdk")
        ?: error("flutter.sdk not set in android/local.properties")

fun registerFlutterEngineJniLibs(buildTypeName: String, engineMode: String) {
    val capitalizedBuildType =
        buildTypeName.replaceFirstChar {
            if (it.isLowerCase()) it.titlecase() else it.toString()
        }
    val modeSuffix = if (engineMode == "debug") "" else "-$engineMode"
    val engineFolders =
        listOf(
            "android-arm$modeSuffix",
            "android-arm64$modeSuffix",
            "android-x64$modeSuffix"
        )
    val outputDir = layout.buildDirectory.dir("generated/flutter_engine_jni/$buildTypeName")
    val extractTask =
        tasks.register<Copy>("extract${capitalizedBuildType}FlutterEngineJniLibs") {
            into(outputDir)
            includeEmptyDirs = false
            engineFolders.forEach { engineFolder ->
                val engineJar =
                    file("$flutterSdkPath/bin/cache/artifacts/engine/$engineFolder/flutter.jar")
                from(zipTree(engineJar)) {
                    include("lib/**/*.so")
                    eachFile {
                        path = path.removePrefix("lib/")
                    }
                }
            }
        }

    android.sourceSets.getByName(buildTypeName).jniLibs.srcDir(outputDir)
    tasks
        .matching {
            it.name == "merge${capitalizedBuildType}JniLibFolders" ||
                it.name == "merge${capitalizedBuildType}NativeLibs"
        }.configureEach {
            dependsOn(extractTask)
        }
}

registerFlutterEngineJniLibs("debug", "debug")
registerFlutterEngineJniLibs("profile", "profile")
registerFlutterEngineJniLibs("release", "release")

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
