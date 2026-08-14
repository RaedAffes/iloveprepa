import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';
import '../models/library_index.dart';
import 'iloveprepa_brand.dart';
import 'notion_folder_icon.dart';
import 'search_input.dart';

/// Left panel with the expandable/collapsible hierarchy tree.
///
/// The tree shows folders only — every parent folder gets a ▶ / ▼ caret and
/// files are never listed here. Clicking the folder that holds the documents
/// opens them in the main content area. The currently open folder is
/// highlighted, its ancestors shown bold so "where am I?" is always
/// answerable. While a search is active, the tree is replaced by the
/// matching results (folders and files).
class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    super.key,
    required this.root,
    required this.currentPath,
    required this.expanded,
    required this.onToggle,
    required this.onOpenFolder,
    required this.onOpenFile,
    required this.searchController,
    required this.onSearchChanged,
    this.searchQuery = '',
    this.searchResults = const [],
    this.treeScrollController,
    this.onMenu,
  });

  final LibraryFolder root;
  final List<String> currentPath;
  final Set<String> expanded;
  final void Function(List<String> path) onToggle;
  final void Function(List<String> path) onOpenFolder;
  final void Function(DocumentItem doc) onOpenFile;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  /// Active search text (non-empty switches the panel to results mode).
  final String searchQuery;

  /// Search matches to display while [searchQuery] is non-empty.
  final List<SearchResult> searchResults;

  /// Keeps the tree's scroll position while search results are shown, so the
  /// tree layout survives a search round-trip.
  final ScrollController? treeScrollController;

  /// Toggles the sidebar (wide screens) or closes the drawer (narrow).
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final subjects = root.children.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final searching = searchQuery.trim().isNotEmpty;

    return Container(
      width: 292,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
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
                Row(
                  children: [
                    if (onMenu != null) ...[
                      IconButton(
                        onPressed: onMenu,
                        tooltip: 'Masquer la barre latérale',
                        icon: const Icon(
                          Icons.menu_rounded,
                          size: 20,
                          color: AppColors.secondary,
                        ),
                        hoverColor: AppColors.hover,
                        splashRadius: 18,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: IloveprepaBrand(
                        fontSize: 26,
                        iconSize: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SearchInput(
              controller: searchController,
              onChanged: onSearchChanged,
              compact: true,
            ),
          ),
          Expanded(
            child: searching
                ? _SearchResultsList(
                    results: searchResults,
                    onOpenFolder: onOpenFolder,
                    onOpenFile: onOpenFile,
                  )
                : ListView(
                    controller: treeScrollController,
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
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.results,
    required this.onOpenFolder,
    required this.onOpenFile,
  });

  final List<SearchResult> results;
  final void Function(List<String> path) onOpenFolder;
  final void Function(DocumentItem doc) onOpenFile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
      children: [
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Résultats',
                  style: AppTypography.label(AppColors.darkCharcoal),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Aucun résultat trouvé.',
                  style: AppTypography.metadata(AppColors.muted),
                ),
              ],
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(
              children: [
                Text(
                  'Résultats',
                  style: AppTypography.label(AppColors.darkCharcoal),
                ),
                const Spacer(),
                Text(
                  '${results.length}',
                  style: AppTypography.metadata(AppColors.muted),
                ),
              ],
            ),
          ),
          for (final result in results)
            _ResultRow(
              result: result,
              depth: result.path.length,
              onTap: () => result.isFolder
                  ? onOpenFolder([...result.path, result.title])
                  : onOpenFile(result.document!),
            ),
        ],
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.result,
    required this.depth,
    required this.onTap,
  });

  final SearchResult result;

  /// Number of ancestor folders — controls the row's left indent so results
  /// read as a hierarchy (folders and files nest under their parents).
  final int depth;
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: result.isFolder
                      ? const NotionFolderIcon(size: 20)
                      : const Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: AppColors.muted,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: AppTypography.metadata(
                          AppColors.darkCharcoal,
                        ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        result.pathLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.metadata(
                          AppColors.muted,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
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

class _Branch extends StatelessWidget {
  const _Branch({
    required this.folder,
    required this.path,
    required this.currentPath,
    required this.expanded,
    required this.onToggle,
    required this.onOpenFolder,
  });

  final LibraryFolder folder;
  final List<String> path;
  final List<String> currentPath;
  final Set<String> expanded;
  final void Function(List<String> path) onToggle;
  final void Function(List<String> path) onOpenFolder;

  String get pathKey => path.join('/');

  @override
  Widget build(BuildContext context) {
    final hasChildren = folder.children.isNotEmpty;
    final isExpandable = hasChildren;
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
          leading: isExpandable
              ? _Caret(expanded: isExpanded, onTap: () => onToggle(path))
              : const SizedBox(width: 20),
          icon: const NotionFolderIcon(size: 20),
          label: folder.name,
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
        if (isExpandable && isExpanded)
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
            ),
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
    required this.textColor,
    required this.fontWeight,
    required this.onTap,
  });

  final int depth;
  final bool isActive;
  final bool isAncestor;
  final Widget leading;
  final Widget icon;
  final String label;
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
                icon,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
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
