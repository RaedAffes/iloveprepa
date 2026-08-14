import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Global live counters backed by a single Firestore document
/// (`stats/counters`), shared by every visitor.
///
/// `visits` increments on every app load, `downloads` each time a document is
/// opened. [watch] keeps listeners (the footer) in sync in real time. Writes
/// are atomic (`FieldValue.increment`) and failures are swallowed so the app
/// keeps working even if Firestore is unreachable. [ready] lets the service
/// wait for Firebase boot so the very first visit still reaches the shared
/// counters instead of being dropped during the init race.
class StatsService {
  StatsService({Future<void>? ready})
      : _ready = ready ?? Future<void>.value(),
        _test = false;

  /// Test seam — no Firebase dependency, everything is a no-op / empty.
  StatsService.forTest() : _ready = null, _test = true;

  static const String countersPath = 'stats/counters';

  final Future<void>? _ready;
  final bool _test;

  /// Resolves lazily so the app works before or without Firebase: whenever no
  /// app is initialized yet (or Firebase is unreachable) it returns null and
  /// all counters become no-ops.
  FirebaseFirestore? get _db {
    if (_test) return null;
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Waits (bounded) for Firebase to finish initialising before touching the
  /// shared document, so no counter is lost during app startup.
  Future<FirebaseFirestore?> _dbWhenReady() async {
    if (_test) return null;
    final ready = _ready;
    if (ready != null) {
      try {
        await ready.timeout(const Duration(seconds: 8));
      } catch (_) {
        // Firebase unavailable — stats stay no-ops.
      }
    }
    return _db;
  }

  /// Emits the current counters and any later change in real time.
  Stream<StatsCounters> watch() {
    if (_test) return Stream.value(StatsCounters.zero());
    return Stream.fromFuture(_dbWhenReady()).asyncExpand((db) {
      if (db == null) return Stream.value(StatsCounters.zero());
      return db
          .doc(countersPath)
          .snapshots()
          .map((snap) => StatsCounters.fromMap(snap.data() ?? const {}));
    });
  }

  Future<void> incrementVisits() => _increment({'visits': 1});

  Future<void> incrementDownloads() => _increment({'downloads': 1});

  Future<void> _increment(Map<String, int> fields) async {
    final db = await _dbWhenReady();
    if (db == null) return;
    try {
      await db.doc(countersPath).set(
        {
          for (final entry in fields.entries)
            entry.key: FieldValue.increment(entry.value),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Best-effort analytics; never break the app for a counter.
    }
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
