import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _donateKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

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
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Scrolls the page back to the top — the brand mark acts as the home
  /// button.
  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll
        .animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrollOffset.dispose();
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
                    physics: const BouncingScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Static sections are wrapped in RepaintBoundary so
                        // scrolling only re-composites their cached raster
                        // instead of re-painting gradients/images/shadows on
                        // every frame. Only the strip (and the contact
                        // parallax) actually change during scroll.
                        RepaintBoundary(
                          child: _Hero(
                            height: isWide ? heroHeight : null,
                            isWide: isWide,
                            isCompact: isCompact,
                            onLibraryPressed: () => _openLibrary(context),
                          ),
                        ),
                        RepaintBoundary(
                          child: _AboutSection(
                            key: _aboutKey,
                            isWide: isWide,
                          ),
                        ),
                        SizedBox(height: isWide ? 96 : 48),
                        const _LibraryStrip(),
                        RepaintBoundary(
                          child: _DonateSection(
                            key: _donateKey,
                            isWide: isWide,
                          ),
                        ),
                        RepaintBoundary(
                          child: _ContactSection(
                            key: _contactKey,
                            isWide: isWide,
                          ),
                        ),
                        RepaintBoundary(
                          child: FutureBuilder<List<DocumentItem>>(
                            future: _documents,
                            builder: (context, snapshot) {
                              return AppFooter(
                                documents: snapshot.data?.length ?? 0,
                                countersStream: _stats.watch(),
                                scrollController: _scroll,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _FixedHeader(
                      isWide: isWide,
                      onNavigate: _navigate,
                      onHome: _scrollToTop,
                    ),
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
      // The image never changes, so its raster is cached and the parallax
      // only re-composites a layer instead of re-painting a 500KB+ image on
      // every scroll frame.
      child: RepaintBoundary(child: child),
    );
  }
}

/// "Votre bibliothèque" section: four feature cards that cascade in as the
/// user scrolls — no hold, no scroll blocking, just pure scroll-linked
/// scale+fade driven by the strip's viewport position.
class _LibraryStrip extends StatefulWidget {
  const _LibraryStrip();

  static const _cards = <(String, String)>[
    ('assets/cours.png', 'Cours'),
    ('assets/td.png', 'TD'),
    ('assets/devoir.png', 'Ds'),
    ('assets/examen.png', 'Examens'),
  ];

  @override
  State<_LibraryStrip> createState() => _LibraryStripState();
}

class _LibraryStripState extends State<_LibraryStrip>
    with SingleTickerProviderStateMixin {
  final GlobalKey _regionKey = GlobalKey();

  /// One ticker smoothly glides the display progress toward the scroll-derived
  /// target at the display refresh rate — eliminates per-notch jumps.
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _display = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateTarget();
        _ticker.start();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _target = 0;

  void _updateTarget() {
    final box = _regionKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final vh = MediaQuery.sizeOf(context).height;
    final h = box.size.height;
    // 0 when strip is fully below viewport, 1 when fully above center.
    _target = ((vh * 0.5 - top) / h).clamp(0.0, 1.0);
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    _updateTarget();
    final diff = _target - _display;
    if (diff.abs() < 0.001) {
      if (_display != _target) setState(() => _display = _target);
      return;
    }
    final f = 1 - math.pow(0.000005, dt).toDouble();
    setState(() => _display += diff * f);
  }

  /// Staggered progress for card [index].
  static double _cardProgress(int index, double progress) {
    final start = index * 0.18;
    final local = ((progress - start) / 0.45).clamp(0.0, 1.0);
    return Curves.easeOutQuart.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    final pageWidth = MediaQuery.sizeOf(context).width;
    final narrow = pageWidth < 700;
    final stripHeight =
        narrow ? 150.0 * 2 + 16 + 48 : pageWidth * (609 / 922) * 0.7;

    return Container(
      key: _regionKey,
      color: Colors.white,
      height: stripHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: Image.asset(
              'assets/scroll_anim.png',
              fit: BoxFit.cover,
            ),
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
                  final p = _cardProgress(i, _display);
                  return RepaintBoundary(
                    child: _FeatureCard(
                      width: cardWidth,
                      height: cardHeight,
                      icon: icon,
                      title: title,
                      opacity: p,
                      scale: 0.92 + 0.08 * p,
                    ),
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
    this.opacity = 1.0,
    this.scale = 1.0,
  });

  final double width;
  final double height;
  final String icon;
  final String title;
  final double opacity;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final compact = height < 190;
    final pad = compact ? 14.0 : 24.0;
    final iconSize = compact ? 44.0 : 58.0;
    final titleSize = compact ? 15.0 : 20.0;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
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
                child: HeroText(onLibraryPressed: onLibraryPressed),
              ),
              Expanded(
                flex: 6,
                child: Center(
                  child: const IllustrationPlaceholder(
                    width: 420,
                    height: 420,
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
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.58,
                  ),
                  child: HeroText(
                    isCompact: isCompact,
                    onLibraryPressed: onLibraryPressed,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: isCompact ? 300 : 460),
                  child: const _HeroImage(),
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
  const _FixedHeader({
    required this.isWide,
    required this.onNavigate,
    required this.onHome,
  });

  static const double _innerHeight = 64;

  final bool isWide;
  final ValueChanged<String> onNavigate;

  /// Scrolls the page back to the top (the brand mark is the home button).
  final VoidCallback onHome;

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
                    onHome: onHome,
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
