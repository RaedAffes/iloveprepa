import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/document_item.dart';

class ApiService {
  static const String apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://iloveprepa-r2.ilovepreparatoire.workers.dev',
  );

  Future<List<DocumentItem>> fetchDocuments() async {
    final uri = Uri.parse('$apiBase/api/files').replace(
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
    );
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
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

  Uri viewUri(DocumentItem item) =>
      Uri.parse('$apiBase/api/view/${Uri.encodeComponent(item.name)}');

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
