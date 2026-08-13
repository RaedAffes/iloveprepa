import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';
import '../models/library_index.dart';
import '../services/api_service.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/library_sidebar.dart';
import '../widgets/recent_file_card.dart';
import '../widgets/search_result_tile.dart';
import '../widgets/skeleton_card.dart';
import '../widgets/state_views.dart';

/// Library home — hierarchical R2 folder tree on the left, a prominent
/// search bar and the recently opened folders/files on the right.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.api});

  /// Test seam — defaults to the real [ApiService].
  final ApiService? api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const double _maxContentWidth = 860;

  late final ApiService _api = widget.api ?? ApiService();
  final _searchController = TextEditingController();

  late Future<List<DocumentItem>> _future;
  List<DocumentItem> _all = const [];
  LibraryIndex? _index;
  String _query = '';
  String? _busy;

  // Sidebar tree expansion (keys are full folder paths).
  final Set<String> _expanded = {};

  // Currently open folder path, shown as a breadcrumb + highlighted.
  List<String> _currentPath = const [];

  // Recently opened folders and files (most recent first, capped).
  List<List<String>> _recentFolders = [];
  List<DocumentItem> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    _future = _api.fetchDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _all = const [];
      _index = null;
      _recentFolders = [];
      _recentFiles = [];
      _currentPath = const [];
      _query = '';
      _searchController.clear();
      _future = _api.fetchDocuments();
    });
  }

  void _prepare(List<DocumentItem> docs) {
    if (_index != null) return;
    final index = LibraryIndex(docs);
    var changed = false;
    for (final name in index.root.children.keys) {
      changed = _expanded.add(name) || changed;
    }
    _index = index;
    if (changed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _syncExpanded(List<String> path) {
    for (var i = 1; i <= path.length; i++) {
      _expanded.add(path.take(i).join('/'));
    }
  }

  void _openFolder(List<String> path) {
    _syncExpanded(path);
    setState(() {
      _currentPath = List.of(path);
      _query = '';
      _searchController.clear();
      _recentFolders.removeWhere((p) => _sameList(p, path));
      _recentFolders.insert(0, List.of(path));
      if (_recentFolders.length > 4) _recentFolders = _recentFolders.sublist(0, 4);
    });
  }

  void _goHome() {
    setState(() {
      _currentPath = const [];
      _query = '';
      _searchController.clear();
    });
  }

  void _toggleNode(List<String> path) {
    final key = path.join('/');
    setState(() {
      if (!_expanded.remove(key)) _expanded.add(key);
    });
  }

  Future<void> _open(DocumentItem item, {required bool download}) async {
    if (_busy != null) return;
    setState(() => _busy = item.name);
    try {
      final uri = download ? _api.downloadUri(item) : _api.viewUri(item);
      final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (launched) {
        setState(() {
          _recentFiles.removeWhere((d) => d.name == item.name);
          _recentFiles.insert(0, item);
          if (_recentFiles.length > 4) _recentFiles = _recentFiles.sublist(0, 4);
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir le document.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(e is ApiException ? e.message : 'Une erreur est survenue.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  LibraryFolder get _root => _index?.root ?? buildLibraryTree(_all);

  @override
  Widget build(BuildContext context) {
    final sidebar = LibrarySidebar(
      root: _root,
      currentPath: _currentPath,
      expanded: _expanded,
      onToggle: _toggleNode,
      onOpenFolder: _openFolder,
      onOpenFile: (doc) => _open(doc, download: false),
      totalDocuments: _root.totalDocuments,
    );

    return Scaffold(
      drawer: Drawer(width: 292, child: sidebar),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            return Row(
              children: [
                if (wide)
                  SizedBox(width: 292, child: sidebar)
                else
                  const SizedBox.shrink(),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        showMenu: !wide,
                        currentPath: _currentPath,
                        onHome: _goHome,
                        onNavigate: _openFolder,
                        onRefresh: _reload,
                      ),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    return FutureBuilder<List<DocumentItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LibrarySkeleton();
        }
        if (snapshot.hasError) {
          return ErrorView(onRetry: _reload);
        }
        final docs = snapshot.data ?? const <DocumentItem>[];
        _all = docs;
        _prepare(docs);
        if (docs.isEmpty) return EmptyView(onRefresh: _reload);
        return _buildBody();
      },
    );
  }

  Widget _buildBody() {
    final index = _index;
    if (_query.trim().isNotEmpty && index != null) {
      return _buildSearchResults(index);
    }
    return _scrollable(
      children: [
        _SearchInput(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _RecentSection(
          folders: _recentFolders,
          files: _recentFiles,
          onOpenFolder: _openFolder,
          onOpenFile: (doc) => _open(doc, download: false),
        ),
      ],
    );
  }

  Widget _buildSearchResults(LibraryIndex index) {
    final results = index.search(_query);

    return _scrollable(
      children: [
        const _Eyebrow('Recherche'),
        const SizedBox(height: AppSpacing.lg),
        if (results.isEmpty)
          NoResultsView(query: _query)
        else
          for (final result in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SearchResultTile(
                result: result,
                busy: _busy == result.document?.name,
                onOpenFolder: () => _openFolder(
                  result.path.isEmpty
                      ? [result.title]
                      : [...result.path, result.title],
                ),
                onView: () => _open(result.document!, download: false),
                onDownload: () => _open(result.document!, download: true),
              ),
            ),
      ],
    );
  }

  Widget _scrollable({required List<Widget> children}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
          children: children,
        ),
      ),
    );
  }
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showMenu,
    required this.currentPath,
    required this.onHome,
    required this.onNavigate,
    required this.onRefresh,
  });

  final bool showMenu;
  final List<String> currentPath;
  final VoidCallback onHome;
  final void Function(List<String> path) onNavigate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          if (showMenu) ...[
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded, size: 20),
              color: AppColors.secondary,
              hoverColor: AppColors.hover,
              splashRadius: 18,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: currentPath.isEmpty
                ? Text('Bibliothèque', style: AppTypography.label())
                : BreadcrumbBar(
                    segments: currentPath,
                    onTap: (index) =>
                        index == -1 ? onHome() : onNavigate(currentPath.take(index + 1).toList()),
                  ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Actualiser la bibliothèque',
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: AppColors.secondary,
            hoverColor: AppColors.hover,
            splashRadius: 18,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTypography.eyebrow());
  }
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, _) => const SkeletonCard(),
        ),
      ),
    );
  }
}

class _SearchInput extends StatefulWidget {
  const _SearchInput({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<_SearchInput> {
  final FocusNode _focus = FocusNode();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_sync);
  }

  @override
  void dispose() {
    _focus.removeListener(_sync);
    _focus.dispose();
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final borderColor = focused
        ? AppColors.darkCharcoal.withValues(alpha: 0.35)
        : _hovered
            ? AppColors.secondary.withValues(alpha: 0.35)
            : AppColors.border;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.searchR,
          border: Border.all(color: borderColor, width: 1),
          boxShadow: _hovered || focused ? AppShadows.xs : null,
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          onSubmitted: widget.onChanged,
          style: AppTypography.body(AppColors.darkCharcoal)
              .copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Rechercher une matière, un dossier ou un document…',
            hintStyle:
                AppTypography.body(AppColors.muted).copyWith(fontSize: 15),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 21,
              color: AppColors.secondary,
            ),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.secondary,
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.folders,
    required this.files,
    required this.onOpenFolder,
    required this.onOpenFile,
  });

  final List<List<String>> folders;
  final List<DocumentItem> files;
  final void Function(List<String> path) onOpenFolder;
  final void Function(DocumentItem doc) onOpenFile;

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty && files.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow('Récents'),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Les dossiers et documents que vous ouvrez apparaîtront ici.',
            style: AppTypography.body(AppColors.muted),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('Récents'),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: folders.length + files.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index < folders.length) {
                final path = folders[index];
                return _RecentFolderCard(
                  name: path.last,
                  location: path.length > 1 ? path.take(path.length - 1).join(' / ') : 'Racine',
                  onTap: () => onOpenFolder(path),
                );
              }
              final doc = files[index - folders.length];
              return RecentFileCard(
                document: doc,
                onTap: () => onOpenFile(doc),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentFolderCard extends StatelessWidget {
  const _RecentFolderCard({
    required this.name,
    required this.location,
    required this.onTap,
  });

  final String name;
  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardSmallR,
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppShadows.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: AppRadius.iconR,
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  size: 20,
                  color: AppColors.accentDark,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.metadata(AppColors.darkCharcoal)
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.metadata(AppColors.muted)
                    .copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
