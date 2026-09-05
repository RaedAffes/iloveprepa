/// Analytics facade.
///
/// Analytics is handled by Cloudflare Web Analytics, which is injected as a
/// beacon script in `web/index.html` and tracks page views automatically in
/// the Cloudflare dashboard. The visit/download counters live in Cloudflare D1
/// and are driven by [StatsService].
///
/// These methods are kept as no-ops so call sites remain stable and analytics
/// can never break the app.
class AnalyticsService {
  AnalyticsService();

  /// Test seam — everything is a no-op.
  AnalyticsService.forTest();

  Future<void> logAppOpen() async {}

  Future<void> logScreenView(String screenName) async {}

  Future<void> logFolderOpen(String path) async {}

  Future<void> logDocumentView(String name) async {}

  Future<void> logDocumentDownload(String name) async {}
}
