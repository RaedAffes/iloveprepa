import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/document_item.dart';

class ApiService {
  static const String apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://iloveprepa-r2.ilovepreparatoire.workers.dev',
  );

  Future<List<DocumentItem>> fetchDocuments() async {
    // No cache-buster on purpose: the worker serves /api/files with a 5-min
    // Cache-Control, so repeated loads reuse the browser/CDN copy instead of
    // listing the whole R2 bucket (a Class A op) every time.
    final uri = Uri.parse('$apiBase/api/files');
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      // The worker pauses itself when a free-tier usage limit is reached
      // (503 + locked). Surface that as a maintenance state in the app
      // instead of a raw server-code error.
      if (response.statusCode == 503) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['locked'] == true) {
            throw ServiceLockedException(
              (body['error'] as String?) ?? 'Service temporarily paused',
            );
          }
        } catch (e) {
          if (e is ServiceLockedException) rethrow;
        }
      }
      // Cloudflare throttles requests (daily quota / burst) with a 429.
      // Show a friendly "try again later" instead of a raw server code.
      if (response.statusCode == 429) {
        throw RateLimitedException(
          'Le serveur est temporairement surchargé. Merci de réessayer '
          'dans quelques instants.',
        );
      }
      throw ApiException(
        'Le serveur a répondu avec le code ${response.statusCode}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final files =
        (body['files'] as List<dynamic>? ?? [])
            .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
    return files;
  }

  /// Short view URL ending in the file name (nice browser tab), with the exact
  /// R2 key carried in `f` so identical file names never collide. The Worker
  /// falls back to `f` when present, and to the URL index otherwise.
  Uri viewUri(DocumentItem item) {
    final base = item.name.split('/').last;
    return Uri.parse(
      '$apiBase/api/view/${Uri.encodeComponent(base)}'
      '?f=${Uri.encodeComponent(item.name)}',
    );
  }

  Uri downloadUri(DocumentItem item) => Uri.parse(
    '$apiBase/api/download?file=${Uri.encodeComponent(item.name)}&download=1',
  );

  /// Sends a contact-form message to ilovepreparatoire@gmail.com via EmailJS.
  /// The template (Contact Us) maps {name, email, message} placeholders and
  /// replies to the visitor's address.
  static const String emailJsServiceId = 'iloveprepa';
  static const String emailJsTemplateId = 'template_q8mygrz';
  static const String emailJsPublicKey = 'aUr1ndO6jKpSWwcfq';

  static final RegExp _emailFormatRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Checks (via the Worker) that the address's domain has mail (MX) records,
  /// which rejects fake addresses like `x@a-domain-that-does-not-exist.xyz`.
  /// Fails open on network / server errors so a real message is never blocked
  /// by a temporary infrastructure problem.
  Future<bool> validateEmail(String email) async {
    final trimmed = email.trim();
    if (!_emailFormatRe.hasMatch(trimmed)) return false;
    try {
      final uri = Uri.parse('$apiBase/api/validate-email').replace(
        queryParameters: {'email': trimmed},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return true;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['ok'] == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> sendContact({
    required String name,
    required String email,
    required String message,
  }) async {
    final uri = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'service_id': emailJsServiceId,
            'template_id': emailJsTemplateId,
            'user_id': emailJsPublicKey,
            'template_params': {
              'name': name,
              'email': email,
              'message': message,
            },
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException(
        "Impossible d'envoyer le message (code ${response.statusCode}). "
        'Veuillez réessayer.',
      );
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Thrown when the backend has paused the whole service (free-tier usage
/// safety lock). The app shows a friendly maintenance state for this instead
/// of the generic server-error screen.
class ServiceLockedException implements Exception {
  final String message;
  ServiceLockedException(this.message);

  @override
  String toString() => message;
}

/// Thrown when Cloudflare throttles requests (daily quota / burst, HTTP 429).
/// The app shows the orange "service temporarily overburdened" state for it.
class RateLimitedException implements Exception {
  final String message;
  RateLimitedException(this.message);

  @override
  String toString() => message;
}
