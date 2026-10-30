/// VM / non-web fallback (used by `flutter test`, where no DOM exists).
/// Reports failure so callers can show an error message.
Future<bool> triggerWebDownload(String url, {String fileName = ''}) async => false;
