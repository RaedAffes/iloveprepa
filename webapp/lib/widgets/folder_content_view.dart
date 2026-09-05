import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';
import 'landing/landing_colors.dart' as landing;
import 'notion_folder_icon.dart';

/// Soft blue fill used for chips in the file browser.
const Color _blueSoft = Color(0xFFE8EDFA);

/// Light blue tint applied to a file row on hover.
const Color _rowHover = Color(0xFFF2F5FD);

/// Near-black ink for titles, numbers and icons.
const Color _ink = Color(0xFF1B1B1B);

/// Muted grey for secondary text.
const Color _greyMuted = Color(0xFF6B7280);

/// Structured main-page browser: the selected top-level folder's hierarchy is
/// shown as expandable sections, like the sidebar used to be but now in the
/// main page. Each folder is a section with a caret; tapping it expands to
/// show its files and its subfolders as nested sections.
class FolderContentView extends StatelessWidget {
  const FolderContentView({
    super.key,
    required this.folder,
    required this.currentPath,
    required this.expanded,
    required this.busy,
    required this.onView,
    required this.onDownload,
    required this.onOpenFolder,
    required this.onToggle,
  });

  final LibraryFolder folder;
  final List<String> currentPath;
  final Set<String> expanded;
  final String? busy;
  final void Function(DocumentItem doc) onView;
  final void Function(DocumentItem doc) onDownload;
  final void Function(List<String> path) onOpenFolder;
  final void Function(List<String> path) onToggle;

  @override
  Widget build(BuildContext context) {
    final files = List<DocumentItem>.from(folder.files)
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    final subfolders = folder.children.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (files.isEmpty && subfolders.isEmpty) {
      return const _EmptyFolder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentPath.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _MainBreadcrumb(path: currentPath, onTap: onOpenFolder),
          ),
        if (files.isNotEmpty) ...[
          _DocumentsWindow(files: files, busy: busy, onView: onView, onDownload: onDownload),
          if (subfolders.isNotEmpty) const SizedBox(height: AppSpacing.lg),
        ],
        for (final child in subfolders)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _MainFolderSection(
              folder: child,
              path: [...currentPath, child.name],
              expanded: expanded,
              busy: busy,
              onView: onView,
              onDownload: onDownload,
              onToggle: onToggle,
              onOpenFolder: onOpenFolder,
            ),
          ),
      ],
    );
  }
}

class _MainFolderSection extends StatelessWidget {
  const _MainFolderSection({
    required this.folder,
    required this.path,
    required this.expanded,
    required this.busy,
    required this.onView,
    required this.onDownload,
    required this.onToggle,
    required this.onOpenFolder,
  });

  final LibraryFolder folder;
  final List<String> path;
  final Set<String> expanded;
  final String? busy;
  final void Function(DocumentItem doc) onView;
  final void Function(DocumentItem doc) onDownload;
  final void Function(List<String> path) onToggle;
  final void Function(List<String> path) onOpenFolder;

  String get pathKey => path.join('/');

  @override
  Widget build(BuildContext context) {
    final isExpanded = expanded.contains(pathKey);
    final files = List<DocumentItem>.from(folder.files)
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    final subfolders = folder.children.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.xs,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onToggle(path),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: isExpanded ? _blueSoft : Colors.white,
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.chevron_right_rounded, size: 20, color: _greyMuted),
                  ),
                  const SizedBox(width: 6),
                  const NotionFolderIcon(size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(folder.name, style: AppTypography.label(_ink).copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            if (files.isNotEmpty)
              _DocumentsWindow(files: files, busy: busy, onView: onView, onDownload: onDownload),
            if (subfolders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in subfolders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MainFolderSection(
                          folder: child,
                          path: [...path, child.name],
                          expanded: expanded,
                          busy: busy,
                          onView: onView,
                          onDownload: onDownload,
                          onToggle: onToggle,
                          onOpenFolder: onOpenFolder,
                        ),
                      ),
                  ],
                ),
              ),
            if (files.isEmpty && subfolders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Dossier vide', style: TextStyle(color: _greyMuted, fontSize: 13)),
              ),
          ],
        ],
      ),
    );
  }
}

class _MainBreadcrumb extends StatelessWidget {
  const _MainBreadcrumb({required this.path, required this.onTap});
  final List<String> path;
  final void Function(List<String> path) onTap;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        InkWell(
          onTap: () => onTap(path.sublist(0, 1)),
          child: Text(path.first, style: AppTypography.label(_ink).copyWith(fontWeight: FontWeight.w700)),
        ),
        for (var i = 1; i < path.length; i++) ...[
          const Icon(Icons.chevron_right_rounded, size: 18, color: _greyMuted),
          InkWell(
            onTap: () => onTap(path.sublist(0, i + 1)),
            child: Text(
              path[i],
              style: AppTypography.label(i == path.length - 1 ? _ink : _greyMuted)
                  .copyWith(fontWeight: i == path.length - 1 ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ],
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
