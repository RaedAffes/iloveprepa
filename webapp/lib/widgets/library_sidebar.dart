import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';

/// Left panel with the expandable/collapsible hierarchy tree.
///
/// Every parent folder gets a ▶ / ▼ caret; files only appear once their
/// parent is expanded. The currently open folder is highlighted in green,
/// its ancestors are shown bold so "where am I?" is always answerable.
class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    super.key,
    required this.root,
    required this.currentPath,
    required this.expanded,
    required this.onToggle,
    required this.onOpenFolder,
    required this.onOpenFile,
    required this.totalDocuments,
  });

  final LibraryFolder root;
  final List<String> currentPath;
  final Set<String> expanded;
  final void Function(List<String> path) onToggle;
  final void Function(List<String> path) onOpenFolder;
  final void Function(DocumentItem doc) onOpenFile;
  final int totalDocuments;

  @override
  Widget build(BuildContext context) {
    final subjects = root.children.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Container(
      width: 292,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bibliothèque', style: AppTypography.sectionTitle()),
                const SizedBox(height: 2),
                Text(
                  '$totalDocuments ${totalDocuments == 1 ? 'document' : 'documents'}',
                  style: AppTypography.metadata(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
              children: [
                for (final subject in subjects)
                  _Branch(
                    folder: subject,
                    path: [subject.name],
                    currentPath: currentPath,
                    expanded: expanded,
                    onToggle: onToggle,
                    onOpenFolder: onOpenFolder,
                    onOpenFile: onOpenFile,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({
    required this.folder,
    required this.path,
    required this.currentPath,
    required this.expanded,
    required this.onToggle,
    required this.onOpenFolder,
    required this.onOpenFile,
  });

  final LibraryFolder folder;
  final List<String> path;
  final List<String> currentPath;
  final Set<String> expanded;
  final void Function(List<String> path) onToggle;
  final void Function(List<String> path) onOpenFolder;
  final void Function(DocumentItem doc) onOpenFile;

  String get pathKey => path.join('/');

  @override
  Widget build(BuildContext context) {
    final hasChildren = folder.children.isNotEmpty;
    final isExpanded = expanded.contains(pathKey);
    final isActive = _samePath(path, currentPath);
    final isAncestor = !isActive && _isPrefix(path, currentPath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TreeRow(
          depth: path.length - 1,
          isActive: isActive,
          isAncestor: isAncestor,
          leading: hasChildren
              ? _Caret(expanded: isExpanded, onTap: () => onToggle(path))
              : const SizedBox(width: 20),
          icon: isActive || isAncestor
              ? Icons.folder_rounded
              : Icons.folder_outlined,
          label: folder.name,
          iconColor: isActive ? AppColors.greenDark : AppColors.accentDark,
          textColor: isActive
              ? AppColors.greenDark
              : isAncestor
              ? AppColors.ink
              : AppColors.secondary,
          fontWeight: isActive || isAncestor
              ? FontWeight.w600
              : FontWeight.w400,
          onTap: () => onOpenFolder(path),
        ),
        if (hasChildren && isExpanded) ...[
          for (final child
              in folder.children.values.toList()..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              ))
            _Branch(
              folder: child,
              path: [...path, child.name],
              currentPath: currentPath,
              expanded: expanded,
              onToggle: onToggle,
              onOpenFolder: onOpenFolder,
              onOpenFile: onOpenFile,
            ),
          for (final doc
              in List<DocumentItem>.from(folder.files)..sort(
                (a, b) => a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                ),
              ))
            _TreeRow(
              depth: path.length,
              isActive: false,
              isAncestor: false,
              leading: const SizedBox(width: 20),
              icon: Icons.description_outlined,
              label: doc.displayName,
              iconColor: AppColors.muted,
              textColor: AppColors.secondary,
              fontWeight: FontWeight.w400,
              onTap: () => onOpenFile(doc),
            ),
        ],
      ],
    );
  }
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.depth,
    required this.isActive,
    required this.isAncestor,
    required this.leading,
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.fontWeight,
    required this.onTap,
  });

  final int depth;
  final bool isActive;
  final bool isAncestor;
  final Widget leading;
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final FontWeight fontWeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.navR,
          child: AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.greenSoft
                  : isAncestor
                  ? AppColors.surfaceMuted.withValues(alpha: 0.6)
                  : Colors.transparent,
              borderRadius: AppRadius.navR,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 2),
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.metadata(
                      textColor,
                    ).copyWith(fontWeight: fontWeight, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Caret extends StatelessWidget {
  const _Caret({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        tooltip: expanded ? 'Réduire' : 'Déplier',
        icon: AnimatedRotation(
          turns: expanded ? 0.25 : 0,
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
          child: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

bool _samePath(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _isPrefix(List<String> prefix, List<String> path) {
  if (prefix.length >= path.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (prefix[i] != path[i]) return false;
  }
  return true;
}
