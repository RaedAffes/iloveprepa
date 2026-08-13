import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import 'file_mark.dart';
import 'hover_lift.dart';

/// A simple file box: type mark, file name, and View / Download actions.
class DocumentCard extends StatelessWidget {
  const DocumentCard({
    super.key,
    required this.document,
    required this.busy,
    required this.onView,
    required this.onDownload,
  });

  final DocumentItem document;
  final bool busy;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final name = Text(
      document.displayName,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.tileTitle(),
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : onView,
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('Voir'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: busy ? null : onDownload,
          icon: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.download_rounded, size: 16),
          label: Text(busy ? '…' : 'Télécharger'),
        ),
      ],
    );

    return HoverLift(
      onTap: busy ? null : onView,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardSmallR,
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.xs,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 540) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      FileMark(
                        isPdf: document.isPdf,
                        extension: document.extension,
                        size: 40,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: name),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : onView,
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Voir'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : onDownload,
                          icon: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Icon(Icons.download_rounded, size: 16),
                          label: Text(busy ? '…' : 'Télécharger'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                FileMark(
                  isPdf: document.isPdf,
                  extension: document.extension,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: name),
                const SizedBox(width: AppSpacing.md),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}
