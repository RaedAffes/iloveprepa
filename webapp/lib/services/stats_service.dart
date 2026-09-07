import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Global live counters backed by Cloudflare D1 (via the worker API),
/// shared by every visitor.
///
/// `visits` increments on every app load, `downloads` each time a document is
/// opened. [watch] keeps listeners (the footer) in sync by polling. Writes are
/// best-effort and failures are swallowed so the app keeps working even if the
/// API is unreachable.
class StatsService {
  StatsService() : _test = false {
    _warm();
  }

  /// Test seam — no network, everything is a no-op / empty.
  StatsService.forTest() : _test = true;

  static const String _statsUrl = '${ApiService.apiBase}/api/stats';
  static const String _incrementUrl = '${ApiService.apiBase}/api/stats/increment';

  /// How often the counters are refreshed while the footer is on screen.
  /// 5 minutes is plenty: counts only move on visits/downloads, and those are
  /// shown instantly via the optimistic update in [_increment]. The 100k
  /// requests/day limit becomes effectively unreachable.
  static const Duration _pollInterval = Duration(minutes: 5);

  final bool _test;

  final http.Client _client = http.Client();

  /// One in-flight read at most, so overlapping timer ticks never race.
  bool _reading = false;

  /// Broadcast counters stream fed by the poller while the footer is visible.
  ///
  /// A broadcast stream is required: the footer is rebuilt lazily by the
  /// page's scroll view, so its listener can be cancelled and re-attached at
  /// any time (and the landing page and the library can listen at the same
  /// time). A single-subscription stream would throw "Stream has already been
  /// listened to" the moment a listener is re-attached, which made the footer
  /// crash into a huge grey error box.
  ///
  /// Polling only runs while the stream has a listener (i.e. the footer is
  /// actually on screen): `onListen` starts the timer, `onCancel` stops it.
  /// No background polling while the footer is hidden — every open tab that
  /// never scrolls down costs exactly one warm-up read.
  late final StreamController<StatsCounters> _counters =
      StreamController<StatsCounters>.broadcast(
    onListen: () {
      // A broadcast stream doesn't replay its last value, so give a new
      // subscriber the latest one immediately instead of waiting for the next
      // poll tick — this is what makes the counters appear right away when the
      // footer first scrolls into view.
      scheduleMicrotask(() {
        if (!_counters.isClosed) _counters.add(_last);
      });
      _startPolling();
    },
    onCancel: _stopPolling,
  );

  /// Latest known counters for optimistic UI updates.
  StatsCounters _last = StatsCounters.zero();

  /// Download count held back until the footer is shown. Because a visit (and
  /// therefore the counters) should only advance once the user actually scrolls
  /// to the footer, downloads made before that are queued here and flushed the
  /// moment the footer first becomes visible.
  int _pendingDownloads = 0;

  /// Whether the footer has already become visible, so a visit is counted only
  /// once per session.
  bool _footerShown = false;

  /// Emits the current counters and then keeps polling every 5 minutes as
  /// long as the footer remains on screen. Every caller shares the same
  /// stream, so the counters stay consistent across the whole app.
  Stream<StatsCounters> watch() => _counters.stream;

  /// One read at startup so the immediate replay for the first footer listen
  /// is not stale. No timer yet — nothing polls until the footer appears.
  Future<void> _warm() async {
    await _pollOnce();
  }

  void _startPolling() {
    if (_test || _timer != null) return;
    _timer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Timer? _timer;

  /// Reads the counters once and pushes the result to [_counters]. Errors are
  /// swallowed by [_read] so a failed read simply reuses the previous value.
  Future<void> _pollOnce() async {
    if (_reading) return;
    _reading = true;
    try {
      _last = await _read();
      if (!_counters.isClosed) _counters.add(_last);
    } finally {
      _reading = false;
    }
  }

  /// Queues a download. It is not sent to the backend yet — it is flushed
  /// together with the visit the first time the footer becomes visible, so a
  /// download only counts if the user actually scrolled to the footer.
  void queueDownload() {
    if (_test) return;
    _pendingDownloads++;
  }

  /// Called once the footer first becomes visible on screen. Counts a visit and
  /// flushes any downloads queued before the footer was shown.
  void markFooterVisible() {
    if (_test) return;
    if (_footerShown) return;
    _footerShown = true;
    final fields = <String, int>{'visits': 1};
    if (_pendingDownloads > 0) {
      fields['downloads'] = _pendingDownloads;
      _pendingDownloads = 0;
    }
    _increment(fields);
  }

  Future<void> _increment(Map<String, int> fields) async {
    if (_test) return;

    // Optimistic update: push immediately so the UI reflects the change
    // without waiting for the next poll cycle.
    int v = _last.visits;
    int d = _last.downloads;
    for (final entry in fields.entries) {
      if (entry.key == 'visits') v += entry.value;
      if (entry.key == 'downloads') d += entry.value;
    }
    _last = StatsCounters(visits: v, downloads: d);
    _counters.add(_last);

    try {
      await _client.post(
        Uri.parse(_incrementUrl),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(fields),
      );
    } catch (_) {
      // Best-effort analytics; never break the app for a counter.
    }
  }

  Future<StatsCounters> _read() async {
    if (_test) return StatsCounters.zero();
    try {
      final response = await _client
          .get(Uri.parse(_statsUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return StatsCounters.zero();
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return StatsCounters(
        visits: (data['visits'] as num?)?.toInt() ?? 0,
        downloads: (data['downloads'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return StatsCounters.zero();
    }
  }
}

class StatsCounters {
  const StatsCounters({required this.visits, required this.downloads});

  StatsCounters.zero() : this(visits: 0, downloads: 0);

  final int visits;
  final int downloads;
}
