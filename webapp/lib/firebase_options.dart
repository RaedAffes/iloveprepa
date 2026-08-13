import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'This app is configured for web only.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBlKp172V4Ty1nXogUl9BGHkjoXdZ5rJNE',
    appId: '1:462732048118:web:1f8cea3d6220cb9c571ed7',
    messagingSenderId: '462732048118',
    projectId: 'iprepa',
    authDomain: 'iprepa.firebaseapp.com',
    storageBucket: 'iprepa.firebasestorage.app',
    measurementId: 'G-5DTE2FZR8E',
  );
}
