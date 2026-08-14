import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';
import 'file_mark.dart';

/// The main-page file browser: when the open folder is the last in the tree
/// (it has no subfolders), its documents are listed as rows with View /
/// Download actions — like a real file app. Folders that only contain
/// subfolders show nothing, since navigation happens in the tree.
class FolderContentView extends StatelessWidget {
  const FolderContentView({
    super.key,
    required this.folder,
    required this.busy,
    required this.onView,
    required this.onDownload,
  });

  final LibraryFolder folder;

  /// Name of the document currently opening (disables its actions).
  final String? busy;

  final void Function(DocumentItem doc) onView;
  final void Function(DocumentItem doc) onDownload;

  @override
  Widget build(BuildContext context) {
    final isLeaf = folder.children.isEmpty;
    if (!isLeaf) return const SizedBox.shrink();

    final files = List<DocumentItem>.from(folder.files)
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        _SectionHeader(
          icon: Icons.description_outlined,
          label: 'Documents',
          count: files.length,
        ),
        const SizedBox(height: AppSpacing.md),
        if (files.isEmpty)
          const _EmptyFolder()
        else
          _DocumentsWindow(
            files: files,
            busy: busy,
            onView: onView,
            onDownload: onDownload,
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.secondary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.label(AppColors.darkCharcoal),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 1,
          ),
          decoration: BoxDecoration(
            color: AppColors.hover,
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Text(
            '$count',
            style: AppTypography.metadata(AppColors.muted).copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: AppRadius.cardSmallR,
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              size: 26,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Ce dossier est vide',
            style: AppTypography.label(AppColors.darkCharcoal),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Aucun dossier ou document ici pour le moment.',
            textAlign: TextAlign.center,
            style: AppTypography.metadata(AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// A file-manager style window: a bordered panel whose rows list the files
/// directly inside the open folder, with their size and View / Download
/// actions.
class _DocumentsWindow extends StatelessWidget {
  const _DocumentsWindow({
    required this.files,
    required this.busy,
    required this.onView,
    required this.onDownload,
  });

  final List<DocumentItem> files;
  final String? busy;
  final void Function(DocumentItem doc) onView;
  final void Function(DocumentItem doc) onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.xs,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _WindowHeader(),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          for (final doc in files)
            _FileRow(
              doc: doc,
              isLast: identical(doc, files.last),
              busy: busy == doc.name,
              onView: () => onView(doc),
              onDownload: () => onDownload(doc),
            ),
        ],
      ),
    );
  }
}

class _WindowHeader extends StatelessWidget {
  const _WindowHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            'Nom',
            style: AppTypography.metadata(AppColors.muted).copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.doc,
    required this.isLast,
    required this.busy,
    required this.onView,
    required this.onDownload,
  });

  final DocumentItem doc;
  final bool isLast;
  final bool busy;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final typeLabel = doc.isPdf
        ? 'PDF'
        : (doc.extension.isEmpty ? 'Fichier' : doc.extension.toUpperCase());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onView,
        hoverColor: AppColors.hover,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: isLast
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;

              final actions = compact
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: busy ? null : onView,
                          tooltip: 'Voir',
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          color: AppColors.secondary,
                        ),
                        IconButton(
                          onPressed: busy ? null : onDownload,
                          tooltip: 'Télécharger',
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.secondary,
                                  ),
                                )
                              : const Icon(Icons.download_rounded, size: 18),
                          color: AppColors.secondary,
                        ),
                      ],
                    )
                  : Row(
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

              return Row(
                children: [
                  FileMark(
                    isPdf: doc.isPdf,
                    extension: doc.extension,
                    size: 38,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.displayName,
                          style: AppTypography.metadata(
                            AppColors.darkCharcoal,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          typeLabel,
                          style: AppTypography.metadata(AppColors.muted)
                              .copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
