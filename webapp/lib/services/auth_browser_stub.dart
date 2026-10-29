import 'auth_user.dart';

/// VM / non-web fallback used by `flutter test`, where no browser exists.
Future<String?> consumeRedirect() async => null;

Future<void> signIn() async {}

Future<AuthResult> signInWithGoogle() async {
  return const AuthResult(error: 'La connexion est disponible dans le navigateur.');
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
  return const AuthResult(error: 'La connexion est disponible dans le navigateur.');
}

Future<AuthResult> confirmEmail() async {
  return const AuthResult(error: 'La connexion est disponible dans le navigateur.');
}

Future<AuthResult> resendVerification() async {
  return const AuthResult(error: 'La connexion est disponible dans le navigateur.');
}

Future<AuthResult> sendPasswordReset(String email) async {
  return const AuthResult(error: 'La connexion est disponible dans le navigateur.');
}

Future<AuthUser?> currentUser() async => null;

Future<void> logout() async {}
