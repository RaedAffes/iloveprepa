import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Google sign-in control for the blue library header.
class AuthButton extends StatefulWidget {
  const AuthButton({super.key, this.compact = false});

  /// Icon only, for the narrow header.
  final bool compact;

  @override
  State<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<AuthButton> {
  AuthUser? _user;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final error = await AuthService.consumeRedirect();
    final user = await AuthService.currentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _ready = true;
    });
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error))),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox(width: 36, height: 36);
    }

    final user = _user;
    if (user == null) {
      return _SignInButton(compact: widget.compact, onPressed: AuthService.signIn);
    }

    final initial = user.label.isEmpty ? '?' : user.label.characters.first.toUpperCase();
    return PopupMenuButton<String>(
      tooltip: user.label,
      offset: const Offset(0, 44),
      color: Colors.white,
      onSelected: (value) {
        if (value == 'logout') _logout();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.label,
                style: const TextStyle(
                  color: Color(0xFF1B1B1B),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Text('Se déconnecter'),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UserAvatar(initial: initial, picture: user.picture),
          if (!widget.compact) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                user.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.initial, this.picture});

  final String initial;
  final String? picture;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Colors.white,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Color(0xFF1B3FA0),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 32,
        height: 32,
        child: picture == null
            ? fallback
            : Image.network(
                picture!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                // An <img> can show a Google profile photo. Flutter's normal
                // network image is blocked because that host sends no CORS header.
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.compact, required this.onPressed});

  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Se connecter avec Google',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _GoogleMark(),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'Connexion',
                    style: TextStyle(
                      color: Color(0xFF1B3FA0),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontWeight: FontWeight.w800,
        fontSize: 16,
        height: 1,
      ),
    );
  }
}

String _errorMessage(String code) {
  switch (code) {
    case 'not_configured':
      return "La connexion Google n'est pas encore configurée.";
    case 'access_denied':
      return 'Connexion annulée.';
    case 'email_in_use':
      return 'Cet e-mail est déjà associé à un autre compte.';
    default:
      return 'La connexion a échoué. Réessayez.';
  }
}
