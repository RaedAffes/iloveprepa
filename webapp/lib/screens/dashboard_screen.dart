import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    _future = _api.fetchDocuments();
    _future.then((docs) async {
      try {
        web.window.localStorage.setItem(
          'flutter.cached_documents',
          jsonEncode(docs.map((d) => d.toJson()).toList()),
        );
      } catch (_) {}
      _notifyBootReady();
    }).catchError((_) => _notifyBootReady());
    _seedFromCache();
    _analytics.logAppOpen();
    _analytics.logScreenView('dashboard');
  }

  /// Tells the boot splash (web/index.html) to fade out only once the library
  /// data is fetched, rendered, AND the phone drawer has finished sliding in —
  /// so the sidebar text/icons are already fully on screen the first moment
  /// the splash disappears (no pop-in), with only the minimum wait added.
  void _notifyBootReady() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
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
    if (!mounted) return;
    web.document.dispatchEvent(web.Event('iloveprepa-data-ready'));
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
      _all = const [];
      _index = null;
      _currentPath = const [];
      _query = '';
      _searchController.clear();
      _future = _api.fetchDocuments();
    });
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
    setState(() {
      _showDon = true;
      _showContactForm = false;
    });
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

  /// Brand tap: leaves the contact / donation views and returns to the library
  /// main page with the exact folder / navigation state the user had before
  /// (nothing is reset). When those views are already closed this is a no-op.
  void _goToLanding() {
    setState(() {
      _showContactForm = false;
      _showDon = false;
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

  /// Queues a download metric when a document is opened or downloaded. It is
  /// only pushed to the backend once the footer becomes visible.
  void _markOpened(DocumentItem item) {
    _stats.queueDownload();
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
    return FutureBuilder<List<DocumentItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (_showContactForm) {
          return ContactFormView(
            key: ValueKey(_contactEpoch),
            onBack: _closeContactForm,
          );
        }
        if (_showDon) {
          return const DonView();
        }
        final isWaiting = snapshot.connectionState == ConnectionState.waiting;
        final hasSnapshotData = snapshot.hasData;
        final error = snapshot.hasError ? snapshot.error : null;
        final docs = hasSnapshotData ? snapshot.data! : _all;
        final loading = isWaiting && docs.isEmpty;
        if (!isWaiting && error == null && hasSnapshotData) {
          _all = docs;
          _prepare(docs);
        } else if (_all.isNotEmpty && _index == null) {
          _prepare(_all);
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
            AppFooter(
              documents: docs.length,
              countersStream: _stats.watch(),
              scrollController: _contentScroll,
              onFirstVisible: _stats.markFooterVisible,
            ),
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


