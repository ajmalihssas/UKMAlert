import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('Only web platform is supported by this app.');
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
}
