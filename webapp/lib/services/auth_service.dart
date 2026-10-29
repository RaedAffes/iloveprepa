import 'auth_browser_stub.dart'
    if (dart.library.js_interop) 'auth_browser_web.dart' as browser;
import 'auth_user.dart';

export 'auth_user.dart';

/// Session token lives in the browser (first-party storage on iprepa.tn) and
/// is sent as a bearer token. The worker never puts it in the query string.
class AuthService {
  static Future<String?> consumeRedirect() => browser.consumeRedirect();

  static Future<void> signIn() => browser.signIn();

  static Future<AuthUser?> currentUser() => browser.currentUser();

  static Future<void> logout() => browser.logout();
}
