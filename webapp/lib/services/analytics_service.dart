import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Google Analytics 4 tracking, tied to the Firebase project's web stream.
///
/// Every method is best-effort: if Firebase has not finished booting or is
/// unreachable the call is a silent no-op, so analytics can never break the
/// app. Events sent: `screen_view` (dashboard / folder), `document_view`,
/// `document_download` and `folder_open`.
class AnalyticsService {
  AnalyticsService({Future<void>? ready})
      : _ready = ready ?? Future<void>.value(),
        _test = false;

  /// Test seam — no Firebase dependency, everything is a no-op.
  AnalyticsService.forTest() : _ready = null, _test = true;

  final Future<void>? _ready;
  final bool _test;

  FirebaseAnalytics? get _analytics {
    if (_test) return null;
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  /// Waits (bounded) for Firebase boot before reporting, so the very first
  /// visit still reaches the analytics property instead of being dropped.
  Future<FirebaseAnalytics?> _whenReady() async {
    if (_test) return null;
    final ready = _ready;
    if (ready != null) {
      try {
        await ready.timeout(const Duration(seconds: 8));
      } catch (_) {
        // Firebase unavailable — analytics stay no-ops.
      }
    }
    return _analytics;
  }

  Future<void> logAppOpen() async {
    await _run((a) => a.logEvent(name: 'app_open'));
  }

  Future<void> logScreenView(String screenName) async {
    await _run((a) => a.logScreenView(screenName: screenName));
  }

  Future<void> logFolderOpen(String path) async {
    await _run(
      (a) => a.logEvent(name: 'folder_open', parameters: {'path': path}),
    );
  }

  Future<void> logDocumentView(String name) async {
    await _run(
      (a) => a.logEvent(name: 'document_view', parameters: {'file': name}),
    );
  }

  Future<void> logDocumentDownload(String name) async {
    await _run(
      (a) => a.logEvent(
        name: 'document_download',
        parameters: {'file': name},
      ),
    );
  }

  Future<void> _run(Future<void> Function(FirebaseAnalytics analytics) action) async {
    final analytics = await _whenReady();
    if (analytics == null) return;
    try {
      await action(analytics);
    } catch (_) {
      // Best-effort analytics; never break the app for a metric.
    }
  }
}
