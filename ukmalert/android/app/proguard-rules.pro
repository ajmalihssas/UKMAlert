# Flutter — the Flutter Gradle plugin contributes its own rules automatically.
# Firebase — Firebase AAR manifests contribute rules automatically.

# Google Nearby Connections (nearby_connections package)
-keep class com.google.android.gms.nearby.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep annotation classes used by Play Services
-keepattributes *Annotation*

# Geolocator uses reflection-based plugin registration
-keep class com.baseflow.geolocator.** { *; }

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# Suppress warnings for missing Google Play Ads classes (not used in this app)
-dontwarn com.google.android.gms.ads.**
