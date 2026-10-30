import 'auth_browser_stub.dart'
    if (dart.library.js_interop) 'auth_browser_web.dart'
    as browser;
import 'auth_user.dart';

export 'auth_user.dart';

/// Session token lives in the browser (first-party storage on iprepa.tn) and
/// is sent as a bearer token. The worker never puts it in the query string.
class AuthService {
  static Future<String?> consumeRedirect() => browser.consumeRedirect();

  static Future<void> signIn() => browser.signIn();

  static Future<AuthResult> signInWithGoogle() => browser.signInWithGoogle();

  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
    required bool createAccount,
    String? givenName,
    String? familyName,
    String? faculty,
    String? phone,
  }) => browser.signInWithEmail(
    email,
    password,
    createAccount,
    givenName,
    familyName,
    faculty,
    phone,
  );

  static Future<AuthResult> confirmEmail() => browser.confirmEmail();

  static Future<AuthResult> resendVerification() =>
      browser.resendVerification();

  static Future<AuthResult> sendPasswordReset(String email) =>
      browser.sendPasswordReset(email);

  static Future<AuthUser?> currentUser() => browser.currentUser();

  static Future<AuthResult> updateProfile({
    required String givenName,
    required String familyName,
    required String faculty,
    required String phone,
  }) => browser.updateProfile(givenName, familyName, faculty, phone);

  static Future<void> logout() => browser.logout();

  /// Raw bearer token for authenticated calls made outside this service
  /// (e.g. the admin "Manage access" screen).
  static Future<String?> authToken() => browser.authToken();
}
