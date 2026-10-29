import 'package:flutter/material.dart';

class FancyContactButton extends StatelessWidget {
  const FancyContactButton({
    super.key,
    this.label = 'CONTACT US',
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  static const Color dark = Color(0xFF262626);
  static const Color orange = Color(0xFFF58A2E);

  static const double canvasW = 360;
  static const double canvasH = 230;
  static const Rect pillRect = Rect.fromLTWH(58, 84, 246, 74);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: canvasW,
      height: canvasH,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ContactRingPainter(dark: dark, orange: orange),
            ),
          ),
          Positioned.fromRect(
            rect: pillRect,
            child: _Pill(label: label, onPressed: onPressed),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatefulWidget {
  const _Pill({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FancyContactButton.dark,
            borderRadius: BorderRadius.circular(37),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactRingPainter extends CustomPainter {
  const _ContactRingPainter({required this.dark, required this.orange});

  final Color dark;
  final Color orange;

  @override
  void paint(Canvas canvas, Size size) {
    final pill = RRect.fromRectAndRadius(
      FancyContactButton.pillRect,
      const Radius.circular(37),
    );

    final darkRing = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final orangeRing = Paint()
      ..color = orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, 110));
    canvas.drawRRect(pill.inflate(8), darkRing);
    canvas.restore();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 110, size.width, size.height));
    canvas.drawRRect(pill.inflate(14), orangeRing);
    canvas.restore();

    final orangeDot = Paint()..color = orange;
    final darkDot = Paint()..color = dark;

    canvas.drawCircle(const Offset(45, 120), 5, orangeDot);
    canvas.drawCircle(const Offset(335, 120), 7, orangeDot);
    canvas.drawCircle(const Offset(180, 88), 4, darkDot);
    canvas.drawCircle(const Offset(302, 85), 5, darkDot);
    canvas.drawCircle(const Offset(250, 82), 3, orangeDot);
    canvas.drawCircle(const Offset(147, 187), 4, orangeDot);
    canvas.drawCircle(const Offset(287, 180), 3, orangeDot);
  }

  @override
  bool shouldRepaint(covariant _ContactRingPainter oldDelegate) => false;
}
