import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../core/theme/app_spacing.dart';
import '../models/document_item.dart';
import '../models/library_folder.dart';
import '../models/library_index.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/stats_service.dart';
import '../utils/web_download.dart';
import '../widgets/app_footer.dart';
import '../widgets/document_viewer.dart';
import '../widgets/folder_content_view.dart';
import '../widgets/iloveprepa_brand.dart';
import '../widgets/contact_form_view.dart';
import '../widgets/don_view.dart';
import '../widgets/landing/landing_colors.dart' as landing;
import '../widgets/library_sidebar.dart';
import '../widgets/overview_view.dart';
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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// True once the drawer has been auto-opened on first entry (narrow
  /// screens). One-shot: the user can close it and it never pops open again
  /// during the same visit.
  bool _openedDrawerOnce = false;
  DateTime? _drawerOpenAt;

  late final ApiService _api = widget.api ?? ApiService();
  late final StatsService _stats = widget.stats ?? StatsService();
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();
  final _searchController = TextEditingController();

  // Keeps the main content's scroll position and drives the footer's
  // visibility-triggered count-up.
  final ScrollController _contentScroll = ScrollController();

  List<DocumentItem> _all = const [];
  LibraryIndex? _index;
  String _query = '';
  String? _busy;
  Object? _apiError;

  // Keeps the sidebar tree's scroll position across a search round-trip.
  final ScrollController _treeScroll = ScrollController();

  // Sidebar tree expansion (keys are full folder paths).
  final Set<String> _expanded = {};

  // Currently open folder path, shown as a breadcrumb + highlighted.
  List<String> _currentPath = const [];

  // Path of the last folder that actually contained files. Carries which
  // folder's files stay visible: the welcome message only shows until the
  // first folder with files is opened; after that, intermediate folders keep
  // showing these files instead of reverting to the welcome card.
  String? _lastFilesPath;

  // Sidebar collapsed state on wide screens.
  bool _sidebarCollapsed = false;

  // Whether the contact form replaces the main content area.
  bool _showContactForm = false;

  /// Bumped every time the Contact button is pressed so the contact form is
  /// rebuilt from scratch (fresh blank form instead of the last success view).
  int _contactEpoch = 0;

  bool _showDon = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _seedFromCache();
    _scheduleBootReady();
    _analytics.logAppOpen();
    _analytics.logScreenView('dashboard');
    unawaited(_precacheContactIllustration());
  }

  /// Kicks off the API refresh in the background (never blocks the UI). The
  /// response is written to [_all] and triggers a rebuild; a failure is
  /// captured in [_apiError] and only shown if no cached data exists.
  void _loadDocuments() {
    _api.fetchDocuments().then((docs) {
      try {
        web.window.localStorage.setItem(
          'flutter.cached_documents',
          jsonEncode(docs.map((d) => d.toJson()).toList()),
        );
      } catch (_) {}
      if (mounted) {
        _apiSettled = true;
        setState(() { _all = docs; _apiError = null; });
        _maybeEmitBootReady();
      }
      return docs;
    }).catchError((e) {
      if (mounted) {
        _apiSettled = true;
        setState(() => _apiError = e);
        _maybeEmitBootReady();
      }
      return <DocumentItem>[];
    });
  }

  /// Hides the boot splash only once the first frame has rendered AND the
  /// library is on screen — either seeded from localStorage or fed by the
  /// first API response — so nothing is ever "missing" when the splash fades.
  /// A hard fallback timer guarantees the splash can never trap the page.
  void _scheduleBootReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firstFrameDone = true;
      _maybeEmitBootReady();
      _bootFallback ??= Timer(const Duration(seconds: 6), _emitBootReady);
    });
  }

  bool _firstFrameDone = false;
  bool _apiSettled = false;
  bool _bootEmitted = false;
  Timer? _bootFallback;

  void _maybeEmitBootReady() {
    if (_bootEmitted || !_firstFrameDone) return;
    if (_all.isEmpty && !_apiSettled) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || _bootEmitted) return;
      final drawerOpened = _drawerOpenAt;
      var remaining = Duration.zero;
      if (_isMobileWeb && drawerOpened != null) {
        final sinceOpen =
            DateTime.now().difference(drawerOpened).inMilliseconds;
        remaining = Duration(milliseconds: 280 - sinceOpen);
      }
      if (remaining > Duration.zero) {
        Future.delayed(remaining, _emitBootReady);
      } else {
        _emitBootReady();
      }
    });
  }

  void _emitBootReady() {
    if (_bootEmitted) return;
    _bootEmitted = true;
    _bootFallback?.cancel();
    if (!mounted) return;
    web.document.dispatchEvent(web.Event('iloveprepa-data-ready'));
  }

  /// Warms the SVG cache the Contact illustration uses so the artwork appears
  /// instantly the first time the Contact form is opened — even if the user
  /// never opened it before, the assets are fetched as soon as the app boots.
  static const _contactArtAssets = [
    'assets/illustrations/contact_art.svg',
    'assets/illustrations/contact_envelope.svg',
    'assets/illustrations/contact_star1.svg',
    'assets/illustrations/contact_star2.svg',
    'assets/illustrations/contact_star3.svg',
    'assets/illustrations/contact_star4.svg',
    'assets/illustrations/contact_star5.svg',
    'assets/illustrations/contact_star6.svg',
  ];

  Future<void> _precacheContactIllustration() async {
    try {
      await Future.wait(_contactArtAssets.map(
        (asset) => SvgAssetLoader(asset).loadBytes(null),
      ));
    } catch (_) {
      // Preloading is a best-effort optimization; rendering handles failures.
    }
  }

  /// Synchronously restores the last library listing from localStorage so the
  /// sidebar folder text/icons are present on the very first frame of every
  /// open (the network refresh updates it right behind). The fetch writes the
  /// same key, so the two always stay in sync.
  void _seedFromCache() {
    try {
      final raw = web.window.localStorage.getItem('flutter.cached_documents');
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isEmpty) return;
      _all = list;
      _index = LibraryIndex(list);
      _expandAll(_index!.root);
    } catch (_) {}
  }

  void _expandAll(LibraryFolder node, [List<String>? prefix]) {
    final path = prefix ?? const <String>[];
    for (final child in node.children.values) {
      final childPath = [...path, child.name];
      _expanded.add(childPath.join('/'));
      _expandAll(child, childPath);
    }
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
      // Keep _all/_index so the sidebar folder tree stays visible while the
      // retry runs; only the error state and the search are cleared.
      _query = '';
      _apiError = null;
      _searchController.clear();
    });
    _loadDocuments();
  }

  void _prepare(List<DocumentItem> docs) {
    if (docs.isEmpty) return;
    if (_index != null && _all.isNotEmpty && _all.length == docs.length) return;
    _index = LibraryIndex(docs);
    _expandAll(_index!.root);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
  }

  void _openContactForm() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).maybePop();
    }
    _resetScroll();
    setState(() {
      _showContactForm = true;
      _contactEpoch++;
      _showDon = false;
    });
  }

  void _openDonForm() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).maybePop();
    }
    _resetScroll();
    setState(() {
      _showDon = true;
      _showContactForm = false;
    });
  }

  /// Returns the shared scroll to the top before switching pages, so every
  /// page (library / contact / donate) always starts at its beginning.
  void _resetScroll() {
    if (_contentScroll.hasClients) {
      _contentScroll.jumpTo(0);
    }
  }

  void _closeContactForm() {
    setState(() => _showContactForm = false);
  }

  void _openFolder(List<String> path) {
    _analytics.logFolderOpen(path.isEmpty ? 'root' : path.join(' / '));
    setState(() {
      _showContactForm = false;
      _showDon = false;
      _currentPath = List.of(path);
      // Clicking a folder toggles it: if it's already open, close its whole
      // branch; otherwise open it. Other folders the user has opened stay as
      // they were — opening one never collapses the rest.
      final key = path.join('/');
      if (_expanded.remove(key)) {
        _expanded.removeWhere((k) => k == key || k.startsWith('$key/'));
      } else {
        _expanded.addAll(_ancestors(path));
        _rememberFiles(path);
      }
      _query = '';
      _searchController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wide = MediaQuery.sizeOf(context).width >= 960;
      if (wide) {
        if (_sidebarCollapsed) setState(() => _sidebarCollapsed = false);
      } else {
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).maybePop();
        }
      }
    });
  }

  /// Once a folder that directly contains files is opened, remember it so the
  /// welcome message can be retired for good and its files stay visible even
  /// while browsing an intermediate folder.
  void _rememberFiles(List<String> path) {
    if (path.isEmpty) return;
    final folder = _root.descend(path);
    if (folder != null && folder.files.isNotEmpty) {
      _lastFilesPath = path.join('/');
    }
  }

  /// The folder whose files should be shown in the content area, or null if
  /// the user has not opened a folder containing files yet.
  List<String>? get _filesPath {
    final current = _root.descend(_currentPath);
    if (current != null && current.files.isNotEmpty) {
      return _currentPath;
    }
    if (_lastFilesPath == null) return null;
    return _lastFilesPath!.split('/');
  }

  /// Every ancestor prefix of [path] (the path itself included), used to
  /// expand exactly the branch that leads to the opened folder.
  List<String> _ancestors(List<String> path) => [
    for (var i = 1; i <= path.length; i++) path.take(i).join('/'),
  ];

  void _goHome() {
    setState(() {
      _showContactForm = false;
      _showDon = false;
      _currentPath = const [];
      _query = '';
      _searchController.clear();
    });
  }

  /// Brand tap: resets the whole dashboard to its initial state, exactly like
  /// reloading the page — root folder, cleared search, collapsed tree, contact
  /// and donation views closed, sidebar expanded, scrolled to the top.
  void _goToLanding() {
    setState(() {
      _showContactForm = false;
      _showDon = false;
      _currentPath = const [];
      _query = '';
      _searchController.clear();
      _expanded.clear();
      _lastFilesPath = null;
      _sidebarCollapsed = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).maybePop();
      }
      if (_contentScroll.hasClients) {
        _contentScroll.jumpTo(0);
      }
    });
  }

  void _toggleNode(List<String> path) {
    final key = path.join('/');
    final opening = !_expanded.contains(key);
    setState(() {
      if (!_expanded.remove(key)) _expanded.add(key);
      // Expanding a folder also shows its documents in the main page, just
      // like clicking the folder itself. Collapsing leaves the view alone.
      if (opening) {
        _currentPath = List.of(path);
        _rememberFiles(path);
        _query = '';
        _searchController.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final wide = MediaQuery.sizeOf(context).width >= 960;
      if (wide) {
        if (_sidebarCollapsed) setState(() => _sidebarCollapsed = false);
      } else {
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).maybePop();
        }
      }
    });
  }

  void _toggleSection(List<String> path) {
    final key = path.join('/');
    setState(() {
      if (!_expanded.remove(key)) _expanded.add(key);
    });
  }

  /// True when running in a mobile browser (phone/tablet). Phones keep the
  /// in-app viewer; desktop browsers open documents in a new browser tab.
  bool get _isMobileWeb =>
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Opens [item]. On desktop web the browser's native PDF viewer opens in a
  /// new tab, so users can view several documents side by side and the
  /// library keeps its state when they come back. Phones and non-web builds
  /// open a simple in-app viewer in the same page. Downloads go through
  /// [_download]. The download counter is bumped no matter what (even if the
  /// platform view fails to build), so the metric is never lost to an
  /// exception.
  Future<void> _open(DocumentItem item) async {
    try {
      if (kIsWeb && !_isMobileWeb) {
        await launchUrl(
          _api.viewUri(item),
          webOnlyWindowName: '_blank',
        );
      } else {
        await showDocumentViewer(
          context: context,
          url: _api.viewUri(item).toString(),
          downloadUrl: _api.downloadUri(item).toString(),
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

  /// Registers a download metric when a document is opened or downloaded. Sent
  /// to the backend immediately and reflected optimistically in the footer.
  void _markOpened(DocumentItem item) {
    _stats.logDownload();
  }

  LibraryFolder get _root => _index?.root ?? buildLibraryTree(_all);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
            if (!wide && !_openedDrawerOnce) {
              _openedDrawerOnce = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _drawerOpenAt = DateTime.now();
                _scaffoldKey.currentState?.openDrawer();
              });
            }
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
                          onContact: _openContactForm,
                          onDon: _openDonForm,
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
    if (_showContactForm) {
      return _viewPage(
        child: ContactFormView(
          key: ValueKey(_contactEpoch),
          onBack: _closeContactForm,
        ),
      );
    }
    if (_showDon) {
      return const DonView();
    }

    // Always show content from _all immediately (populated from cache by
    // _seedFromCache() on repeat visits, or fed by _loadDocuments() on the
    // first visit — the boot splash is what waits for the data to be here).
    final docs = _all;
    final loading = docs.isEmpty && _apiError == null;
    if (!loading && _index == null) {
      _prepare(docs);
    }
    return _buildBody(
      loading: loading,
      error: _apiError,
      docs: docs,
      onReload: _reload,
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
        return _scrollable(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _maxContentWidth,
                  minHeight: constraints.maxHeight,
                ),
                child: _content(
                  docs: docs,
                  loading: loading,
                  error: error,
                  onReload: onReload,
                ),
              ),
            ),
            _buildAppFooter(),
          ],
        );
      },
    );
  }

  /// The main content that switches between loading / error / empty / welcome
  /// / documents depending on the current state.
  Widget _content({
    required List<DocumentItem> docs,
    required bool loading,
    required Object? error,
    required VoidCallback onReload,
  }) {
    return Builder(builder: (context) {
      final isOverview =
          !loading && error == null && docs.isNotEmpty && _currentPath.isEmpty;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          isOverview ? AppSpacing.lg : AppSpacing.giant + AppSpacing.xxl,
          24,
          AppSpacing.huge,
        ),
        child: Builder(builder: (context) {
        if (loading) {
          return const SizedBox.shrink();
        }
        if (error != null) {
          // Every type of backend error (quota exceeded, throttling, timeout,
          // unreachable server) shows the same "come back later" page.
          return ComeBackLaterView(onRetry: onReload);
        }
        if (docs.isEmpty) {
          return EmptyView(onRefresh: onReload);
        }
        if (_currentPath.isEmpty) {
          return OverviewView(
            folders: _root.children.values.toList(),
            onOpenFolder: _openFolder,
          );
        }
        final folder = _root.descend(_currentPath);
        if (folder == null) {
          return EmptyView(onRefresh: onReload);
        }
        return FolderContentView(
          folder: folder,
          currentPath: _currentPath,
          expanded: _expanded,
          busy: _busy,
          onView: _open,
          onDownload: _download,
          onOpenFolder: _openFolder,
          onToggle: _toggleSection,
        );
      }),
    );
  });
  }

  /// Renders a full-page view (contact / donate) without the shared stats
  /// footer. The view fills the available height and scrolls if its content is
  /// taller than the screen.
  Widget _viewPage({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _scrollable(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The shared stats footer, used on the library page and at the bottom of
  /// the contact / donate pages.
  Widget _buildAppFooter() {
    return AppFooter(
      documents: _all.length,
      countersStream: _stats.watch(),
      scrollController: _contentScroll,
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
    required this.onContact,
    required this.onDon,
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

  /// Opens the contact form in the main content area.
  final VoidCallback onContact;

  /// Opens the donation screen in the main content area.
  final VoidCallback onDon;

  final void Function(List<String> path) onNavigate;

  /// Returns to the landing page when the brand mark is tapped.
  final VoidCallback onBrandTap;

@override
  Widget build(BuildContext context) {
return Container(
      height: 68,
      padding: EdgeInsets.fromLTRB(wide ? 40 : 4, 0, wide ? 40 : 20, 0),
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
              icon: const Icon(Icons.menu_rounded, size: 24),
              color: Colors.white,
              hoverColor: Colors.white12,
              splashRadius: 20,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints.tightFor(width: 36, height: 40),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (!wide)
            IloveprepaBrand(
              fontSize: 26,
              iconSize: 24,
              color: Colors.white,
              onTap: onBrandTap,
            ),
          const Spacer(),
_HeaderIconButton(
            tooltip: 'Contact',
            image: 'assets/icon/contact.png',
            color: const Color(0xFF3B5998),
            size: 40,
            onPressed: onContact,
          ),
          SizedBox(width: wide ? 36 : 20),
          _HeaderIconButton(
            tooltip: 'Don',
            image: 'assets/icon/don.png',
            color: const Color(0xFFFF923C),
            size: 48,
            onPressed: onDon,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.image,
    required this.color,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
  });

  final String image;

  /// Color the icon is tinted with on hover / press (social-button style).
  final Color color;

  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _active => _controller.value > 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setActive(bool active) {
    if (active == _active) return;
    if (active) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setActive(true),
      onExit: (_) => _setActive(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: (_) => _setActive(true),
        onTapCancel: () => _setActive(false),
        child: Tooltip(
          message: widget.tooltip ?? '',
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(_controller.value);
              return Transform.scale(
                scale: 1 + 0.08 * t,
                child: child,
              );
            },
            child: Image.asset(
              widget.image,
              height: widget.size,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
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


