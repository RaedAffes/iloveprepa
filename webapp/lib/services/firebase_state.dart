import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

Future<void>? _firebaseReady;

/// Idempotently starts Firebase initialization. Call from `main` in the
/// background so the page renders immediately; the returned future completes
/// once Firebase is actually ready (or failed). Callers must degrade
/// gracefully — e.g. stats become no-ops when Firebase is unreachable.
Future<void> ensureFirebaseReady() {
  return _firebaseReady ??= _initialize();
}

Future<void> _initialize() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Best-effort: the app must keep working without Firebase.
  }
}
