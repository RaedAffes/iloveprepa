import 'dart:math' as math;
import 'package:flutter/material.dart';

class FancyContactButton extends StatefulWidget {
  const FancyContactButton({
    super.key,
    this.label = 'CONTACT US',
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<FancyContactButton> createState() => _FancyContactButtonState();
}

class _FancyContactButtonState extends State<FancyContactButton> {
  static const Color _dark = Color(0xFF262626);
  static const Color _orange = Color(0xFFF5862B);

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CircuitPainter(dark: _dark, orange: _orange),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            widget.onPressed();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: _dark,
                borderRadius: BorderRadius.circular(40),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter({required this.dark, required this.orange});

  final Color dark;
  final Color orange;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(20, size.height / 2)
      ..lineTo(size.width - 20, size.height / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) => false;
}
