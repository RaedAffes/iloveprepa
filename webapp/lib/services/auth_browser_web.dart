import 'dart:convert';
import 'dart:js_interop';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'api_service.dart';
import 'auth_user.dart';
import 'firebase_options.dart';

const _tokenKey = 'iprepa_session';

/// Reads a session token or an error code left in the URL fragment by the
/// worker, stores the token, and strips the fragment.
Future<String?> consumeRedirect() async {
  final current = Uri.parse(web.window.location.href);
  final params = Uri.splitQueryString(current.fragment);
  final token = params['auth_session'];
  final error = params['auth_error'];
  if (token != null && token.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    final cleaned = current.replace(fragment: '');
    web.window.history.replaceState(null, '', cleaned.toString());
  }
  final storedError = web.window.sessionStorage.getItem('iprepa_auth_error');
  if (storedError != null && storedError.isNotEmpty) {
    web.window.sessionStorage.removeItem('iprepa_auth_error');
  }
  if (token != null && token.isNotEmpty) return null;
  if (error != null && error.isNotEmpty) return error;
  return storedError;
}

Future<void> signIn() async {}

Future<AuthResult> signInWithGoogle() async {
  if (!FirebaseConfig.isConfigured) return _firebaseNotConfigured();
  try {
    await _ensureFirebase();
    final credential = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    return await _openSession(credential.user);
  } on FirebaseAuthException catch (err) {
    return AuthResult(error: _firebaseError(err.code));
  } catch (_) {
    return const AuthResult(error: 'La connexion a échoué. Réessayez.');
  }
}

Future<AuthResult> signInWithEmail(
  String email,
  String password,
  bool createAccount,
  String? givenName,
  String? familyName,
  String? faculty,
  String? phone,
) async {
  if (!FirebaseConfig.isConfigured) return _firebaseNotConfigured();
  try {
    await _ensureFirebase();
    final auth = FirebaseAuth.instance;
    final credential = createAccount
        ? await auth.createUserWithEmailAndPassword(email: email, password: password)
        : await auth.signInWithEmailAndPassword(email: email, password: password);
    final account = credential.user;
    final displayName = [givenName?.trim(), familyName?.trim()]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (createAccount && account != null && displayName.isNotEmpty) {
      await account.updateDisplayName(displayName);
    }
    final result = await _openSession(
      account,
      signup: createAccount,
      givenName: givenName,
      familyName: familyName,
      faculty: faculty,
      phone: phone,
    );
    if (result.needsVerification && account != null) {
      final sent = await _sendVerification(auth, account);
      return sent ?? result;
    }
    if (createAccount && result.user == null && account != null) {
      try {
        await account.delete();
      } catch (_) {}
    }
    return result;
  } on FirebaseAuthException catch (err) {
    return AuthResult(error: _firebaseError(err.code));
  } catch (_) {
    return const AuthResult(error: 'La connexion a échoué. Réessayez.');
  }
}

AuthResult _firebaseNotConfigured() {
  return const AuthResult(
    error: "Firebase n'est pas encore configuré pour cette application.",
  );
}

Future<AuthResult> confirmEmail() async {
  if (!FirebaseConfig.isConfigured) return _firebaseNotConfigured();
  try {
    await _ensureFirebase();
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      return const AuthResult(error: 'Reconnectez-vous, puis confirmez le lien reçu par e-mail.');
    }
    await current.reload();
    final account = FirebaseAuth.instance.currentUser;
    if (account == null || !account.emailVerified) {
      return const AuthResult(
        needsVerification: true,
        error: "Le lien n'a pas encore été confirmé. Ouvrez l'e-mail, puis réessayez.",
      );
    }
    await account.getIdToken(true);
    return await _openSession(account);
  } on FirebaseAuthException catch (err) {
    return AuthResult(error: _firebaseError(err.code));
  } catch (_) {
    return const AuthResult(error: 'La confirmation a échoué. Réessayez.');
  }
}

Future<AuthResult> resendVerification() async {
  if (!FirebaseConfig.isConfigured) return _firebaseNotConfigured();
  try {
    await _ensureFirebase();
    final account = FirebaseAuth.instance.currentUser;
    if (account == null) {
      return const AuthResult(error: 'Reconnectez-vous pour renvoyer l’e-mail.');
    }
    final sent = await _sendVerification(FirebaseAuth.instance, account);
    return sent ??
        const AuthResult(notice: 'Un nouvel e-mail de vérification a été envoyé.');
  } on FirebaseAuthException catch (err) {
    return AuthResult(error: _firebaseError(err.code));
  } catch (_) {
    return const AuthResult(error: "L'e-mail n'a pas pu être renvoyé.");
  }
}

Future<AuthResult> sendPasswordReset(String email) async {
  final address = email.trim();
  if (address.isEmpty) {
    return const AuthResult(error: 'Entrez votre e-mail pour recevoir le lien.');
  }
  if (!FirebaseConfig.isConfigured) return _firebaseNotConfigured();
  try {
    await _ensureFirebase();
    final auth = FirebaseAuth.instance;
    await auth.setLanguageCode('fr');
    await auth.sendPasswordResetEmail(email: address);
    return const AuthResult(
      notice: 'Un e-mail pour choisir un nouveau mot de passe a été envoyé. Vérifiez aussi les courriers indésirables.',
    );
  } on FirebaseAuthException catch (err) {
    return AuthResult(error: _firebaseError(err.code));
  } catch (_) {
    return const AuthResult(error: "L'e-mail n'a pas pu être envoyé. Réessayez.");
  }
}

Future<AuthResult?> _sendVerification(FirebaseAuth auth, User account) async {
  try {
    await auth.setLanguageCode('fr');
    await account.sendEmailVerification();
    return null;
  } on FirebaseAuthException {
    return const AuthResult(
      needsVerification: true,
      error: "L'e-mail de vérification n'a pas pu être envoyé. Réessayez.",
    );
  }
}

Future<void> _ensureFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: FirebaseConfig.apiKey,
      appId: FirebaseConfig.appId,
      messagingSenderId: FirebaseConfig.messagingSenderId,
      projectId: FirebaseConfig.projectId,
      authDomain: FirebaseConfig.authDomain,
    ),
  );
}

Future<AuthResult> _openSession(
  User? account, {
  bool signup = false,
  String? givenName,
  String? familyName,
  String? faculty,
  String? phone,
}) async {
  if (account == null) {
    return const AuthResult(error: 'La connexion a échoué. Réessayez.');
  }
  final idToken = await account.getIdToken();
  if (idToken == null || idToken.isEmpty) {
    return const AuthResult(error: 'La connexion a échoué. Réessayez.');
  }
  final response = await web.window
      .fetch(
        '${ApiService.apiBase}/api/auth/firebase'.toJS,
        web.RequestInit(
          method: 'POST',
          headers: _jsonHeaders(),
          credentials: 'omit',
          body: jsonEncode({
            'idToken': idToken,
            'signup': signup,
            'givenName': givenName,
            'familyName': familyName,
            'faculty': faculty,
            'phone': phone,
          }).toJS,
        ),
      )
      .toDart;
  final text = (await response.text().toDart).toDart;
  if (!response.ok) {
    if (_errorCode(text) == 'email_unverified') {
      return const AuthResult(needsVerification: true);
    }
    return AuthResult(error: _workerError(text));
  }
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    return const AuthResult(error: 'La connexion a échoué. Réessayez.');
  }
  final token = decoded['token'];
  if (token is! String || token.isEmpty) {
    return const AuthResult(error: 'La connexion a échoué. Réessayez.');
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_tokenKey, token);
  final user = decoded['user'];
  if (user is Map) {
    return AuthResult(
      user: AuthUser.fromJson(user.map((key, value) => MapEntry('$key', value))),
    );
  }
  return AuthResult(user: await currentUser());
}

web.Headers _jsonHeaders() {
  final headers = web.Headers();
  headers.set('Content-Type', 'application/json');
  return headers;
}

String? _errorCode(String body) {
  try {
    final decoded = jsonDecode(body);
    final code = decoded is Map ? decoded['error'] : null;
    return code is String ? code : null;
  } catch (_) {
    return null;
  }
}

String _workerError(String body) {
  try {
    final code = _errorCode(body);
    if (code == 'not_configured') {
      return "Le serveur n'est pas encore relié à Firebase.";
    }
    if (code == 'email_in_use') {
      return 'Cet e-mail est déjà associé à un autre compte.';
    }
    if (code == 'profile') {
      return 'Ce compte Google ne partage pas d’adresse e-mail.';
    }
    if (code == 'phone') {
      return 'Entrez un numéro tunisien valide, par exemple 20 123 456.';
    }
    if (code == 'name') {
      return 'Entrez votre prénom et votre nom.';
    }
  } catch (_) {}
  return 'La connexion a échoué. Réessayez.';
}

String _firebaseError(String code) {
  switch (code) {
    case 'email-already-in-use':
      return 'Un compte existe déjà avec cet e-mail.';
    case 'invalid-email':
      return 'Cette adresse e-mail n’est pas valide.';
    case 'weak-password':
      return 'Le mot de passe doit contenir au moins 6 caractères.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'E-mail ou mot de passe incorrect.';
    case 'account-exists-with-different-credential':
      return 'Cet e-mail est déjà utilisé avec une autre méthode de connexion.';
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
      return 'Connexion annulée.';
    case 'popup-blocked':
      return 'Le navigateur a bloqué la fenêtre Google. Autorisez les pop-ups.';
    case 'too-many-requests':
      return 'Trop de tentatives. Réessayez dans un moment.';
    default:
      return 'La connexion a échoué. Réessayez.';
  }
}

/// The raw bearer token, for callers (like the admin screen) that need to
/// attach `Authorization: Bearer <token>` to their own requests.
Future<String?> authToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_tokenKey);
  return (token == null || token.isEmpty) ? null : token;
}

Future<AuthUser?> currentUser() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_tokenKey);
  if (token == null || token.isEmpty) return null;
  final result = await _request('/api/auth/me', token: token);
  if (result.unauthorized) {
    await prefs.remove(_tokenKey);
    return null;
  }
  final user = result.body?['user'];
  if (user is! Map) return null;
  return AuthUser.fromJson(user.map((key, value) => MapEntry('$key', value)));
}

Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(_tokenKey);
  if (token != null && token.isNotEmpty) {
    await _request('/api/auth/logout', token: token, method: 'POST');
  }
  await prefs.remove(_tokenKey);
}

Future<_AuthHttp> _request(
  String path, {
  required String token,
  String method = 'GET',
}) async {
  try {
    final headers = web.Headers();
    headers.set('Authorization', 'Bearer $token');
    final response = await web.window
        .fetch(
          '${ApiService.apiBase}$path'.toJS,
          web.RequestInit(method: method, headers: headers, credentials: 'omit'),
        )
        .toDart;
    if (response.status == 401) return const _AuthHttp.unauthorized();
    if (!response.ok) return const _AuthHttp.failed();
    final text = (await response.text().toDart).toDart;
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return _AuthHttp(decoded);
    if (decoded is Map) {
      return _AuthHttp(decoded.map((key, value) => MapEntry('$key', value)));
    }
    return const _AuthHttp.failed();
  } catch (_) {
    return const _AuthHttp.failed();
  }
}

class _AuthHttp {
  const _AuthHttp(this.body) : unauthorized = false;
  const _AuthHttp.unauthorized() : body = null, unauthorized = true;
  const _AuthHttp.failed() : body = null, unauthorized = false;

  final Map<String, dynamic>? body;
  final bool unauthorized;
}
