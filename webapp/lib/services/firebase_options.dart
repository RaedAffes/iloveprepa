/// Public web app settings for Firebase project `iprepa`.
/// These identify the project in the browser. They are not a server secret.
class FirebaseConfig {
  static const apiKey = 'AIzaSyBlKp172V4Ty1nXogUl9BGHkjoXdZ5rJNE';
  static const appId = '1:462732048118:web:1f8cea3d6220cb9c571ed7';
  static const messagingSenderId = '462732048118';
  static const projectId = 'iprepa';
  static const authDomain = 'iprepa.firebaseapp.com';

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty &&
      authDomain.isNotEmpty;
}
