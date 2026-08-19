import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';

/// Global live counters backed by a single Firestore document
/// (`stats/counters`), shared by every visitor.
///
/// `visits` increments on every app load, `downloads` each time a document is
/// opened. [watch] keeps listeners (the footer) in sync by polling. Writes are
/// atomic (`FieldValue.increment` via the REST API) and failures are swallowed
/// so the app keeps working even if Firestore is unreachable.
///
/// This talks to Firestore's REST API directly instead of the Firebase JS SDK:
/// the SDK is loaded at runtime from Google's CDN and silently no-ops whenever
/// it cannot boot (blocked CDN, slow network), which made the counters appear
/// dead even though the backend rules were correct. Plain HTTPS requests work
/// everywhere the app can reach the internet.
class StatsService {
  StatsService() : _test = false {
    _startPolling();
  }

  /// Test seam — no network, everything is a no-op / empty.
  StatsService.forTest() : _test = true;

  static const String countersPath = 'stats/counters';

  static const String _baseUrl =
      'https://firestore.googleapis.com/v1/projects/iprepa/databases/(default)/documents';

  final bool _test;

  final http.Client _client = http.Client();

  /// Broadcast counters stream fed by the poller. A broadcast stream is
  /// required: the footer is rebuilt lazily by the page's scroll view, so its
  /// listener can be cancelled and re-attached at any time (and the landing
  /// page and the library can listen at the same time). A single-subscription
  /// stream would throw "Stream has already been listened to" the moment a
  /// listener is re-attached, which made the footer crash into a huge grey
  /// error box.
  final StreamController<StatsCounters> _counters =
      StreamController<StatsCounters>.broadcast();

  String get _apiKey => DefaultFirebaseOptions.currentPlatform.apiKey;

  /// Short resource name Firestore expects inside write/transform payloads
  /// (the full URL form is rejected with a 400).
  String get _docPath => 'projects/iprepa/databases/(default)/documents/$countersPath';

  /// Full endpoint used for reads.
  String get _countersDoc => '$_baseUrl/$countersPath';

  Uri _docUri() => Uri.parse(_countersDoc).replace(queryParameters: {'key': _apiKey});

  Uri _commitUri() =>
      Uri.parse('$_baseUrl:commit').replace(queryParameters: {'key': _apiKey});

  /// Latest known counters for optimistic UI updates.
  StatsCounters _last = StatsCounters.zero();

  /// Emits the current counters and then keeps polling every 5 seconds so
  /// the footer always shows fresh numbers. Every caller shares the same
  /// stream, so the counters stay consistent across the whole app.
  Stream<StatsCounters> watch() => _counters.stream;

  /// Reads Firestore immediately, then re-reads every 5 seconds, pushing each
  /// result to [_counters] for the app's whole lifetime. Errors are already
  /// swallowed by [_read] so a failed read simply reuses the previous value.
  void _startPolling() async {
    while (!_counters.isClosed) {
      _last = await _read();
      _counters.add(_last);
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> incrementVisits() => _increment({'visits': 1});

  Future<void> incrementDownloads() => _increment({'downloads': 1});

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
      final transform = {
        'document': _docPath,
        'fieldTransforms': [
          for (final entry in fields.entries)
            {
              'fieldPath': entry.key,
              'increment': {'integerValue': entry.value.toString()},
            },
        ],
      };
      await _client.post(
        _commitUri(),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'writes': [
            {'transform': transform},
          ],
        }),
      );
    } catch (_) {
      // Best-effort analytics; never break the app for a counter.
    }
  }

  Future<StatsCounters> _read() async {
    if (_test) return StatsCounters.zero();
    try {
      final response = await _client.get(_docUri());
      if (response.statusCode != 200) return StatsCounters.zero();
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return StatsCounters.fromMap(_fieldsToMap(data['fields']));
    } catch (_) {
      return StatsCounters.zero();
    }
  }

  /// Converts a Firestore `fields` payload (e.g.
  /// `{'visits': {'integerValue': '2'}}`) into a plain `{key: num}` map.
  Map<String, dynamic> _fieldsToMap(Object? fields) {
    final result = <String, dynamic>{};
    if (fields is Map) {
      for (final entry in fields.entries) {
        final value = entry.value;
        if (value is Map) {
          final intValue = value['integerValue'];
          if (intValue is String) {
            result[entry.key as String] = int.tryParse(intValue) ?? 0;
            continue;
          }
          final doubleValue = value['doubleValue'];
          if (doubleValue is String) {
            result[entry.key as String] = double.tryParse(doubleValue) ?? 0;
          }
        }
      }
    }
    return result;
  }
}

class StatsCounters {
  const StatsCounters({required this.visits, required this.downloads});

  StatsCounters.zero() : this(visits: 0, downloads: 0);

  factory StatsCounters.fromMap(Map<String, dynamic> map) => StatsCounters(
        visits: (map['visits'] as num?)?.toInt() ?? 0,
        downloads: (map['downloads'] as num?)?.toInt() ?? 0,
      );

  final int visits;
  final int downloads;
}
