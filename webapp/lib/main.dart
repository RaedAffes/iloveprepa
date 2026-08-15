import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/landing_page.dart';
import 'services/analytics_service.dart';
import 'services/stats_service.dart';
import 'theme/app_theme.dart';
import 'widgets/iloveprepa_brand.dart';
import 'widgets/landing/landing_colors.dart' as landing;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Inter and PlayfairDisplay are bundled as assets, so text renders
  // instantly at its final size.
  // Render the page immediately. Firebase boots in the background so the app
  // keeps working even when Firebase is slow or unreachable (the stats and
  // analytics services wait for it so the shared counters and events never
  // miss a visit).
  final firebaseReady = _initFirebase();
  runApp(
    IloveprepaApp(
      stats: StatsService(),
      analytics: AnalyticsService(ready: firebaseReady),
      firebaseReady: firebaseReady,
    ),
  );
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Best-effort: the app must keep working without Firebase.
  }
}

class IloveprepaApp extends StatelessWidget {
  const IloveprepaApp({
    super.key,
    this.stats,
    this.analytics,
    this.firebaseReady,
  });

  /// Test seam — defaults to a real [StatsService] built in [main].
  final StatsService? stats;

  /// Test seam — defaults to a real [AnalyticsService] built in [main].
  final AnalyticsService? analytics;

  /// Completed once Firebase is initialized; the launch splash waits for it.
  final Future<void>? firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IlovePrepa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _LaunchGate(
        stats: stats,
        analytics: analytics,
        firebaseReady: firebaseReady,
      ),
    );
  }
}

/// Shows a short branded splash until the landing page's first section is
/// ready (hero title + illustration loaded) and Firebase is up, so the page
/// opens fully ready instead of loading in front of the user. It waits only
/// the minimum necessary, then everything else loads right after.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate({
    required this.stats,
    required this.analytics,
    required this.firebaseReady,
  });

  final StatsService? stats;
  final AnalyticsService? analytics;
  final Future<void>? firebaseReady;

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate>
    with SingleTickerProviderStateMixin {
  static const Duration _minimum = Duration(milliseconds: 900);
  static const Duration _fadeOut = Duration(milliseconds: 220);
  static const String _heroImage = 'assets/main.png';

  late final AnimationController _splashFade;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _splashFade = AnimationController(
      vsync: this,
      duration: _fadeOut,
      value: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    _splashFade.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    await Future.wait([
      Future<void>.delayed(_minimum),
      precacheImage(const AssetImage(_heroImage), context),
      widget.firebaseReady ?? Future<void>.value(),
    ]);
    if (!mounted) return;
    // Fade the splash out completely before showing the landing page, so the
    // brand and spinner are never visible at two sizes at once.
    await _splashFade.forward(from: 1.0);
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) {
      return LandingPage(
        stats: widget.stats,
        analytics: widget.analytics,
      );
    }
    return FadeTransition(
      opacity: _splashFade,
      child: const _LaunchSplash(),
    );
  }
}

class _LaunchSplash extends StatelessWidget {
  const _LaunchSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: landing.AppColors.midBlue,
      body: Center(
        // Brand only: the 44px spinner already runs in the HTML boot preview,
        // so the Flutter splash never renders a second spinner and the boot
        // path shows the spinner at a single size in a single place.
        child: const IloveprepaBrand(
          fontSize: 40,
          iconSize: 36,
          color: Colors.white,
        ),
      ),
    );
  }
}
