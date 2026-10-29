import 'auth_user.dart';

/// VM / non-web fallback used by `flutter test`, where no browser exists.
Future<String?> consumeRedirect() async => null;

Future<void> signIn() async {}

Future<AuthUser?> currentUser() async => null;

Future<void> logout() async {}
