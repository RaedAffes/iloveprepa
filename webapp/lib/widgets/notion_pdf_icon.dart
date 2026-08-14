import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Minimal Notion-style PDF icon — a rounded document with a folded corner
/// and a small "PDF" label, drawn in the same clean line style as Notion.
class NotionPdfIcon extends StatelessWidget {
  const NotionPdfIcon({super.key, this.size = 32, this.color = AppColors.secondary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _NotionPdfPainter(color)),
    );
  }
}

class _NotionPdfPainter extends CustomPainter {
  _NotionPdfPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final page = Path()
      ..moveTo(5, 2.6)
      ..lineTo(13.8, 2.6)
      ..lineTo(19, 7.8)
      ..lineTo(19, 21.4)
      ..lineTo(5, 21.4)
      ..close();

    final fold = Path()
      ..moveTo(13.8, 2.6)
      ..lineTo(13.8, 7.8)
      ..lineTo(19, 7.8);

    canvas.drawPath(page, outline);
    canvas.drawPath(fold, outline);

    final label = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: color,
          fontSize: 6.4,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset((24 - label.width) / 2, 13.4));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NotionPdfPainter oldDelegate) =>
      oldDelegate.color != color;
}
