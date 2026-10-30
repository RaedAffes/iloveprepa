/// Account stored in D1 and returned by `/api/auth/me`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    this.name,
    this.givenName,
    this.familyName,
    this.picture,
    this.locale,
    this.faculty,
    this.phone,
    this.createdAt,
    this.lastLoginAt,
    this.role = 'free',
    this.entitlements = const [],
  });

  final String id;
  final String email;
  final bool emailVerified;
  final String? name;
  final String? givenName;
  final String? familyName;
  final String? picture;
  final String? locale;
  final String? faculty;
  final String? phone;
  final String? createdAt;
  final String? lastLoginAt;

  /// 'free' | 'admin'.
  final String role;

  /// Active premium product codes, e.g. 'y1_s1', 'y1_s2', 'y2_s1', 'y2_s2'.
  final List<String> entitlements;

  bool get isAdmin => role == 'admin';
  bool get isPremium => entitlements.isNotEmpty;

  /// Short status label shown next to the user's name in the UI.
  String get planLabel {
    if (isAdmin) return 'Admin';
    return isPremium ? 'Premium' : 'Gratuit';
  }

  String get label {
    final display = name?.trim();
    if (display != null && display.isNotEmpty) return display;
    return email;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      emailVerified: json['emailVerified'] == true,
      name: json['name'] as String?,
      givenName: json['givenName'] as String?,
      familyName: json['familyName'] as String?,
      picture: json['picture'] as String?,
      locale: json['locale'] as String?,
      faculty: json['faculty'] as String?,
      phone: json['phone'] as String?,
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

/// The four sellable products: one per semester, across both years.
enum PremiumProduct { y1s1, y1s2, y2s1, y2s2 }

extension PremiumProductCode on PremiumProduct {
  String get code => switch (this) {
        PremiumProduct.y1s1 => 'y1_s1',
        PremiumProduct.y1s2 => 'y1_s2',
        PremiumProduct.y2s1 => 'y2_s1',
        PremiumProduct.y2s2 => 'y2_s2',
      };

  String get label => switch (this) {
        PremiumProduct.y1s1 => 'MP1 Semestre 1',
        PremiumProduct.y1s2 => 'MP1 Semestre 2',
        PremiumProduct.y2s1 => 'MP2 Semestre 1',
        PremiumProduct.y2s2 => 'MP2 Semestre 2',
      };
}

class AuthResult {
  const AuthResult({this.user, this.error, this.notice, this.needsVerification = false});

  final AuthUser? user;
  final String? error;
  final String? notice;
  final bool needsVerification;
}
