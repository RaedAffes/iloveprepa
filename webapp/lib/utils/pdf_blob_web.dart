import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

String createPdfBlobUrl(Uint8List bytes) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  return web.URL.createObjectURL(blob);
}

void revokePdfBlobUrl(String url) {
  if (url.isEmpty) return;
  web.URL.revokeObjectURL(url);
}
