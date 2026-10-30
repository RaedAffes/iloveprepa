import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'auth_service.dart';

class CourseOrder {
  const CourseOrder({
    required this.id,
    required this.label,
    required this.amountDt,
    required this.payerPhone,
    required this.status,
    required this.createdAt,
    this.email,
    this.name,
  });

  final String id;
  final String label;
  final int amountDt;
  final String payerPhone;
  final String status;
  final String createdAt;
  final String? email;
  final String? name;

  String get statusLabel => switch (status) {
        'pending_payment' => 'En attente de paiement',
        'payment_claimed' => 'Paiement déclaré',
        'validated' => 'Validée',
        'rejected' => 'Refusée',
        _ => status,
      };

  factory CourseOrder.fromJson(Map<String, dynamic> json) {
    return CourseOrder(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      amountDt: (json['amountDt'] as num?)?.toInt() ?? 0,
      payerPhone: json['payerPhone'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      email: json['email'] as String?,
      name: json['name'] as String?,
    );
  }
}

class OrderService {
  Future<List<CourseOrder>> mine() => _list('/api/orders');

  Future<List<CourseOrder>> adminOrders(String status) =>
      _list('/api/admin/orders?status=$status');

  Future<CourseOrder> create({
    required String planCode,
    String? productCode,
    required String payerPhone,
    required bool payNow,
  }) async {
    final body = await _send('/api/orders', {
      'planCode': planCode,
      'productCode': productCode,
      'payerPhone': payerPhone,
      'payNow': payNow,
    });
    return CourseOrder.fromJson(body['order'] as Map<String, dynamic>);
  }

  Future<void> claimPaid(String orderId) async {
    await _send('/api/orders/claim', {'orderId': orderId});
  }

  Future<void> validate(String orderId) async {
    await _send('/api/admin/orders/validate', {'orderId': orderId});
  }

  Future<void> reject(String orderId) async {
    await _send('/api/admin/orders/reject', {'orderId': orderId});
  }

  Future<void> unclaim(String orderId) async {
    await _send('/api/admin/orders/unclaim', {'orderId': orderId});
  }

  Future<void> unvalidate(String orderId) async {
    await _send('/api/admin/orders/unvalidate', {'orderId': orderId});
  }

  Future<List<CourseOrder>> _list(String path) async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiService.apiBase}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _check(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['orders'] as List<dynamic>? ?? [])
        .map((e) => CourseOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _send(String path, Map<String, dynamic> payload) async {
    final token = await _token();
    final response = await http.post(
      Uri.parse('${ApiService.apiBase}$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    _check(response);
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<String> _token() async {
    final token = await AuthService.authToken();
    if (token == null) throw ApiException('Connectez-vous pour continuer.');
    return token;
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String code = '';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) code = body['error'] as String;
    } catch (_) {}
    if (code == 'phone') {
      throw ApiException('Entrez un numéro tunisien valide, par exemple 20 123 456.');
    }
    throw ApiException('Le serveur a répondu avec le code ${response.statusCode}');
  }
}
