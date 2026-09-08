import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Global live counters backed by Cloudflare D1 (via the worker API),
/// shared by every visitor.
///
/// `visits` increments on every app load, `downloads` each time a document is
/// opened. There is no periodic polling: /api/stats is read once at startup and
/// [watch] (the footer) then tracks the up-to-date, optimistic values. Writes
/// are best-effort and failures are swallowed so the app keeps working even if
/// the API is unreachable.
class StatsService {
  StatsService() : _test = false {
    _warm();
  }

  /// Test seam — no network, everything is a no-op / empty.
  StatsService.forTest() : _test = true;

  static const String _statsUrl = '${ApiService.apiBase}/api/stats';
  static const String _incrementUrl = '${ApiService.apiBase}/api/stats/increment';

  final bool _test;

  final http.Client _client = http.Client();

  /// Broadcast counters stream fed by the single startup read and the
  /// optimistic increments.
  ///
  /// A broadcast stream is required: the footer is rebuilt lazily by the
  /// page's scroll view, so its listener can be cancelled and re-attached at
  /// any time (and the landing page and the library can listen at the same
  /// time). A single-subscription stream would throw "Stream has already been
  /// listened to" the moment a listener is re-attached, which made the footer
  /// crash into a huge grey error box.
  late final StreamController<StatsCounters> _counters =
      StreamController<StatsCounters>.broadcast(
    onListen: () {
      // A broadcast stream doesn't replay its last value, so give a new
      // subscriber the latest one immediately instead of waiting for the next
      // event — this is what makes the counters appear right away when the
      // footer first scrolls into view.
      scheduleMicrotask(() {
        if (!_counters.isClosed) _counters.add(_last);
      });
    },
  );

  /// Latest known counters for optimistic UI updates.
  StatsCounters _last = StatsCounters.zero();

  /// Emits the latest counters. Shared by every caller, so the values stay
  /// consistent across the whole app. Never polls — the footer is a display
  /// of the latest known value only.
  Stream<StatsCounters> watch() => _counters.stream;

  /// One read at startup, then this load counts as one visit.
  Future<void> _warm() async {
    await _refresh();
    logAppOpen();
  }

  /// Registers one visit — fired on every app load. Sent immediately and
  /// reflected optimistically in the UI.
  void logAppOpen() {
    if (_test) return;
    _increment({'visits': 1});
  }

  /// Registers a download (called when a document is opened). Sent to the
  /// backend immediately and reflected optimistically in the UI.
  void logDownload() {
    if (_test) return;
    _increment({'downloads': 1});
  }

  Future<void> _refresh() async {
    _last = await _read();
    if (!_counters.isClosed) _counters.add(_last);
  }

  Future<void> _increment(Map<String, int> fields) async {
    if (_test) return;

    // Optimistic update: push immediately so the UI reflects the change
    // without waiting for anything.
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