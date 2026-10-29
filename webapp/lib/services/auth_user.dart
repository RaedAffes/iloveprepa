/// Google account stored in D1 and returned by `/api/auth/me`.
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
      createdAt: json['createdAt'] as String?,
      lastLoginAt: json['lastLoginAt'] as String?,
    );
  }
}
