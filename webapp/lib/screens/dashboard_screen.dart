import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';
import '../models/library_index.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/stats_service.dart';
import '../widgets/app_footer.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/document_viewer.dart';
import '../widgets/folder_content_view.dart';
import '../widgets/iloveprepa_brand.dart';
import '../widgets/landing/landing_colors.dart' as landing;
import '../widgets/library_sidebar.dart';
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

  // Path of the last folder whose documents are shown on the main page. Kept
  // so the documents persist while browsing intermediate folders that have no
  // files of their own (they stay until another folder with files is opened).
  List<String>? _shownDocumentsPath;

  // Sidebar collapsed state on wide screens.
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchDocuments();
    _analytics.logAppOpen();
    _analytics.logScreenView('dashboard');
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
      _currentPath = const [];
      _query = '';
      _searchController.clear();
      _future = _api.fetchDocuments();
    });
  }

  void _prepare(List<DocumentItem> docs) {
    if (_index != null) return;
    _index = LibraryIndex(docs);
    // Rebuild the sidebar now that the tree is ready. All folders start
    // collapsed: nothing is expanded until the user opens a folder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  void _openFolder(List<String> path) {
    _analytics.logFolderOpen(path.isEmpty ? 'root' : path.join(' / '));
    setState(() {
      _currentPath = List.of(path);
      _expanded
        ..clear()
        ..addAll(_ancestors(path));
      final folder = _root.descend(path);
      if (folder != null && folder.files.isNotEmpty) {
        _shownDocumentsPath = List.of(path);
      }
      _query = '';
      _searchController.clear();
    });
  }

  /// Every ancestor prefix of [path] (the path itself included), used to
  /// expand exactly the branch that leads to the opened folder.
  List<String> _ancestors(List<String> path) => [
    for (var i = 1; i <= path.length; i++) path.take(i).join('/'),
  ];

  void _goHome() {
    setState(() {
      _currentPath = const [];
      _shownDocumentsPath = null;
      _query = '';
      _searchController.clear();
    });
  }

  /// Returns to the marketing landing page (the route underneath the library).
  /// Closes any open drawer along the way.
  void _goToLanding() {
    Navigator.of(context).popUntil((route) => route.isFirst);
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

  /// Bumps the download metric when a document is opened or downloaded.
  void _markOpened(DocumentItem item) {
    if (!item.isPdf || !mounted) return;
    _stats.incrementDownloads();
  }

  LibraryFolder get _root => _index?.root ?? buildLibraryTree(_all);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        width: 320,
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
                  SizedBox(width: 320, child: _buildSidebar(onMenu: _toggleSidebar))
                else
                  const SizedBox.shrink(),
                Expanded(
                  child: Container(
                    color: landing.AppColors.lightBg,
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
                          onBrandTap: _goToLanding,
                        ),
                        Expanded(child: _buildContent()),
                      ],
                    ),
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
      onBrandTap: _goToLanding,
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
        final error = snapshot.hasError ? snapshot.error : null;
        final docs = snapshot.data ?? const <DocumentItem>[];
        if (!loading && error == null) {
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
    required Object? error,
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
                      return const _LoadingSkeleton();
                    }
                    if (error != null) {
                      return ErrorView(
                        onRetry: onReload,
                        detail: _describeError(error),
                        apiBase: ApiService.apiBase,
                      );
                    }
                    if (docs.isEmpty) {
                      return EmptyView(onRefresh: onReload);
                    }
                    if (_currentPath.isEmpty) {
                      final root = _root;
                      if (root.files.isNotEmpty) {
                        return FolderContentView(
                          folder: root,
                          busy: _busy,
                          onView: _open,
                          onDownload: _download,
                        );
                      }
                      return const _LibraryOverview();
                    }
                    final folder = _root.descend(_currentPath);
                    if (folder == null) {
                      return EmptyView(onRefresh: onReload);
                    }
                    if (folder.files.isEmpty) {
                      LibraryFolder? shown;
                      final persisted = _shownDocumentsPath;
                      if (persisted != null) {
                        shown = _root.descend(persisted);
                      }
                      // With nothing persisted yet (e.g. coming from home), the
                      // root files stay on screen instead of going blank.
                      if (shown == null && _root.files.isNotEmpty) {
                        shown = _root;
                      }
                      if (shown != null && shown.files.isNotEmpty) {
                        return FolderContentView(
                          folder: shown,
                          busy: _busy,
                          onView: _open,
                          onDownload: _download,
                        );
                      }
                      return FolderContentView(
                        folder: folder,
                        busy: _busy,
                        onView: _open,
                        onDownload: _download,
                      );
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

  String _describeError(Object? error) {
    if (error is ApiException) return '${error.message}\n\n$error';
    final text = error.toString();
    if (text.contains('TimeoutException')) {
      return 'Le serveur a mis trop de temps à répondre.\n\n$text';
    }
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return 'Connexion au serveur impossible. Vérifiez le réseau.\n\n$text';
    }
    return text;
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
    required this.onBrandTap,
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

  /// Returns to the landing page when the brand mark is tapped.
  final VoidCallback onBrandTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: landing.AppColors.midBlue,
        border: Border(bottom: BorderSide(color: Color(0x33FFFFFF), width: 1)),
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
              color: Colors.white,
              hoverColor: Colors.white12,
              splashRadius: 18,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.sm),
            IloveprepaBrand(
              fontSize: 20,
              iconSize: 18,
              color: Colors.white,
              onTap: onBrandTap,
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            child: currentPath.isEmpty
                ? const SizedBox.shrink()
                : BreadcrumbBar(
                    segments: currentPath,
                    onDark: true,
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

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

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

/// Branded home panel shown when the library has no files at its root:
/// a blue gradient header plus orange/blue stat tiles (documents, folders,
/// storage) so the landing page never feels empty.
class _LibraryOverview extends StatelessWidget {
  const _LibraryOverview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardR,
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppShadows.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      landing.AppColors.midBlue,
                      landing.AppColors.brightBlue,
                      landing.AppColors.accentBlue,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -40,
                      top: -40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 120,
                      bottom: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: landing.AppColors.orange
                              .withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: landing.AppColors.orange,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.folder_copy_outlined,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Votre bibliothèque',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Retrouvez vos cours et vos documents.',
                                style: TextStyle(
                                  color: landing.AppColors.mutedWhite,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _OverviewTile(
                        color: landing.AppColors.orange,
                        icon: Icons.description_outlined,
                        label: 'Documents',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _OverviewTile(
                        color: landing.AppColors.accentBlue,
                        icon: Icons.folder_outlined,
                        label: 'Dossiers',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _OverviewTile(
                        color: landing.AppColors.midBlue,
                        icon: Icons.cloud_outlined,
                        label: 'Stockage',
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: landing.AppColors.accentBlue,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Naviguez dans vos dossiers depuis la barre latérale à gauche.',
                        style: TextStyle(
                          color: landing.AppColors.midBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.cardSmallR,
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.metadata(color).copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

