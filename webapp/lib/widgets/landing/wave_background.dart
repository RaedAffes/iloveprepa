import 'package:flutter/material.dart';

import 'landing_colors.dart';

/// Layered wave background drawn behind the landing content: a deep navy base,
/// a mid-blue wave on the left, a lighter accent wave on top, and a light
/// panel on the right for the illustration side.
class WaveBackgroundPainter extends CustomPainter {
  const WaveBackgroundPainter({this.narrow = false});

  final bool narrow;

  @override
  void paint(Canvas canvas, Size size) {
    // Base fill: deep navy across whole canvas
    final basePaint = Paint()..color = AppColors.darkNavy;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // Mid blue wave shape covering left ~65% with a curved right edge
    final wavePath = Path();
    wavePath.moveTo(0, 0);
    wavePath.lineTo(size.width * 0.62, 0);
    wavePath.quadraticBezierTo(
      size.width * 0.78,
      size.height * 0.30,
      size.width * 0.60,
      size.height * 0.55,
    );
    wavePath.quadraticBezierTo(
      size.width * 0.42,
      size.height * 0.80,
      size.width * 0.66,
      size.height,
    );
    wavePath.lineTo(0, size.height);
    wavePath.close();

    final wavePaint = Paint()..color = AppColors.midBlue;
    canvas.drawPath(wavePath, wavePaint);

    // Lighter blue accent wave, layered on top, slightly offset
    final wave2 = Path();
    wave2.moveTo(0, size.height * 0.15);
    wave2.quadraticBezierTo(
      size.width * 0.30,
      size.height * 0.05,
      size.width * 0.50,
      size.height * 0.20,
    );
    wave2.quadraticBezierTo(
      size.width * 0.68,
      size.height * 0.35,
      size.width * 0.48,
      size.height * 0.55,
    );
    wave2.quadraticBezierTo(
      size.width * 0.30,
      size.height * 0.72,
      size.width * 0.50,
      size.height,
    );
    wave2.lineTo(0, size.height);
    wave2.close();

    final wave2Paint = Paint()
      ..color = AppColors.brightBlue.withValues(alpha: 0.55);
    canvas.drawPath(wave2, wave2Paint);

    // Right side stays as lightBg (page background) — draw a rounded
    // near-white panel so content on the right sits on light ground.
    // The panel is pushed well under the hero image so the illustration
    // sits fully inside the white zone. On narrow screens it keeps the upper
    // band around ~62% so the stacked hero copy always remains on navy, while
    // the lower band widens toward the centered image.
    final rightPanel = Path();
    if (narrow) {
      rightPanel.moveTo(size.width, 0);
      rightPanel.lineTo(size.width * 0.62, 0);
      rightPanel.quadraticBezierTo(
        size.width * 0.60,
        size.height * 0.42,
        size.width * 0.50,
        size.height * 0.72,
      );
      rightPanel.quadraticBezierTo(
        size.width * 0.46,
        size.height * 0.92,
        size.width * 0.52,
        size.height,
      );
    } else {
      rightPanel.moveTo(size.width, 0);
      rightPanel.lineTo(size.width * 0.56, 0);
      rightPanel.quadraticBezierTo(
        size.width * 0.44,
        size.height * 0.28,
        size.width * 0.50,
        size.height * 0.55,
      );
      rightPanel.quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.80,
        size.width * 0.50,
        size.height,
      );
    }
    rightPanel.lineTo(size.width, size.height);
    rightPanel.close();

    final rightPaint = Paint()..color = AppColors.lightBg;
    canvas.drawPath(rightPanel, rightPaint);
  }

  @override
  bool shouldRepaint(covariant WaveBackgroundPainter oldDelegate) {
    return oldDelegate.narrow != narrow;
  }
}

class FaintCircle extends StatelessWidget {
  final double size;
  const FaintCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}
