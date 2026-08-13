import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import 'file_mark.dart';
import 'hover_lift.dart';

/// Compact, lightweight card for a recently opened document.
class RecentFileCard extends StatelessWidget {
  const RecentFileCard({
    super.key,
    required this.document,
    required this.onTap,
  });

  final DocumentItem document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      onTap: onTap,
      lift: 3,
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardSmallR,
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FileMark(
                  isPdf: document.isPdf,
                  extension: document.extension,
                  size: 30,
                ),
                const Spacer(),
                const Icon(
                  Icons.more_horiz_rounded,
                  size: 16,
                  color: AppColors.muted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              document.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.metadata(
                AppColors.darkCharcoal,
              ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '${document.extension.isEmpty ? 'Fichier' : document.extension.toUpperCase()} · ${document.sizeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.metadata(
                AppColors.muted,
              ).copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
