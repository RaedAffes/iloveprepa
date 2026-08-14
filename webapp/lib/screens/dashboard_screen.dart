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
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/recent_store.dart';
import '../services/stats_service.dart';
import '../widgets/app_footer.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/document_viewer.dart';
import '../widgets/folder_content_view.dart';
import '../widgets/iloveprepa_brand.dart';
import '../widgets/library_sidebar.dart';
import '../widgets/notion_pdf_icon.dart';
import '../widgets/skeleton_card.dart';
import '../widgets/state_views.dart';

/// Library home — hierarchical R2 folder tree on the left (with the search
/// field), and on the right either the recently opened files (home) or the
/// contents of the folder currently open in the tree.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.api, this.stats, this.analytics});

  /// Test seam — defaults to the real [ApiService].
  final ApiService? api;

  /// Test seam — defaults to the real [StatsService].
  final StatsService? stats;

  /// Test seam — defaults to the real [AnalyticsService].
  final AnalyticsService? analytics;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const double _maxContentWidth = 860;
  static const double _headerHeight = 220;
  static const int _maxRecents = 8;

  late final ApiService _api = widget.api ?? ApiService();
  late final StatsService _stats = widget.stats ?? StatsService();
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();
  final _searchController = TextEditingController();

  // Keeps the main content's scroll position and drives the footer's
  // visibility-triggered count-up.
  final ScrollController _contentScroll = ScrollController();

  late Future<List<DocumentItem>> _future;
  List<DocumentItem> _all = const [];
  LibraryIndex? _index;
  String _query = '';
  String? _busy;

  // Keeps the sidebar tree's scroll position across a search round-trip.
  final ScrollController _treeScroll = ScrollController();

  // Sidebar tree expansion (keys are full folder paths).
  final Set<String> _expanded = {};

  // Currently open folder path, shown as a breadcrumb + highlighted.
  List<String> _currentPath = const [];

  // Sidebar collapsed state on wide screens.
  bool _sidebarCollapsed = false;

  // Recently opened PDF files (most recent first, capped).
  final List<_RecentEntry> _recents = [];

  // Recents restored from persistent storage, resolved once the docs load.
  List<RecentItem> _storedRecents = const [];

  @override
  void initState() {
    super.initState();
    _future = _api.fetchDocuments();
    _restoreRecents();
    _stats.incrementVisits();
    _analytics.logAppOpen();
    _analytics.logScreenView('dashboard');
  }

  Future<void> _restoreRecents() async {
    final stored = await RecentStore.load();
    if (!mounted || stored.isEmpty) return;
    setState(() => _storedRecents = stored);
    if (_index != null) {
      final changed = _applyStoredRecents(_all);
      if (changed) setState(() {});
    }
  }

  Future<void> _persistRecents() async {
    await RecentStore.save([
      for (final e in _recents)
        RecentItem(name: e.document.name, openedAt: e.openedAt),
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _treeScroll.dispose();
    _contentScroll.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _all = const [];
      _index = null;
      _recents.clear();
      _storedRecents = const [];
      _currentPath = const [];
      _query = '';
      _searchController.clear();
      _future = _api.fetchDocuments();
    });
    _restoreRecents();
  }

  void _prepare(List<DocumentItem> docs) {
    if (_index != null) return;
    final index = LibraryIndex(docs);
    var changed = false;
    for (final name in index.root.children.keys) {
      changed = _expanded.add(name) || changed;
    }
    _index = index;
    changed = _applyStoredRecents(docs) || changed;
    if (changed && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Resolves persisted recents against the fetched docs, dropping entries
  /// whose file no longer exists. Returns true if any were added.
  bool _applyStoredRecents(List<DocumentItem> docs) {
    if (_storedRecents.isEmpty || _recents.length >= _maxRecents) return false;
    final byName = {for (final d in docs) d.name: d};
    final added = <_RecentEntry>[];
    for (final stored in _storedRecents) {
      if (_recents.length + added.length >= _maxRecents) break;
      final doc = byName[stored.name];
      if (doc == null || !doc.isPdf) continue;
      final segments = doc.name.split('/');
      final location = segments.length > 1
          ? segments.take(segments.length - 1).join(' / ')
          : 'Racine';
      added.add(
        _RecentEntry(
          title: doc.displayName,
          location: location,
          document: doc,
          openedAt: stored.openedAt,
        ),
      );
    }
    if (added.isEmpty) return false;
    _recents.addAll(added);
    return true;
  }

  void _syncExpanded(List<String> path) {
    for (var i = 1; i <= path.length; i++) {
      _expanded.add(path.take(i).join('/'));
    }
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  void _openFolder(List<String> path) {
    _syncExpanded(path);
    _analytics.logFolderOpen(path.isEmpty ? 'root' : path.join(' / '));
    setState(() {
      _currentPath = List.of(path);
      _query = '';
      _searchController.clear();
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

  /// Opens [item] in the in-page viewer. Downloads go through [_download].
  Future<void> _open(DocumentItem item) async {
    await showDocumentViewer(
      context: context,
      url: _api.viewUri(item).toString(),
    );
    _markOpened(item);
    if (item.isPdf) _analytics.logDocumentView(item.name);
  }

  /// Downloads [item] to disk (opens the download URL in a new tab).
  Future<void> _download(DocumentItem item) async {
    if (_busy != null) return;
    setState(() => _busy = item.name);
    try {
      final launched = await launchUrl(
        _api.downloadUri(item),
        webOnlyWindowName: '_blank',
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de télécharger le document.')),
        );
      }
      _markOpened(item);
      if (item.isPdf) _analytics.logDocumentDownload(item.name);
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

  /// Adds an opened PDF to the recents list and bumps the download metric.
  void _markOpened(DocumentItem item) {
    if (!item.isPdf || !mounted) return;
    setState(() {
      final segments = item.name.split('/');
      final location = segments.length > 1
          ? segments.take(segments.length - 1).join(' / ')
          : 'Racine';
      _recents.removeWhere((e) => e.document.name == item.name);
      _recents.insert(
        0,
        _RecentEntry(
          title: item.displayName,
          location: location,
          document: item,
          openedAt: DateTime.now(),
        ),
      );
      if (_recents.length > _maxRecents) {
        _recents.removeRange(_maxRecents, _recents.length);
      }
    });
    _persistRecents();
    _stats.incrementDownloads();
  }

  LibraryFolder get _root => _index?.root ?? buildLibraryTree(_all);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        width: 292,
        child: _buildSidebar(
          onMenu: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            return Row(
              children: [
                if (wide && !_sidebarCollapsed)
                  SizedBox(width: 292, child: _buildSidebar(onMenu: _toggleSidebar))
                else
                  const SizedBox.shrink(),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        wide: wide,
                        collapsed: _sidebarCollapsed,
                        showMenu: !wide || _sidebarCollapsed,
                        currentPath: _currentPath,
                        onMenu: wide
                            ? _toggleSidebar
                            : () => Scaffold.of(context).openDrawer(),
                        onHome: _goHome,
                        onNavigate: _openFolder,
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

  Widget _buildSidebar({VoidCallback? onMenu}) {
    final index = _index;
    final searching = _query.trim().isNotEmpty && index != null;
    return LibrarySidebar(
      root: _root,
      currentPath: _currentPath,
      expanded: _expanded,
      onToggle: _toggleNode,
      onOpenFolder: _openFolder,
      onOpenFile: _open,
      searchController: _searchController,
      onSearchChanged: (value) => setState(() => _query = value),
      searchQuery: searching ? _query : '',
      searchResults: searching ? index.search(_query) : const [],
      treeScrollController: _treeScroll,
      onMenu: onMenu,
    );
  }

  Widget _buildContent() {
    return FutureBuilder<List<DocumentItem>>(
      future: _future,
      builder: (context, snapshot) {
        // Header + footer render immediately; only the recents area waits.
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final error = snapshot.hasError;
        final docs = snapshot.data ?? const <DocumentItem>[];
        if (!loading && !error) {
          _all = docs;
          _prepare(docs);
        }
        return _buildBody(
          loading: loading,
          error: error,
          docs: docs,
          onReload: _reload,
        );
      },
    );
  }

  Widget _buildBody({
    required bool loading,
    required bool error,
    required List<DocumentItem> docs,
    required VoidCallback onReload,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minContent = constraints.maxHeight - _headerHeight;
        return _scrollable(
          children: [
            const _Header(),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _maxContentWidth,
                  minHeight: minContent > 0 ? minContent : 0,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    AppSpacing.giant,
                    24,
                    AppSpacing.huge,
                  ),
                  child: Builder(builder: (context) {
                    if (loading) {
                      return const _RecentsSkeleton();
                    }
                    if (error) {
                      return ErrorView(onRetry: onReload);
                    }
                    if (docs.isEmpty) {
                      return EmptyView(onRefresh: onReload);
                    }
                    if (_currentPath.isEmpty) {
                      return _RecentSection(
                        entries: _recents,
                        onOpenFile: _open,
                      );
                    }
                    final folder = _root.descend(_currentPath);
                    if (folder == null) {
                      return EmptyView(onRefresh: onReload);
                    }
                    return FolderContentView(
                      folder: folder,
                      busy: _busy,
                      onView: _open,
                      onDownload: _download,
                    );
                  }),
                ),
              ),
            ),
            AppFooter(
              documents: docs.length,
              countersStream: _stats.watch(),
              scrollController: _contentScroll,
            ),
          ],
        );
      },
    );
  }

  Widget _scrollable({required List<Widget> children}) {
    return ListView(
      key: const ValueKey('mainScroll'),
      controller: _contentScroll,
      padding: EdgeInsets.zero,
      children: children,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.wide,
    required this.collapsed,
    required this.showMenu,
    required this.currentPath,
    required this.onMenu,
    required this.onHome,
    required this.onNavigate,
  });

  final bool wide;
  final bool collapsed;

  /// Whether the hamburger button should be rendered (hidden when the
  /// sidebar already shows one on wide expanded layouts).
  final bool showMenu;

  final List<String> currentPath;
  final VoidCallback onMenu;
  final VoidCallback onHome;
  final void Function(List<String> path) onNavigate;

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
              onPressed: onMenu,
              tooltip: wide
                  ? (collapsed
                        ? 'Afficher la barre latérale'
                        : 'Masquer la barre latérale')
                  : 'Menu',
              icon: const Icon(Icons.menu_rounded, size: 20),
              color: AppColors.secondary,
              hoverColor: AppColors.hover,
              splashRadius: 18,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.sm),
            const IloveprepaBrand(fontSize: 20, iconSize: 18),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            child: currentPath.isEmpty
                ? const SizedBox.shrink()
                : BreadcrumbBar(
                    segments: currentPath,
                    onTap: (index) =>
                        index == -1 ? onHome() : onNavigate(currentPath.take(index + 1).toList()),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/header.png',
      width: double.infinity,
      height: 220,
      fit: BoxFit.cover,
    );
  }
}

class _RecentsSkeleton extends StatelessWidget {
  const _RecentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 3; i++) ...[
          const SkeletonCard(),
          if (i < 2) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RecentEntry {
  const _RecentEntry({
    required this.title,
    required this.location,
    required this.document,
    required this.openedAt,
  });

  final String title;
  final String location;
  final DocumentItem document;
  final DateTime openedAt;
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.entries,
    required this.onOpenFile,
  });

  final List<_RecentEntry> entries;
  final void Function(DocumentItem doc) onOpenFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.xs,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecentHeader(count: entries.length),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          if (entries.isEmpty)
            const _EmptyRecent()
          else
            for (final entry in entries)
              _RecentRow(
                entry: entry,
                isLast: identical(entry, entries.last),
                onTap: () => onOpenFile(entry.document),
              ),
        ],
      ),
    );
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            'Récents',
            style: AppTypography.tileTitle(AppColors.darkCharcoal),
          ),
          const Spacer(),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
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
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
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
              Icons.history_rounded,
              size: 26,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Aucun fichier récent',
            style: AppTypography.label(AppColors.darkCharcoal),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Les fichiers PDF que vous ouvrez apparaîtront ici.',
            textAlign: TextAlign.center,
            style: AppTypography.metadata(AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatefulWidget {
  const _RecentRow({
    required this.entry,
    required this.isLast,
    required this.onTap,
  });

  final _RecentEntry entry;
  final bool isLast;
  final VoidCallback onTap;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.hover : AppColors.sidebar,
            border: Border(
              bottom: widget.isLast
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              const NotionPdfIcon(size: 34),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: AppTypography.metadata(AppColors.darkCharcoal)
                          .copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.location} · ${_timeAgo(entry.openedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metadata(AppColors.muted).copyWith(
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} jours';
  if (diff.inDays < 30) return 'il y a ${diff.inDays ~/ 7} sem.';
  return 'il y a ${diff.inDays ~/ 30} mois';
}
