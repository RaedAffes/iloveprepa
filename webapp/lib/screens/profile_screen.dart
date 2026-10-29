import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../services/auth_user.dart';
import '../widgets/landing/landing_colors.dart' as landing;

/// First letter of an account label, for the avatar fallback.
String accountInitial(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

enum AccountMenuAction { profile, logout }

/// Account menu anchored above the sidebar profile row.
Future<AccountMenuAction?> showAccountMenu(BuildContext anchorContext, AuthUser user) {
  final box = anchorContext.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return Future.value();
  final origin = box.localToGlobal(Offset.zero);
  final anchorSize = box.size;

  return showGeneralDialog<AccountMenuAction>(
    context: anchorContext,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    // A fully transparent barrier can miss taps. This is invisible in practice.
    barrierColor: const Color(0x01000000),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondary) {
      return _AccountMenuOverlay(
        origin: origin,
        anchorSize: anchorSize,
        user: user,
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AccountMenuOverlay extends StatelessWidget {
  const _AccountMenuOverlay({
    required this.origin,
    required this.anchorSize,
    required this.user,
  });

  final Offset origin;
  final Size anchorSize;
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    const gap = AppSpacing.sm;

    var width = anchorSize.width.clamp(220.0, 280.0).toDouble();
    final maxWidth = media.width - AppSpacing.lg;
    if (width > maxWidth) width = maxWidth;
    var left = origin.dx;
    if (left + width > media.width - AppSpacing.sm) {
      left = media.width - AppSpacing.sm - width;
    }
    if (left < AppSpacing.sm) left = AppSpacing.sm;

    final spaceAbove = origin.dy - padding.top - gap;
    final spaceBelow =
        media.height - (origin.dy + anchorSize.height) - padding.bottom - gap;
    final openAbove = spaceAbove >= 180 || spaceAbove >= spaceBelow;
    final maxHeight = (openAbove ? spaceAbove : spaceBelow).clamp(140.0, 480.0);

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned(
            left: left,
            width: width,
            bottom: openAbove ? media.height - origin.dy + gap : null,
            top: openAbove ? null : origin.dy + anchorSize.height + gap,
            child: _AccountCard(user: user, maxHeight: maxHeight),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.maxHeight});

  final AuthUser user;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.button),
        boxShadow: AppShadows.md,
      ),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      AccountAvatar(
                        initial: accountInitial(user.label),
                        picture: user.picture,
                        size: 36,
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
                              style: AppTypography.tileTitle(),
                            ),
                            Text(
                              'Gratuit',
                              style: AppTypography.metadata(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _MenuRow(
                  icon: Icons.person_outline,
                  label: 'Profil',
                  onTap: () => Navigator.of(context).pop(AccountMenuAction.profile),
                ),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                _MenuRow(
                  icon: Icons.logout_rounded,
                  label: 'Se déconnecter',
                  onTap: () => Navigator.of(context).pop(AccountMenuAction.logout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.navR,
        hoverColor: AppColors.hover,
        splashColor: AppColors.hover,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.ink),
              const SizedBox(width: AppSpacing.md),
              Text(
                label,
                style: AppTypography.body(AppColors.ink).copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile details shown in the main area, beside the open sidebar.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user, required this.onBack});

  final AuthUser user;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Prénom', user.givenName?.trim() ?? ''),
      ('Nom', user.familyName?.trim() ?? ''),
      ('E-mail', user.email.trim()),
      ('Faculté', user.faculty?.trim() ?? ''),
      ('Téléphone', user.phone?.trim() ?? ''),
    ].where((row) => row.$2.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onBack,
            tooltip: 'Retour',
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: AccountAvatar(
            initial: accountInitial(user.label),
            picture: user.picture,
            size: 72,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(user.label, textAlign: TextAlign.center, style: AppTypography.sectionTitle()),
        const SizedBox(height: AppSpacing.xs),
        Text('Gratuit', textAlign: TextAlign.center, style: AppTypography.metadata()),
        const SizedBox(height: AppSpacing.xl),
        for (final row in rows) ...[
          Text(row.$1, style: AppTypography.metadata(AppColors.muted)),
          const SizedBox(height: AppSpacing.xs),
          Text(row.$2, style: AppTypography.body(AppColors.ink)),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

/// Round account photo, or the first letter on the brand blue.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.initial,
    this.picture,
    this.size = 32,
    this.inverted = false,
  });

  final String initial;
  final String? picture;
  final double size;

  /// White disc and blue letter, for the blue sidebar.
  /// Otherwise a blue disc and a white letter, for light surfaces.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final background = inverted ? AppColors.white : landing.AppColors.midBlue;
    final foreground = inverted ? landing.AppColors.midBlue : AppColors.white;
    final fallback = ColoredBox(
      color: background,
      child: Center(
        child: Text(
          initial,
          style: AppTypography.cardTitle(foreground).copyWith(
            fontSize: size * 0.44,
            height: 1,
          ),
        ),
      ),
    );
    final url = picture?.trim();
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? fallback
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}
