import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'services/analytics_service.dart';
import 'services/stats_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Inter and PlayfairDisplay are bundled as assets, so never fetch fonts at
  // runtime — text renders instantly at its final size.
  GoogleFonts.config.allowRuntimeFetching = false;
  // Render the page immediately. Firebase boots in the background so the app
  // keeps working even when Firebase is slow or unreachable (the stats and
  // analytics services wait for it so the shared counters and events never
  // miss a visit).
  final firebaseReady = _initFirebase();
  runApp(
    IloveprepaApp(
      stats: StatsService(ready: firebaseReady),
      analytics: AnalyticsService(ready: firebaseReady),
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
  const IloveprepaApp({super.key, this.stats, this.analytics});

  /// Test seam — defaults to a real [StatsService] built in [main].
  final StatsService? stats;

  /// Test seam — defaults to a real [AnalyticsService] built in [main].
  final AnalyticsService? analytics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IlovePrepa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: DashboardScreen(stats: stats, analytics: analytics),
    );
  }
}
