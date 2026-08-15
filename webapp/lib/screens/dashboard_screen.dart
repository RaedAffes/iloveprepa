import 'package:flutter/foundation.dart';
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
import '../utils/web_download.dart';
import '../widgets/app_footer.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/document_viewer.dart';
import '../widgets/folder_content_view.dart';
import '../widgets/iloveprepa_brand.dart';
import '../widgets/landing/landing_colors.dart' as landing;
import '../widgets/library_sidebar.dart';
import '../widgets/skeleton_card.dart';
import '../widgets/state_views.dart';

/// Near-black ink for titles and the big welcome message.
const Color _ink = Color(0xFF1B1B1B);

/// Muted grey for secondary text.
const Color _greyMuted = Color(0xFF6B7280);

/// True when running in a mobile browser (phone/tablet). Desktop browsers
/// keep the in-app iframe viewer; phones open the browser's native PDF viewer
/// because iOS Safari cannot render PDFs inside iframes.
bool get _isMobileWeb =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

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
  /// The download counter is bumped no matter what (even if the platform view
  /// fails to build), so the metric is never lost to an exception.
  Future<void> _open(DocumentItem item) async {
    try {
      if (_isMobileWeb) {
        // On phones the in-page <iframe> PDF viewer is unreliable (iOS Safari
        // does not render PDFs inside iframes), so open the browser's native
        // PDF viewer in a new tab instead. The app keeps its state when the
        // user returns.
        await launchUrl(
          _api.viewUri(item),
          webOnlyWindowName: '_blank',
        );
      } else {
        await showDocumentViewer(
          context: context,
          url: _api.viewUri(item).toString(),
        );
      }
    } finally {
      _markOpened(item);
      if (item.isPdf) _analytics.logDocumentView(item.name);
    }
  }

  /// Downloads [item] to disk. Uses a hidden-anchor click so no tab opens and
  /// no popup blocker can ever interfere, on desktop or mobile.
  Future<void> _download(DocumentItem item) async {
    if (_busy != null) return;
    setState(() => _busy = item.name);
    try {
      final ok = await triggerWebDownload(
        _api.downloadUri(item).toString(),
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de télécharger le document.')),
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
      _markOpened(item);
      if (item.isPdf) _analytics.logDocumentDownload(item.name);
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Bumps the download metric when a document is opened or downloaded.
  void _markOpened(DocumentItem item) {
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
        // The page scrolls as one: header image first, then the content, and
        // the stats footer at the bottom (revealed when scrolling down).
        final headerHeight = _headerHeightFor(context);
        final minContent = constraints.maxHeight - headerHeight;
        return _scrollable(
          children: [
            _Header(height: headerHeight),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _maxContentWidth,
                  minHeight: minContent > 0 ? minContent : 0,
                ),
                child: _content(
                  docs: docs,
                  loading: loading,
                  error: error,
                  onReload: onReload,
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

  /// Header image height, slightly taller on big screens.
  double _headerHeightFor(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 860 ? 170 : 280;

  /// The main content that switches between loading / error / empty / welcome
  /// / documents depending on the current state.
  Widget _content({
    required List<DocumentItem> docs,
    required bool loading,
    required Object? error,
    required VoidCallback onReload,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        AppSpacing.giant + AppSpacing.xxl,
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
          return const _WelcomeMessage();
        }
        final folder = _root.descend(_currentPath);
        if (folder == null) {
          return EmptyView(onRefresh: onReload);
        }
        // Only folders that actually contain files show them. An intermediate
        // folder (subfolders but no direct files) keeps the welcome message
        // until a leaf folder is opened.
        if (folder.files.isEmpty) {
          return const _WelcomeMessage();
        }
        return FolderContentView(
          folder: folder,
          busy: _busy,
          onView: _open,
          onDownload: _download,
        );
      }),
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
  const _Header({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/header.png',
      width: double.infinity,
      height: height,
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

/// Big, friendly call-to-action shown on first entry (no folder opened yet): a
/// beautiful card telling the user to press the hamburger button to open the
/// library. It stays until a folder is opened and its documents appear on the
/// main page.
class _WelcomeMessage extends StatelessWidget {
  const _WelcomeMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.giant,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardR,
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppShadows.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                children: [
                  const Text(
                    'Appuyez sur le bouton',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Icon(
                    Icons.menu_rounded,
                    size: 30,
                    color: landing.AppColors.midBlue,
                  ),
                  const Text(
                    'pour commencer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w300,
                      height: 1.25,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Ouvrez le menu pour parcourir vos cours, devoirs et examens.',
                textAlign: TextAlign.center,
                style: AppTypography.metadata(_greyMuted).copyWith(
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

