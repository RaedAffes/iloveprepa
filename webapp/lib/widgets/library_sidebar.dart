import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';
import '../models/library_index.dart';
import 'iloveprepa_brand.dart';
import 'landing/landing_colors.dart' as landing;
import 'notion_folder_icon.dart';
import 'notion_pdf_icon.dart';
import 'search_input.dart';

/// Left panel with the expandable/collapsible hierarchy tree.
///
/// Folders get a ▶ / ▼ caret and, once expanded, their documents are listed
/// beneath them as file rows. Clicking a folder or a file opens it in the main
/// content area. The currently open folder is highlighted, its ancestors shown
/// bold so "where am I?" is always answerable. While a search is active, the
/// tree is replaced by the matching results: the ancestor folders of every hit
/// keep the hierarchy readable, but only the folders and files that actually
/// match are shown.
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
    this.onBrandTap,
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

  /// Returns to the landing page when the brand mark is tapped.
  final VoidCallback? onBrandTap;

  @override
  Widget build(BuildContext context) {
    final subjects = root.children.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final searching = searchQuery.trim().isNotEmpty;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: landing.AppColors.midBlue,
        border: Border(
          right: BorderSide(color: Color(0x33FFFFFF), width: 1),
        ),
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
                          color: Colors.white,
                        ),
                        hoverColor: Colors.white12,
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
                        color: Colors.white,
                        onTap: onBrandTap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x33FFFFFF)),
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
                      for (final file in root.files)
                        _TreeRow(
                          depth: 0,
                          isActive: false,
                          isAncestor: false,
                          leading: const SizedBox(width: 20),
                          icon: const NotionPdfIcon(
                            size: 15,
                            color: Colors.white70,
                          ),
                          label: file.fileName,
                          textColor: Colors.white70,
                          fontWeight: FontWeight.w400,
                          onTap: () => onOpenFile(file),
                        ),
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
    final roots = _buildSearchTree(results);

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: Row(
            children: [
              Text(
                'Résultats',
                style: AppTypography.label(Colors.white),
              ),
              const Spacer(),
              Text(
                '${results.length}',
                style: AppTypography.metadata(Colors.white70),
              ),
            ],
          ),
        ),
        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 24),
            child: Text(
              'Aucun résultat trouvé.',
              style: AppTypography.metadata(Colors.white70),
            ),
          )
        else
          for (final node in roots) ..._searchRows(node, 0),
      ],
    );
  }

  /// Flattens a search hit's matches into tree rows: each ancestor folder of a
  /// hit is shown as a folder row (so the path stays readable), and only the
  /// folders/files that actually matched are listed beneath — never the full
  /// contents of a folder.
  List<Widget> _searchRows(_SearchNode node, int depth) => [
        _SearchFolderRow(
          name: node.name,
          depth: depth,
          isMatch: node.isMatch,
          onTap: () => onOpenFolder(node.path),
        ),
        for (final child in node.children.values.toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
          ..._searchRows(child, depth + 1),
        for (final file in node.files)
          _SearchFileRow(
            title: file.title,
            depth: depth + 1,
            onTap: () => onOpenFile(file.document!),
          ),
      ];
}

/// Rebuilds the flat [SearchResult] list into a minimal tree: matched folders
/// and files keep their ancestor folders so the hierarchy of the real tree is
/// preserved, but sibling folders/files that don't match are dropped.
List<_SearchNode> _buildSearchTree(List<SearchResult> results) {
  final root = _SearchNode('', const []);
  for (final result in results) {
    final node = result.isFolder
        ? root.ensure([...result.path, result.title])
        : root.ensure(result.path);
    if (result.isFolder) {
      node.match = result;
    } else {
      node.files.add(result);
    }
  }
  return [
    for (final child in root.children.values) child,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// One folder in the filtered search tree.
class _SearchNode {
  _SearchNode(this.name, this.path);

  final String name;

  /// Full folder path — the node's own name included.
  final List<String> path;

  final Map<String, _SearchNode> children = {};
  final List<SearchResult> files = [];

  /// Set when the folder name itself matches the query.
  SearchResult? match;

  bool get isMatch => match != null;

  _SearchNode ensure(List<String> segments) {
    var node = this;
    for (final segment in segments) {
      node = node.children.putIfAbsent(
        segment,
        () => _SearchNode(segment, [...node.path, segment]),
      );
    }
    return node;
  }
}

class _SearchFolderRow extends StatelessWidget {
  const _SearchFolderRow({
    required this.name,
    required this.depth,
    required this.isMatch,
    required this.onTap,
  });

  final String name;
  final int depth;
  final bool isMatch;
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
                const SizedBox(width: 20),
                const NotionFolderIcon(size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: AppTypography.metadata(
                      isMatch ? Colors.white : Colors.white70,
                    ).copyWith(
                      fontWeight: isMatch ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
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

class _SearchFileRow extends StatelessWidget {
  const _SearchFileRow({
    required this.title,
    required this.depth,
    required this.onTap,
  });

  final String title;
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
                const SizedBox(width: 20),
                const Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.metadata(Colors.white).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
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
    final hasFiles = folder.files.isNotEmpty;
    final isExpandable = hasChildren || hasFiles;
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
              ? _Caret(
                  expanded: isExpanded,
                  onTap: () => onToggle(path),
                )
              : const SizedBox(width: 20),
          icon: const NotionFolderIcon(size: 20),
          label: folder.name,
          textColor: isActive
              ? Colors.white
              : isAncestor
              ? Colors.white
              : Colors.white70,
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
              onOpenFile: onOpenFile,
            ),
        if (isExpanded && folder.files.isNotEmpty)
          for (final file in folder.files)
            _TreeRow(
              depth: path.length,
              isActive: false,
              isAncestor: false,
              leading: const SizedBox(width: 20),
              icon: const NotionPdfIcon(size: 15, color: Colors.white70),
              label: file.fileName,
              textColor: Colors.white70,
              fontWeight: FontWeight.w400,
              onTap: () => onOpenFile(file),
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
                  ? landing.AppColors.orange
                  : isAncestor
                  ? Colors.white.withValues(alpha: 0.12)
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
            color: Colors.white70,
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
