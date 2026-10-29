import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../screens/profile_screen.dart';
import '../services/auth_service.dart';
import 'landing/landing_colors.dart' as landing;

/// One session for every sidebar copy (the drawer and the wide rail).
class _AuthSession extends ChangeNotifier {
  _AuthSession._();

  static final instance = _AuthSession._();

  AuthUser? user;
  bool ready = false;
  String? _error;
  bool _errorClaimed = false;
  Future<void>? _pending;

  Future<void> boot() => _pending ??= _load();

  Future<void> _load() async {
    final error = await AuthService.consumeRedirect();
    user = await AuthService.currentUser();
    ready = true;
    _error = error;
    notifyListeners();
  }

  /// First caller shows the redirect error. Later callers get nothing.
  String? claimError() {
    if (_errorClaimed) return null;
    _errorClaimed = true;
    return _error;
  }

  void setUser(AuthUser? next) {
    user = next;
    ready = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.logout();
    user = null;
    notifyListeners();
  }
}

/// Account row pinned to the bottom of the library sidebar.
class AuthButton extends StatefulWidget {
  const AuthButton({super.key, this.onOpenProfile});

  final void Function(AuthUser user)? onOpenProfile;

  @override
  State<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<AuthButton> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _AuthSession.instance.boot().then((_) {
      if (!mounted) return;
      final error = _AuthSession.instance.claimError();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(error))),
        );
      }
    });
  }

  Future<void> _openSignIn() async {
    final user = await showDialog<AuthUser>(
      context: context,
      builder: (context) => const _SignInDialog(),
    );
    if (user == null) return;
    _AuthSession.instance.setUser(user);
  }

  Future<void> _openAccount() async {
    final user = _AuthSession.instance.user;
    if (user == null || !mounted) return;
    setState(() => _open = true);
    final action = await showAccountMenu(context, user);
    if (action == AccountMenuAction.logout) await _AuthSession.instance.logout();
    if (action == AccountMenuAction.profile) widget.onOpenProfile?.call(user);
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _AuthSession.instance,
      builder: (context, _) {
        final session = _AuthSession.instance;
        if (!session.ready) {
          return const SizedBox(height: 48);
        }

        final user = session.user;
        if (user == null) {
          return _SidebarAccountTile(
            tooltip: 'Se connecter',
            selected: false,
            onTap: _openSignIn,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: landing.AppColors.midBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Connexion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(AppColors.white).copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return _SidebarAccountTile(
          tooltip: 'Profil',
          selected: _open,
          onTap: _openAccount,
          child: Row(
            children: [
              AccountAvatar(
                initial: accountInitial(user.label),
                picture: user.picture,
                inverted: true,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(AppColors.white).copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'Gratuit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metadata(Colors.white70).copyWith(height: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarAccountTile extends StatefulWidget {
  const _SidebarAccountTile({
    required this.tooltip,
    required this.onTap,
    required this.selected,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onTap;
  final bool selected;
  final Widget child;

  @override
  State<_SidebarAccountTile> createState() => _SidebarAccountTileState();
}

class _SidebarAccountTileState extends State<_SidebarAccountTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hover || widget.selected;
    return Tooltip(
      message: widget.tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.navR,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hover = value),
          borderRadius: AppRadius.navR,
          hoverColor: Colors.transparent,
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: AppRadius.navR,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _SignInDialog extends StatefulWidget {
  const _SignInDialog();

  @override
  State<_SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<_SignInDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _givenName = TextEditingController();
  final _familyName = TextEditingController();
  final _faculty = TextEditingController();
  bool _create = false;
  bool _busy = false;
  String? _error;
  String? _pendingEmail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _givenName.dispose();
    _familyName.dispose();
    _faculty.dispose();
    super.dispose();
  }

  Future<void> _finish(Future<AuthResult> attempt) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await attempt;
    if (!mounted) return;
    if (result.user != null) {
      Navigator.of(context).pop(result.user);
      return;
    }
    if (result.needsVerification) {
      setState(() {
        _busy = false;
        _pendingEmail = _email.text.trim();
        _error = result.error;
      });
      return;
    }
    setState(() {
      _busy = false;
      _error = result.error ?? 'La connexion a échoué. Réessayez.';
    });
  }

  Future<void> _confirmEmail() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await AuthService.confirmEmail();
    if (!mounted) return;
    if (result.user != null) {
      Navigator.of(context).pop(result.user);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.error ?? "Le lien n'a pas encore été confirmé.";
    });
  }

  Future<void> _resendEmail() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await AuthService.resendVerification();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.error;
      if (result.notice != null) _error = null;
    });
    if (result.notice != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.notice!)));
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Entrez votre e-mail pour recevoir le lien.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await AuthService.sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.error;
    });
    if (result.notice != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.notice!)));
    }
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Entrez votre e-mail et votre mot de passe.');
      return;
    }
    String? givenName;
    String? familyName;
    String? faculty;
    if (_create) {
      givenName = _givenName.text.trim();
      familyName = _familyName.text.trim();
      faculty = _faculty.text.trim();
      if (givenName.isEmpty || familyName.isEmpty) {
        setState(() => _error = 'Entrez votre prénom et votre nom.');
        return;
      }
    }
    await _finish(
      AuthService.signInWithEmail(
        email: email,
        password: password,
        createAccount: _create,
        givenName: givenName,
        familyName: familyName,
        faculty: faculty == null || faculty.isEmpty ? null : faculty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        _pendingEmail != null
            ? 'Confirmez votre e-mail'
            : (_create ? 'Créer un compte' : 'Connexion'),
      ),
      content: _pendingEmail != null
          ? SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Un lien a été envoyé à $_pendingEmail. Ouvrez-le pour confirmer votre adresse, puis revenez ici. Pensez à vérifier les courriers indésirables.',
                    style: const TextStyle(color: Color(0xFF1B1B1B), height: 1.4),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFFC4432F))),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
        child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => _finish(AuthService.signInWithGoogle()),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1B1B1B),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF1B3FA0),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Continuer avec Google'),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'ou',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            if (_create) ...[
              TextField(
                controller: _givenName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _familyName,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _faculty,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Faculté',
                  hintText: 'Facultatif',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              onSubmitted: (_) => _busy ? null : _submit(),
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            if (!_create)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1B3FA0),
                    padding: const EdgeInsets.only(top: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Mot de passe oublié'),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFC4432F))),
            ],
          ],
        ),
        ),
      ),
      actions: _pendingEmail != null
          ? [
              TextButton(
                onPressed: _busy ? null : _resendEmail,
                child: const Text('Renvoyer l’e-mail'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B3FA0)),
                onPressed: _busy ? null : _confirmEmail,
                child: Text(_busy ? 'Patientez…' : 'J’ai confirmé'),
              ),
            ]
          : [
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _create = !_create;
                    _error = null;
                  }),
          child: Text(_create ? 'J’ai déjà un compte' : 'Créer un compte'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B3FA0)),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Patientez…' : (_create ? 'Créer' : 'Se connecter')),
        ),
      ],
    );
  }
}

String _errorMessage(String code) {
  switch (code) {
    case 'not_configured':
      return "La connexion n'est pas encore configurée.";
    case 'access_denied':
      return 'Connexion annulée.';
    case 'email_in_use':
      return 'Cet e-mail est déjà associé à un autre compte.';
    default:
      return 'La connexion a échoué. Réessayez.';
  }
}
