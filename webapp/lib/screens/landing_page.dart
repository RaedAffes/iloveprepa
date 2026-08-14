import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/stats_service.dart';
import '../widgets/landing/hero_text.dart';
import '../widgets/landing/illustration_placeholder.dart';
import '../widgets/landing/nav_bar.dart';
import '../widgets/landing/wave_background.dart';
import 'dashboard_screen.dart';

/// Marketing landing page shown before the library. The "Library" button
/// pushes the real library home ([DashboardScreen]) on top.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key, this.stats, this.analytics});

  /// Test seam — forwarded to [DashboardScreen] when the user enters the
  /// library.
  final StatsService? stats;

  /// Test seam — forwarded to [DashboardScreen] when the user enters the
  /// library.
  final AnalyticsService? analytics;

  void _openLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DashboardScreen(stats: stats, analytics: analytics),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFF4F6FB),
      ),
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Layer 1: wave background
                  Positioned.fill(
                    child: CustomPaint(
                      painter: WaveBackgroundPainter(),
                    ),
                  ),
                  // Layer 2: decorative faint circles
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
                  // Layer 3: content
                  SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 60 : 24,
                        vertical: 30,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LandingNavBar(isWide: isWide),
                          const SizedBox(height: 40),
                          Expanded(
                            child: isWide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: HeroText(
                                          onLibraryPressed: () =>
                                              _openLibrary(context),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Center(
                                          child: IllustrationPlaceholder(
                                            width: 420,
                                            height: 420,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        HeroText(
                                          onLibraryPressed: () =>
                                              _openLibrary(context),
                                        ),
                                        const SizedBox(height: 32),
                                        IllustrationPlaceholder(
                                          width: 300,
                                          height: 300,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
