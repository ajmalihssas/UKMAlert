import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAibaRo-VyaDFC1_R-m3pmhB9qoJiKcadA',
    appId: '1:773835997973:web:f4c9a8c47345aa00e11f1c',
    messagingSenderId: '773835997973',
    projectId: 'ukmalert',
    authDomain: 'ukmalert.firebaseapp.com',
    storageBucket: 'ukmalert.firebasestorage.app',
    measurementId: 'G-8FZX2QMSZ5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyArK4hYLZ9ohmkPi16GcBLo1S565SyZQAM',
    appId: '1:773835997973:android:925cc0b801ed93f6e11f1c',
    messagingSenderId: '773835997973',
    projectId: 'ukmalert',
    storageBucket: 'ukmalert.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAwBTwggvMnb0QEid-242EsJh25xSEjcFw',
    appId: '1:773835997973:ios:90083f9e13773c02e11f1c',
    messagingSenderId: '773835997973',
    projectId: 'ukmalert',
    storageBucket: 'ukmalert.firebasestorage.app',
    iosBundleId: 'com.example.ukmalert',
  );

}