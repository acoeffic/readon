# =============================================================================
# ProGuard / R8 rules — LexDay
# =============================================================================
# Référence : https://developer.android.com/build/shrink-code
# Toutes les règles consumer des plugins Flutter sont automatiquement incluses,
# ce fichier ne contient que les overrides spécifiques à notre app.
# =============================================================================

# -----------------------------------------------------------------------------
# Flutter
# -----------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# -----------------------------------------------------------------------------
# Google Play Core (split install) — résout les warnings R8 fréquents
# -----------------------------------------------------------------------------
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# -----------------------------------------------------------------------------
# Firebase (core + messaging)
# -----------------------------------------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Messaging — services et receivers ne doivent pas être renommés
-keep class * extends com.google.firebase.messaging.FirebaseMessagingService

# -----------------------------------------------------------------------------
# Google Sign-In
# -----------------------------------------------------------------------------
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# -----------------------------------------------------------------------------
# Google Maps
# -----------------------------------------------------------------------------
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }

# -----------------------------------------------------------------------------
# Google ML Kit Text Recognition (OCR)
# -----------------------------------------------------------------------------
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# -----------------------------------------------------------------------------
# WebView (webview_flutter + JS interface)
# -----------------------------------------------------------------------------
-keepattributes JavascriptInterface
-keep public class * implements android.webkit.WebViewClient
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# -----------------------------------------------------------------------------
# RevenueCat (purchases_flutter)
# -----------------------------------------------------------------------------
-keep class com.revenuecat.purchases.** { *; }
-dontwarn com.revenuecat.purchases.**

# -----------------------------------------------------------------------------
# Hive (utilise du code généré + reflection sur les TypeAdapter)
# -----------------------------------------------------------------------------
-keep class * extends hive.HiveObject { *; }
-keep @hive.HiveType class * { *; }
-keepclassmembers class * {
    @hive.HiveField <fields>;
}

# -----------------------------------------------------------------------------
# Supabase / GoTrue (utilise kotlinx.serialization en interne via les libs Kt)
# Laisse les classes annotées Serializable intactes
# -----------------------------------------------------------------------------
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep,includedescriptorclasses class **$$serializer { *; }
-keepclassmembers class * {
    *** Companion;
}
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}

# -----------------------------------------------------------------------------
# OkHttp / Okio (utilisés par http, supabase, firebase, etc.)
# -----------------------------------------------------------------------------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# -----------------------------------------------------------------------------
# Kotlin Coroutines
# -----------------------------------------------------------------------------
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# -----------------------------------------------------------------------------
# Generic — préserve les annotations et les noms des classes
# référencées par leur nom dans l'app (ex: deserialization, reflection)
# -----------------------------------------------------------------------------
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses, Exceptions
-keepclasseswithmembernames class * {
    native <methods>;
}

# Empêche R8 de virer les classes `MainActivity` Kotlin (sécurité)
-keep class com.acoeffic.lexday.** { *; }
