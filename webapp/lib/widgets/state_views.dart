import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'landing/landing_colors.dart' as landing;

const Color _blueSoft = Color(0xFFE8EDFA);

/// Universal page shown for every backend error (quota exceeded, throttling,
/// timeouts, unreachable server...). It mirrors the "Message envoyé" success
/// card from the contact page — the check.png illustration — with a friendly
/// "come back later" message and the orange retry pill.
class ComeBackLaterView extends StatelessWidget {
  const ComeBackLaterView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/check.png', height: 280),
            const SizedBox(height: 26),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Iloveprepa utilise des services totalement '
                        'gratuits. Lorsqu\'un grand nombre de personnes se '
                        'connectent en même temps, la limite de ces services '
                        'peut être atteinte. Merci de revenir après un moment ',
                  ),
                  const TextSpan(
                    text: '♥',
                    style: TextStyle(color: Color(0xFFFF5A6A)),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w600,
                fontSize: 17,
                height: 1.5,
                color: Color(0xFF555A66),
              ),
            ),
            const SizedBox(height: 30),
            _OrangePillButton(label: 'Réessayer', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Custom action widget (e.g. the orange pill button). When provided it
  /// replaces the default blue retry button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.dialog),
              ),
              child: Icon(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle(),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.body(),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ] else if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: landing.AppColors.midBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when the library could not be reached. [detail] is the underlying
/// failure (server code, timeout, network) surfaced so the cause is not a
/// mystery.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.onRetry, this.detail, this.apiBase});

  final VoidCallback onRetry;
  final String? detail;
  final String? apiBase;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.cloud_off_outlined,
      iconColor: AppColors.danger,
      iconBg: AppColors.dangerSoft,
      title: 'Impossible de joindre la bibliothèque',
      subtitle: detail == null
          ? 'Une erreur est survenue lors de la connexion au serveur de documents. '
                'Vérifiez votre connexion et réessayez.'
          : 'Une erreur est survenue lors de la connexion au serveur de documents :\n'
                '$detail'
                '${apiBase == null ? '' : '\n\nAPI : $apiBase'}',
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

/// Shown when R2 has no files at all.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.folder_open_outlined,
      iconColor: landing.AppColors.accentBlue,
      iconBg: _blueSoft,
      title: 'Aucun document pour le moment',
      subtitle:
          'Votre bibliothèque est vide. Ajoutez des fichiers à votre bucket R2 '
          'et ils apparaîtront ici.',
      actionLabel: 'Actualiser',
      onAction: onRefresh,
    );
  }
}

/// Shown when the backend has paused the service (free-tier usage lock).
/// Replaces the raw 503 error with a friendly maintenance message and the
/// orange pill button used on the contact page.
class LibraryMaintenanceView extends StatelessWidget {
  const LibraryMaintenanceView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.engineering_outlined,
      iconColor: const Color(0xFFE88F2A),
      iconBg: const Color(0xFFFFF3E0),
      title: 'Bibliothèque en cours de réglage',
      subtitle:
          'La bibliothèque est maintenant en cours de réglage, merci de '
          'revenir une autre fois.',
      action: _OrangePillButton(label: 'Réessayer', onTap: onRetry),
    );
  }
}

/// Shown when Cloudflare is throttling the API (HTTP 429 / daily quota, or
/// the browser-side `Failed to fetch` that the block produces). Same orange
/// pill treatment as the maintenance view, with a "try again later" message.
class ServerOverloadedView extends StatelessWidget {
  const ServerOverloadedView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.cloud_queue_outlined,
      iconColor: const Color(0xFFE88F2A),
      iconBg: const Color(0xFFFFF3E0),
      title: 'Service temporairement indisponible',
      subtitle:
          'Le serveur est temporairement surchargé ou bloqué. Merci de '
          'réessayer dans quelques instants.',
      action: _OrangePillButton(label: 'Réessayer', onTap: onRetry),
    );
  }
}

/// Pill-shaped orange button, matching the "Send message" button on the
/// contact page (InkWell ripple, rounded 48, Quicksand bold on white).
class _OrangePillButton extends StatelessWidget {
  const _OrangePillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(48),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFF923C),
            borderRadius: BorderRadius.circular(48),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when a search returns nothing.
class NoResultsView extends StatelessWidget {
  const NoResultsView({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.search_off_rounded,
      iconColor: landing.AppColors.accentBlue,
      iconBg: _blueSoft,
      title: 'Aucun résultat',
      subtitle:
          'Aucun document ne correspond à « $query ». Essayez un autre mot.',
    );
  }
}
