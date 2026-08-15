import 'package:web/web.dart' as web;

/// Triggers a browser download for [url] by clicking a hidden anchor. The
/// server answers with `Content-Disposition: attachment`, so the file always
/// downloads — no tab switch, no popup blocker. This is the same mechanism
/// real apps use and works on desktop and mobile browsers.
Future<bool> triggerWebDownload(String url) async {
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = ''
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
