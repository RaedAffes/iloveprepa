import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'landing/landing_colors.dart' as landing;

const Color _blueSoft = Color(0xFFE8EDFA);

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (actionLabel != null) ...[
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
