import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document_item.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/stats_service.dart';
import '../widgets/app_footer.dart';
import '../widgets/landing/hero_text.dart';
import '../widgets/landing/illustration_placeholder.dart';
import '../widgets/landing/landing_colors.dart';
import '../widgets/landing/nav_bar.dart';
import '../widgets/landing/wave_background.dart';
import 'dashboard_screen.dart';

/// Marketing landing page shown before the library. The "Bibliothèque" button
/// pushes the real library home ([DashboardScreen]) on top.
///
/// The page scrolls like a professional website: a full-height hero over the
/// wave background, then the "À propos", "Faire un don" and "Contact"
/// sections, then the shared stats footer. The nav bar scrolls to each
/// section.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key, this.stats, this.analytics, this.api});

  /// Test seam — forwarded to [DashboardScreen] when the user enters the
  /// library.
  final StatsService? stats;

  /// Test seam — forwarded to [DashboardScreen] when the user enters the
  /// library.
  final AnalyticsService? analytics;

  /// Test seam — defaults to a real [ApiService] (see [main]).
  final ApiService? api;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  final _StripHold _stripHold = _StripHold();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _donateKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();
  bool _autoScroll = false;

  late final StatsService _stats = widget.stats ?? StatsService();
  late final ApiService _api = widget.api ?? ApiService();
  late final Future<List<DocumentItem>> _documents = _api.fetchDocuments();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _stats.incrementVisits();
  }

  void _onScroll() {
    if (_scroll.hasClients) _scrollOffset.value = _scroll.offset;
  }

  void _openLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DashboardScreen(stats: _stats, analytics: widget.analytics),
      ),
    );
  }

  void _navigate(String section) {
    switch (section) {
      case 'about':
        _scrollTo(_aboutKey);
      case 'donate':
        _scrollTo(_donateKey);
      case 'contact':
        _scrollTo(_contactKey);
    }
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      _autoScroll = true;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      ).whenComplete(() => _autoScroll = false);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrollOffset.dispose();
    _stripHold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.lightBg,
      ),
      child: Scaffold(
        body: _ScrollScope(
          offset: _scrollOffset,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final isCompact = constraints.maxWidth < 600;
              // The nav bar is fixed at the top of the screen, so the scroll
              // content starts just below it.
              final headerHeight = _FixedHeader.contentHeight(context);
              final heroHeight =
                  (constraints.maxHeight - headerHeight).clamp(0.0, double.infinity);
              return Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scroll,
                    physics: _HoldPhysics(
                      hold: _stripHold,
                      parent: const BouncingScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Hero(
                          height: isWide ? heroHeight : null,
                          isWide: isWide,
                          isCompact: isCompact,
                          onLibraryPressed: () => _openLibrary(context),
                        ),
                        _AboutSection(
                          key: _aboutKey,
                          isWide: isWide,
                        ),
                        SizedBox(height: isWide ? 96 : 48),
                        _LibraryStrip(
                          scrollController: _scroll,
                          autoScroll: () => _autoScroll,
                          hold: _stripHold,
                        ),
                        _DonateSection(
                          key: _donateKey,
                          isWide: isWide,
                        ),
                        _ContactSection(
                          key: _contactKey,
                          isWide: isWide,
                        ),
                        FutureBuilder<List<DocumentItem>>(
                          future: _documents,
                          builder: (context, snapshot) {
                            return AppFooter(
                              documents: snapshot.data?.length ?? 0,
                              countersStream: _stats.watch(),
                              scrollController: _scroll,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _FixedHeader(isWide: isWide, onNavigate: _navigate),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Exposes the page's scroll offset to scroll-linked widgets below it.
class _ScrollScope extends InheritedWidget {
  const _ScrollScope({required this.offset, required super.child});

  final ValueNotifier<double> offset;

  static ValueNotifier<double> read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ScrollScope>()!.offset;

  @override
  bool updateShouldNotify(_ScrollScope oldWidget) => oldWidget.offset != offset;
}

/// One-shot entrance animation (used by the hero), staggered with [delay] as a
/// fraction of the total duration.
class _Entrance extends StatefulWidget {
  const _Entrance({required this.child, this.delay = 0});

  final Widget child;
  final double delay;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delay.clamp(0.0, 0.9),
      1.0,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(_animation),
        child: widget.child,
      ),
    );
  }
}

/// Parallax: the child scrolls at a slightly different speed than the page
/// (positive [factor] = the child lags behind).
class _Parallax extends StatelessWidget {
  const _Parallax({required this.child, required this.factor});

  final Widget child;
  final double factor;

  @override
  Widget build(BuildContext context) {
    final notifier = _ScrollScope.read(context);
    return AnimatedBuilder(
      animation: notifier,
      builder: (context, child) {
        final offset = notifier.value;
        final shift = (offset * factor).clamp(-140.0, 140.0);
        return Transform.translate(
          offset: Offset(0, shift),
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Shared state of the strip hold. While [holding] is true the page scroll is
/// absorbed and the user's scrolling is converted into box progress, so the
/// boxes only appear when the user scrolls (never automatically). Once
/// [progress] reaches 1.0 every box is fully visible and the hold releases.
class _StripHold extends ChangeNotifier {
  bool holding = false;
  bool done = false;
  double progress = 0;
  double heldOffset = 0;
  double _window = 1000;

  void start(double progressValue, double windowValue, double offsetValue) {
    holding = true;
    done = false;
    progress = progressValue;
    _window = windowValue;
    heldOffset = offsetValue;
    notifyListeners();
  }

  /// Accumulates [delta] scroll pixels (positive = scrolling down) into box
  /// progress. Returns true once every box is fully visible (hold released).
  bool feed(double delta) {
    progress += delta / _window;
    if (progress >= 1.0) {
      holding = false;
      done = true;
      progress = 1.0;
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  /// Marks the passage as complete without feeding, used when the nav bar
  /// programmatically scrolls past the strip, so it never re-engages (and
  /// rewinds the page) afterward.
  void skip() {
    holding = false;
    done = true;
    progress = 1.0;
    notifyListeners();
  }

  /// Called by the scroll physics for each touch/trackpad drag update. In
  /// Flutter a drag passes the raw finger delta here: negative = scrolling
  /// down, positive = scrolling back up. Scrolling down feeds the boxes and
  /// the page stays put; scrolling up passes through.
  double absorb(double attempted) {
    if (!holding) return attempted;
    if (attempted > 0) return attempted;
    return feed(-attempted) ? attempted : 0.0;
  }
}

/// Scroll physics used by the landing page: while the strip hold is active the
/// user's scroll is converted into box progress instead of moving the page.
class _HoldPhysics extends ScrollPhysics {
  const _HoldPhysics({super.parent, required this.hold});

  final _StripHold hold;

  @override
  _HoldPhysics applyTo(ScrollPhysics? ancestor) =>
      _HoldPhysics(parent: buildParent(ancestor), hold: hold);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      hold.absorb(offset);
}

/// "Votre bibliothèque" section: a plain block exactly the size of the
/// scroll_anim image (image fills it 1:1), with the four library cards
/// centered on it. As the section scrolls into view the cards cascade in
/// horizontally one after the other. When the strip reaches the header the
/// page holds still so the next section does not appear until every box is
/// completely visible — and boxes only appear while the user scrolls.
class _LibraryStrip extends StatefulWidget {
  const _LibraryStrip({
    required this.scrollController,
    required this.autoScroll,
    required this.hold,
  });

  final ScrollController scrollController;

  /// True while the nav bar is programmatically scrolling to a section; the
  /// hold is skipped in that case so anchors never get stuck.
  final bool Function() autoScroll;

  final _StripHold hold;

  static const _cards = <(String, String)>[
    ('assets/cours.png', 'Cours'),
    ('assets/td.png', 'TD'),
    ('assets/devoir.png', 'Ds'),
    ('assets/examen.png', 'Examens'),
  ];

  /// Staggered entrance for card [index]: the cascade starts as soon as the
  /// section scrolls into view, each card waiting a bit longer and taking a
  /// lot more scroll to fully appear (each box fades in very slowly, one after
  /// the other), so the whole reveal spans the strip's whole passage.
  static double _cardProgress(int index, double progress) {
    final start = index * 0.20;
    final local = ((progress - start) / 0.40).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
  }

  @override
  State<_LibraryStrip> createState() => _LibraryStripState();
}

class _LibraryStripState extends State<_LibraryStrip> {
  final GlobalKey _regionKey = GlobalKey();
  double _regionTop = 0;
  double _pinTop = 80;
  double _viewport = 800;
  double _stripHeight = 600;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  /// Cascade progress when the strip is at document position [top].
  double _scrollProgressFor(double top) {
    final cardCenter = top + _stripHeight / 2;
    return ((_viewport - cardCenter) / _revealWindow()).clamp(0.0, 1.0);
  }

  /// How much scrolling is needed to fully reveal the strip's boxes. Wider
  /// than one viewport on purpose so the boxes appear gradually over more
  /// scroll instead of all at once.
  double _revealWindow() => 2 * (_viewport + _stripHeight / 2);

  void _onScroll() {
    final offset = widget.scrollController.offset;
    final box = _regionKey.currentContext?.findRenderObject();
    final top = box is RenderBox && box.attached && box.hasSize
        ? box.localToGlobal(Offset.zero).dy
        : double.infinity;

    if (widget.autoScroll()) {
      // The nav bar is programmatically jumping past the strip: mark the
      // passage complete so it never re-engages (and rewinds) afterward.
      if (top != double.infinity && top <= _pinTop && !widget.hold.done) {
        widget.hold.skip();
      }
      return;
    }
    if (widget.hold.done) return;

    if (!widget.hold.holding) {
      // Engage the hold as soon as the strip's top has reached the header.
      // Keyed on the rendered position — not on whether the strip is still on
      // screen — so even a very fast scroll that jumps straight past the
      // strip cannot slip through: the page is rewound so the strip sits at
      // the header and every box must feed before the page moves on.
      if (top != double.infinity && top <= _pinTop) {
        final pinOffset = offset + top - _pinTop;
        widget.hold.start(
          _scrollProgressFor(_pinTop),
          _revealWindow(),
          pinOffset,
        );
        if ((offset - pinOffset).abs() > 0.5) {
          widget.scrollController.jumpTo(pinOffset);
        }
      }
      return;
    }

    // Any movement that got through the physics (mouse wheel, ballistic)
    // feeds the boxes, then the page is pulled back to the held position.
    final delta = offset - widget.hold.heldOffset;
    if (delta > 0 && !widget.hold.feed(delta)) {
      widget.scrollController.jumpTo(widget.hold.heldOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageWidth = MediaQuery.sizeOf(context).width;
    final viewport = MediaQuery.sizeOf(context).height;
    final notifier = _ScrollScope.read(context);

    // On phones the strip must be tall enough for two stacked rows of cards
    // (2x2 grid) so all four boxes are visible at once; on desktop a single
    // row that covers the full page width edge to edge.
    final narrow = pageWidth < 700;
    final stripHeight = narrow
        ? 150.0 * 2 + 16 + 48
        : pageWidth * (609 / 922) * 0.7;

    _pinTop = _FixedHeader.contentHeight(context) + 8;
    _viewport = viewport;
    _stripHeight = stripHeight;

    final box = _regionKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      _regionTop = box.localToGlobal(Offset.zero).dy + notifier.value;
    }

    return Container(
      key: _regionKey,
      color: Colors.white,
      height: stripHeight,
      child: AnimatedBuilder(
        animation: Listenable.merge([notifier, widget.hold]),
        builder: (context, _) {
          final offset = notifier.value;
          // Re-measure every frame so the cascade stays in sync with the
          // scroll, even if the layout shifts while images/fonts load.
          final liveBox = _regionKey.currentContext?.findRenderObject();
          final top =
              liveBox is RenderBox && liveBox.attached && liveBox.hasSize
                  ? liveBox.localToGlobal(Offset.zero).dy
                  : _regionTop - offset;
          // While the page is held, scrolling feeds the boxes directly; before
          // that they follow the scroll position. Nothing appears by itself.
          final progress = widget.hold.holding || widget.hold.done
              ? widget.hold.progress.clamp(0.0, 1.0)
              : _scrollProgressFor(top);

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/scroll_anim.png',
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final narrow = width < 700;
                    const gap = 16.0;
                    final cardHeight = narrow ? 150.0 : 220.0;
                    final cardWidth =
                        narrow ? (width - gap) / 2 : (width - 120) / 4;
                    Widget card(int i) {
                      final (icon, title) = _LibraryStrip._cards[i];
                      return _AnimatedCard(
                        progress: _LibraryStrip._cardProgress(i, progress),
                        fromLeft: i.isEven,
                        width: cardWidth,
                        height: cardHeight,
                        icon: icon,
                        title: title,
                      );
                    }

                    return Align(
                      alignment: Alignment.center,
                      child: narrow
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    card(0),
                                    const SizedBox(width: gap),
                                    card(1),
                                  ],
                                ),
                                SizedBox(height: gap),
                                Row(
                                  children: [
                                    card(2),
                                    const SizedBox(width: gap),
                                    card(3),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                card(0),
                                const SizedBox(width: gap),
                                card(1),
                                const SizedBox(width: gap),
                                card(2),
                                const SizedBox(width: gap),
                                card(3),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A library feature card that fades, rises, pops and slides in horizontally
/// from its side as the strip scrolls.
class _AnimatedCard extends StatelessWidget {
  const _AnimatedCard({
    required this.progress,
    required this.fromLeft,
    required this.width,
    required this.height,
    required this.icon,
    required this.title,
  });

  /// 0 when hidden, 1 when fully in place.
  final double progress;
  final bool fromLeft;
  final double width;
  final double height;
  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final dx = (fromLeft ? -1.0 : 1.0) * 96 * (1 - progress);
    final dy = 28 * (1 - progress);
    final scale = 0.85 + 0.15 * progress;
    return Opacity(
      opacity: progress,
      child: Transform(
        alignment: Alignment.center,
        transform:
            Matrix4.translationValues(dx, dy, 0)
              ..scaleByDouble(scale, scale, scale, 1),
        child: _FeatureCard(
          width: width,
          height: height,
          icon: icon,
          title: title,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.width,
    required this.height,
    required this.icon,
    required this.title,
  });

  final double width;
  final double height;
  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final compact = height < 190;
    final pad = compact ? 14.0 : 24.0;
    final iconSize = compact ? 44.0 : 58.0;
    final titleSize = compact ? 15.0 : 20.0;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFC877),
            Color(0xFFFFE4BC),
            Color(0xFFA9CBF7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkNavy.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFFFF9F0)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.55),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      padding: EdgeInsets.all(compact ? 8 : 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E3),
                        borderRadius: BorderRadius.circular(compact ? 14 : 18),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Image.asset(icon, fit: BoxFit.contain),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-height hero on desktop; on phones it takes its natural height so the
/// whole page scrolls as one flow. The wave background, the nav bar and the
/// headline + illustration, exactly as the previous landing page looked.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.height,
    required this.isWide,
    required this.isCompact,
    required this.onLibraryPressed,
  });

  /// Viewport height on wide screens; `null` on phones so the hero shrinks to
  /// its content and the page scrolls naturally.
  final double? height;
  final bool isWide;
  final bool isCompact;
  final VoidCallback onLibraryPressed;

  @override
  Widget build(BuildContext context) {
    final content = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: _Entrance(
                  delay: 0.12,
                  child: HeroText(onLibraryPressed: onLibraryPressed),
                ),
              ),
              Expanded(
                flex: 6,
                child: Center(
                  child: _Entrance(
                    delay: 0.25,
                    child: const IllustrationPlaceholder(
                      width: 420,
                      height: 420,
                    ),
                  ),
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  // Keep the hero copy over the navy part of the wave so the
                  // white title stays readable next to the light right panel.
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.58,
                  ),
                  child: _Entrance(
                    delay: 0.12,
                    child: HeroText(
                      isCompact: isCompact,
                      onLibraryPressed: onLibraryPressed,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isCompact ? 300 : 460),
                  child: const _Entrance(
                    delay: 0.25,
                    child: _HeroImage(),
                  ),
                ),
              ),
            ],
          );

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: WaveBackgroundPainter(narrow: !isWide),
            ),
          ),
          const Positioned(
            top: -40,
            right: 60,
            child: FaintCircle(size: 220),
          ),
          const Positioned(
            bottom: 40,
            right: -60,
            child: FaintCircle(size: 180),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 60 : 24,
                vertical: isWide ? 30 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isWide ? 72 : 56),
                  if (isWide) Expanded(child: content) else content,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero illustration sized to its real aspect ratio so nothing is cropped
/// on narrow screens.
class _HeroImage extends StatelessWidget {
  const _HeroImage();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AspectRatio(
        aspectRatio: 448 / 406,
        child: Image.asset('assets/main.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// Top navigation bar pinned to the top of the screen: transparent while the
/// page sits at the top (the hero's wave shows through), then a solid navy bar
/// with a soft shadow once the user scrolls, so it stays readable over any
/// section.
class _FixedHeader extends StatelessWidget {
  const _FixedHeader({required this.isWide, required this.onNavigate});

  static const double _innerHeight = 64;

  final bool isWide;
  final ValueChanged<String> onNavigate;

  /// Total height the header occupies, including the top system inset.
  static double contentHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + _innerHeight;

  @override
  Widget build(BuildContext context) {
    final notifier = _ScrollScope.read(context);
    return AnimatedBuilder(
      animation: notifier,
      builder: (context, _) {
        final scrolled = notifier.value > 8;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: scrolled ? AppColors.darkNavy : Colors.transparent,
            boxShadow: scrolled
                ? const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: _innerHeight,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 60 : 24,
                  ),
                  child: LandingNavBar(
                    isWide: isWide,
                    scrolled: scrolled,
                    onNavigate: onNavigate,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "À propos" section: text on the left, the landing's second illustration
/// (main2) framed in a rounded card on the right.
class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key, required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final body = TextStyle(
      fontSize: 15,
      height: 1.7,
      color: AppColors.darkNavy.withValues(alpha: 0.75),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionEyebrow('À PROPOS'),
        const SizedBox(height: 12),
        const _SectionTitle('La bibliothèque des prépas'),
        const SizedBox(height: 20),
        Text(
          'IlovePrepa rassemble cours, TD, Ds et examens des classes '
          'préparatoires, classés par filière, matière et niveau. Retrouvez '
          'toute votre bibliothèque au même endroit, où que vous soyez, '
          'depuis votre ordinateur comme depuis votre téléphone.',
          style: body,
        ),
        const SizedBox(height: 20),
        Text(
          '• Accès gratuit et sans inscription\n'
          '• Documents classés par filière et par matière\n'
          '• Mises à jour régulières de la bibliothèque',
          style: body,
        ),
      ],
    );

    return Container(
      color: AppColors.lightBg,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 60 : 24,
        vertical: isWide ? 88 : 56,
      ),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 5, child: text),
                const SizedBox(width: 56),
                Expanded(flex: 6, child: Center(child: _ShowcaseImage())),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: 40),
                _ShowcaseImage(),
              ],
            ),
    );
  }
}

/// "Faire un don" section: a navy band with a call to action.
class _DonateSection extends StatelessWidget {
  const _DonateSection({super.key, required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 60 : 24,
        vertical: isWide ? 88 : 56,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkNavy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Image.asset(
              'assets/don.png',
              key: const Key('landing_donate_icon'),
              width: isWide ? 120 : 96,
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(
            'Soutenez la bibliothèque',
            color: Colors.white,
            center: true,
          ),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                'Votre don permet de maintenir la bibliothèque en ligne, '
                'd’ajouter de nouveaux documents et de la rendre accessible '
                'à toute la communauté des prépas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Material(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => _showDonateDialog(context),
                key: const Key('landing_donate_button'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  child: Text(
                    'Faire un don',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pop-up showing the e-dinar card number to send the donation to.
  void _showDonateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.darkNavy,
        title: const Text(
          'Faire un don',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Envoyez votre don à cette carte e-dinar :',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xE6FFFFFF),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x59000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                '25680686',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  color: Color(0xFF1B1B1B),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: '25680686'));
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Numéro copié !')),
              );
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: AppColors.orange,
            ),
            label: const Text(
              'Copier',
              style: TextStyle(
                color: AppColors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Fermer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Contact" section: a simple way to reach the team, over the main3 banner
/// background.
class _ContactSection extends StatelessWidget {
  const _ContactSection({super.key, required this.isWide});

  final bool isWide;

  Future<void> _sendMail(BuildContext context) async {
    final uri = Uri(
      scheme: 'https',
      host: 'mail.google.com',
      path: '/mail/',
      queryParameters: const {
        'view': 'cm',
        'fs': '1',
        'to': 'ilovepreparatoire@gmail.com',
        'su': 'Contact IlovePrepa',
        'body': 'Bonjour,',
      },
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fall back to the system mail client with the same recipient.
      final mailto = Uri(
        scheme: 'mailto',
        path: 'ilovepreparatoire@gmail.com',
        queryParameters: const {
          'subject': 'Contact IlovePrepa',
          'body': 'Bonjour,',
        },
      );
      await launchUrl(mailto, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkNavy,
      child: Stack(
        children: [
          Positioned(
            top: -160,
            bottom: -160,
            left: 0,
            right: 0,
            child: _Parallax(
              factor: 0.06,
              child: Image.asset(
                'assets/main3.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 60 : 24,
            vertical: isWide ? 88 : 56,
          ),
          child: Column(
            crossAxisAlignment: isWide
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            children: [
              const Center(child: _SectionEyebrow('CONTACT')),
              const SizedBox(height: 12),
              const _SectionTitle('Parlons-en', center: true, color: Colors.white),
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    'Une question, un document manquant, une suggestion ? '
                    'Écrivez-nous, nous répondons à tout le monde.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: InkWell(
                  onTap: () => _sendMail(context),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: _ContactRow(
                      icon: Icons.mail_outline,
                      label: 'ilovepreparatoire@gmail.com',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton(
                  onPressed: () => _sendMail(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: const Color(0xFF1B1B1B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Envoyer un message',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}

/// The main2 illustration framed in a rounded card with a soft shadow.
class _ShowcaseImage extends StatelessWidget {
  const _ShowcaseImage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.midBlue.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/main2.png',
                    key: const Key('landing_showcase_image'),
                    width: width,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColors.orange,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.color, this.center = false});

  final String text;
  final Color? color;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.3,
        color: color ?? AppColors.darkNavy,
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.orange, size: 20),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.darkNavy,
          ),
        ),
      ],
    );
  }
}
