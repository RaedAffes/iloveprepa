import 'package:flutter/material.dart';

/// Non-web fallback used by widget tests — the real implementation embeds the
/// PDF in an <iframe> on the web.
class PdfEmbed extends StatelessWidget {
  const PdfEmbed({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Color(0xFFF7F7F5));
  }
}
