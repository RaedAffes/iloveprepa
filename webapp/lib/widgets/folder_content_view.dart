import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';
import 'landing/landing_colors.dart' as landing;

/// Soft blue fill used for chips in the file browser.
const Color _blueSoft = Color(0xFFE8EDFA);

/// Light blue tint applied to a file row on hover.
const Color _rowHover = Color(0xFFF2F5FD);

/// Near-black ink for titles, numbers and icons.
const Color _ink = Color(0xFF1B1B1B);

/// Muted grey for secondary text.
const Color _greyMuted = Color(0xFF6B7280);

/// The main-page file browser: the open folder's documents are listed as
/// numbered, professional rows with View / Download actions — like a real file
/// app. Folders that only contain subfolders show nothing, since navigation
/// happens in the tree.
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
    final files = List<DocumentItem>.from(folder.files)
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ));

    if (files.isEmpty) {
      if (folder.children.isEmpty) return const _EmptyFolder();
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const _SectionHeader(label: 'Documents'),
        const SizedBox(height: AppSpacing.md),
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
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.sectionTitle(_ink),
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
              color: _blueSoft,
              borderRadius: AppRadius.cardSmallR,
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              size: 26,
              color: landing.AppColors.accentBlue,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Ce dossier est vide',
            style: AppTypography.label(_ink),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Aucun dossier ou document ici pour le moment.',
            textAlign: TextAlign.center,
            style: AppTypography.metadata(_greyMuted),
          ),
        ],
      ),
    );
  }
}

/// A file-manager style window: a bordered panel with a flat blue header and
/// numbered rows listing the files with View / Download actions.
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
    const style = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 11,
      ),
      color: landing.AppColors.midBlue,
      child: const Row(
        children: [
          Expanded(child: Text('NOM', style: style)),
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
        hoverColor: _rowHover,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 10,
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
                          color: _ink,
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
                                    color: landing.AppColors.orange,
                                  ),
                                )
                              : const Icon(Icons.download_rounded, size: 18),
                          color: landing.AppColors.orange,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : onView,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: _ink, width: 1.2),
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Voir'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: busy ? null : onDownload,
                          style: FilledButton.styleFrom(
                            backgroundColor: landing.AppColors.orange,
                            foregroundColor: _ink,
                          ),
                          icon: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _ink,
                                  ),
                                )
                              : const Icon(Icons.download_rounded, size: 16),
                          label: Text(busy ? '…' : 'Télécharger'),
                        ),
                      ],
                    );

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.displayName,
                          style: AppTypography.label(_ink).copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          typeLabel,
                          style: AppTypography.metadata(_greyMuted)
                              .copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
