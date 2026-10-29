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
    );
  }
}

class AuthResult {
  const AuthResult({this.user, this.error, this.notice, this.needsVerification = false});

  final AuthUser? user;
  final String? error;
  final String? notice;
  final bool needsVerification;
}
