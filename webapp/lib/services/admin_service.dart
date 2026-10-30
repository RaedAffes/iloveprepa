import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'auth_service.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.name,
    this.givenName,
    this.familyName,
    this.faculty,
    this.phone,
    this.emailVerified = false,
    this.createdAt,
    this.lastLoginAt,
    required this.role,
    required this.entitlements,
  });

  final String id;
  final String email;
  final String? name;
  final String? givenName;
  final String? familyName;
  final String? faculty;
  final String? phone;
  final bool emailVerified;
  final String? createdAt;
  final String? lastLoginAt;
  final String role;
  final List<String> entitlements;

  String get label => (name != null && name!.trim().isNotEmpty) ? name! : email;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      givenName: json['givenName'] as String?,
      familyName: json['familyName'] as String?,
      faculty: json['faculty'] as String?,
      phone: json['phone'] as String?,
      emailVerified: json['emailVerified'] == true,
      createdAt: json['createdAt'] as String?,
      lastLoginAt: json['lastLoginAt'] as String?,
      role: json['role'] as String? ?? 'free',
      entitlements: (json['entitlements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Talks to the Worker's `/api/admin/*` endpoints. Every call requires the
/// signed-in user to have the `admin` role server-side; the server re-checks
/// this on every request, so there is no client-only gate to bypass.
class AdminService {
  Future<List<AdminUser>> searchUsers(String query) async {
    final token = await AuthService.authToken();
    if (token == null) throw ApiException('Non authentifié.');
    final uri = Uri.parse('${ApiService.apiBase}/api/admin/users').replace(
      queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 403) {
      throw ApiException('Accès réservé aux administrateurs.');
    }
    if (response.statusCode != 200) {
      throw ApiException('Le serveur a répondu avec le code ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['users'] as List<dynamic>? ?? [])
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> setEntitlement({
    required String userId,
    required String productCode,
    required bool grant,
  }) async {
    final token = await AuthService.authToken();
    if (token == null) throw ApiException('Non authentifié.');
    final response = await http.post(
      Uri.parse('${ApiService.apiBase}/api/admin/entitlements'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userId': userId,
        'productCode': productCode,
        'action': grant ? 'grant' : 'revoke',
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException('Le serveur a répondu avec le code ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['entitlements'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
  }
}
