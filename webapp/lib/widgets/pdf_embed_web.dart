import 'dart:js_interop' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/theme/app_colors.dart';

/// Embeds a PDF inside the page by rendering an <iframe> pointing at [url],
/// letting the browser's native viewer show the document without leaving the
/// app. A spinner covers the frame until the document finishes loading.
class PdfEmbed extends StatefulWidget {
  const PdfEmbed({super.key, required this.url});

  final String url;

  @override
  State<PdfEmbed> createState() => _PdfEmbedState();
}

class _PdfEmbedState extends State<PdfEmbed> {
  static int _counter = 0;

  late final String _viewType;
  final ValueNotifier<bool> _loading = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _viewType = 'pdf-embed-${_counter++}';
    final url = widget.url;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..allowFullscreen = true;
      iframe.addEventListener(
        'load',
        ((web.Event _) {
          _loading.value = false;
        }).toJS,
      );
      return iframe;
    });
  }

  @override
  void dispose() {
    _loading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        ValueListenableBuilder<bool>(
          valueListenable: _loading,
          builder: (context, loading, _) {
            if (!loading) return const SizedBox.shrink();
            return const ColoredBox(
              color: AppColors.surfaceSecondary,
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ],
    );
  }
}
