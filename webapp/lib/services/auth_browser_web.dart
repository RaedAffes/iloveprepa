import 'dart:convert';
import 'dart:js_interop';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'api_service.dart';
import 'auth_user.dart';

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

Future<void> signIn() async {
  final here = Uri.parse(web.window.location.href).replace(fragment: '');
  final start = Uri.parse('${ApiService.apiBase}/api/auth/google').replace(
    queryParameters: {'return_to': here.toString()},
  );
  web.window.location.assign(start.toString());
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
