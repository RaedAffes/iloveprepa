import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/document_item.dart';

class ApiService {
  static const String apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://iloveprepa-r2.ilovepreparatoire.workers.dev',
  );

  Future<List<DocumentItem>> fetchDocuments() async {
    final uri = Uri.parse('$apiBase/api/files');
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
      Uri.parse('$apiBase/api/download?file=${Uri.encodeComponent(item.name)}');

  Uri downloadUri(DocumentItem item) => Uri.parse(
    '$apiBase/api/download?file=${Uri.encodeComponent(item.name)}&download=1',
  );
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
