import java.util.Properties
import java.io.FileInputStream
import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ----------------------------------------------------------------------------
// Chargement des credentials de signature depuis android/key.properties
// (fichier gitignoré, généré par scripts/setup_keystore.sh)
// ----------------------------------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// ----------------------------------------------------------------------------
// Lecture des secrets côté natif depuis env.json (gitignored, à la racine du projet)
// Utilisé pour remplir les placeholders du AndroidManifest (Google Maps API key, etc.)
// Le Dart-side reçoit ces mêmes valeurs via `--dart-define-from-file=env.json`.
// ----------------------------------------------------------------------------
val envJsonFile = rootProject.file("../env.json")
@Suppress("UNCHECKED_CAST")
val envJson: Map<String, Any?> = if (envJsonFile.exists()) {
    JsonSlurper().parse(envJsonFile) as Map<String, Any?>
} else emptyMap()

android {
    namespace = "com.acoeffic.lexday"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Requis par flutter_local_notifications (utilise java.time)
        // pour fonctionner sur les Android < API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
        }
    }

    defaultConfig {
        applicationId = "com.acoeffic.lexday"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Placeholders consommés par AndroidManifest.xml.
        // Lus depuis env.json — vide en CI sans env.json (le build échouera
        // explicitement avec "no value for ${...} provided").
        manifestPlaceholders["GOOGLE_PLACES_API_KEY"] =
            (envJson["GOOGLE_PLACES_API_KEY"] as? String) ?: ""
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Si key.properties est présent on signe avec la clé d'upload,
            // sinon on tombe sur les clés debug (utile pour `flutter run --release`
            // sur un poste qui n'a pas le keystore — typiquement la CI ou un dev secondaire).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Polyfill JDK pour le core library desugaring (cf. compileOptions ci-dessus)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
