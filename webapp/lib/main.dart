import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'services/analytics_service.dart';
import 'services/stats_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    IloveprepaApp(
      stats: StatsService(),
      analytics: AnalyticsService(),
    ),
  );
}

class IloveprepaApp extends StatelessWidget {
  const IloveprepaApp({
    super.key,
    this.stats,
    this.analytics,
  });

  final StatsService? stats;
  final AnalyticsService? analytics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IlovePrepa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: DashboardScreen(
        stats: stats,
        analytics: analytics,
      ),
    );
  }
}
