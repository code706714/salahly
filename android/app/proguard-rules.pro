# Flutter's own rules are added by the Flutter Gradle plugin, and the
# plugins this app uses (secure storage, geolocator, speech, sqlite) ship
# their own consumer rules. Only warnings from optional annotation
# libraries are silenced here.
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn com.google.errorprone.annotations.**
