import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentItem {
  const RecentItem({required this.name, required this.openedAt});

  final String name;
  final DateTime openedAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'openedAt': openedAt.millisecondsSinceEpoch,
  };

  factory RecentItem.fromJson(Map<String, dynamic> json) => RecentItem(
    name: json['name'] as String? ?? '',
    openedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['openedAt'] as num?)?.toInt() ?? 0,
    ),
  );
}

class RecentStore {
  static const String _key = 'recent_files_v1';

  static Future<List<RecentItem>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => RecentItem.fromJson((e as Map).cast<String, dynamic>()))
          .where((e) => e.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<RecentItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([for (final item in items) item.toJson()]),
      );
    } catch (_) {}
  }
}
