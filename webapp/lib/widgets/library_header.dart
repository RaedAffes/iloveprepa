import 'package:flutter/material.dart' hide SearchBar;

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import 'search_bar.dart';

/// Top bar of the library: brand mark, hamburger menu (narrow) and search field.
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.onRefresh,
    this.onMenu,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;

  /// Reloads the library (shown as a refresh action in the header).
  final VoidCallback onRefresh;

  /// Opens the sidebar drawer (shown only on narrow screens when non-null).
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final menuButton = onMenu == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              onPressed: onMenu,
              tooltip: 'Ouvrir la navigation',
              icon: const Icon(Icons.menu_rounded, size: 20),
              color: AppColors.ink,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.border, width: 1),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.button),
                  ),
                ),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(38, 38),
              ),
            ),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SearchBar(controller: controller, onChanged: onQueryChanged),
          );

          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ?menuButton,
                    const Expanded(child: _Brand()),
                    _RefreshButton(onPressed: onRefresh),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                search,
              ],
            );
          }

          return Row(
            children: [
              ?menuButton,
              const Expanded(child: _Brand()),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: search),
            ],
          );
        },
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.favorite_rounded,
          size: 28,
          color: Colors.red,
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Iloveprepa',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle(),
              ),
              Text(
                'BIBLIOTHÈQUE DE PRÉPA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.eyebrow(AppColors.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Actualiser la bibliothèque',
      icon: const Icon(Icons.refresh_rounded, size: 20),
      color: AppColors.ink,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceMuted,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border, width: 1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
        ),
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(38, 38),
      ),
    );
  }
}
