import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/library_index.dart';
import 'file_mark.dart';
import 'hover_lift.dart';
import 'notion_folder_icon.dart';

/// A single search result. Folders open the folder; files offer Voir and
/// Télécharger actions. Every result always shows its complete path so the
/// user instantly knows where it belongs.
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.result,
    required this.busy,
    required this.onOpenFolder,
    required this.onView,
    required this.onDownload,
  });

  final SearchResult result;
  final bool busy;
  final VoidCallback onOpenFolder;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      onTap: result.isFolder ? onOpenFolder : (busy ? null : onView),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardSmallR,
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.xs,
        ),
        child: result.isFolder ? _buildFolder() : _buildFile(),
      ),
    );
  }

  Widget _buildFolder() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.folderYellowSoft,
            borderRadius: AppRadius.iconR,
          ),
          child: const NotionFolderIcon(size: 30),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _body()),
        const SizedBox(width: AppSpacing.sm),
        const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.muted,
        ),
      ],
    );
  }

  Widget _buildFile() {
    final doc = result.document!;
    final layout = LayoutBuilder(
      builder: (context, constraints) {
        final actions = _actions();
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FileMark(
                    isPdf: doc.isPdf,
                    extension: doc.extension,
                    size: 40,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _body()),
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
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Télécharger'),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            FileMark(isPdf: doc.isPdf, extension: doc.extension, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _body()),
            const SizedBox(width: AppSpacing.md),
            actions,
          ],
        );
      },
    );

    return layout;
  }

  Widget _body() {
    final meta = <Widget>[
      if (result.type != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Text(
            result.type!.label,
            style: AppTypography.metadata(
              AppColors.greenDark,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
    ];

    if (!result.isFolder) {
      final doc = result.document!;
      meta.addAll([
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${doc.isPdf ? 'PDF' : doc.extension.toUpperCase()} · ${doc.sizeLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.metadata(),
          ),
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.tileTitle(),
        ),
        const SizedBox(height: 3),
        Text(
          result.pathLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.metadata(AppColors.muted),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: meta),
        ],
      ],
    );
  }

  Widget _actions() {
    return Row(
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
  }
}
