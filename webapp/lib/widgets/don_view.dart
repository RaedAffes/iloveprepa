import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Donation screen shown in the main area when the Don icon is tapped.
/// Payment is made by D17 only: tapping the button reveals the merchant card
/// number to copy, then the visitor pays from their D17 app.
///
/// The background is a static star field tinted with the app's palette
/// (navy-blue / orange) on a white surface.
class DonView extends StatefulWidget {
  const DonView({super.key});

  @override
  State<DonView> createState() => _DonViewState();
}

/// The D17 merchant card number presented to visitors.
const String kD17Number = '25680686';

class _DonViewState extends State<DonView> {
  bool _showNumber = false;

  void _revealNumber() {
    if (_showNumber) return;
    setState(() => _showNumber = true);
  }

  Future<void> _copyNumber() async {
    await Clipboard.setData(const ClipboardData(text: kD17Number));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro copié !')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFFFF),
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(child: CustomPaint(painter: _DoodlePainter())),
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Soutenir iloveprepa',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Pacifico',
                        height: 1.1,
                        fontSize: 36,
                        color: Color(0xFF212529),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // The heart lives in the bundled Material icons font (which
                    // is already on screen), not an emoji font that Flutter
                    // fetches lazily — so the heart and the text always appear
                    // together.
                    Text.rich(
                      TextSpan(
                        text: 'Votre soutien fait grandir notre idée. '
                            'Merci de faire partie de l’aventure. ',
                        style: const TextStyle(
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          height: 1.5,
                          color: Color(0xFF57565C),
                        ),
                        children: const [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(left: 2),
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 18,
                                color: Color(0xFFE53935),
                              ),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    _buildRevealButton(),
                    if (_showNumber) ...[
                      const SizedBox(height: 20),
                      _buildNumberCard(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _revealNumber,
        borderRadius: BorderRadius.circular(48),
        child: Ink(
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFFF923C),
            borderRadius: BorderRadius.circular(48),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.smartphone_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Faire un don via D17',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1F212529)),
      ),
      child: Column(
        children: [
          const Text(
            'Numéro D17',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF838788),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                kD17Number,
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  letterSpacing: 2,
                  color: Color(0xFF212529),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _copyNumber,
                borderRadius: BorderRadius.circular(20),
                child: const Tooltip(
                  message: 'Copier',
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 22,
                      color: Color(0xFFFF923C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hand-drawn "pencil" doodles scattered on the edges of the page, drawn in
/// the orange of the donate button at low opacity. Cheerful, supportive
/// symbols: smiles, a helping hand, hearts, a flower, a balloon, a joyful
/// person, the sun, stars and scribbles — purely decorative.
class _DoodlePainter extends CustomPainter {
  const _DoodlePainter();

  static const Color _orange = Color(0xFFFF923C);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 700.0;

    Paint pen([double alpha = 0.28]) => Paint()
      ..color = _orange.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Paint fill(double alpha) => Paint()
      ..color = _orange.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;

    // Narrow phones get only corner doodles so nothing collides with the
    // centered text, button or card.
    if (size.width < 560) {
      _paintPhone(canvas, size, s, pen, fill);
      return;
    }

    // ── Top-left: big smiley + tiny dots ────────────────────────────────
    _smiley(canvas, Offset(size.width * 0.11, size.height * 0.15), 30 * s,
        pen(0.32));
    _dot(canvas, Offset(size.width * 0.06, size.height * 0.28), 2.0 * s,
        fill(0.30));
    _dot(canvas, Offset(size.width * 0.19, size.height * 0.26), 1.6 * s,
        fill(0.26));

    // ── Top-center: balloon + heart ─────────────────────────────────────
    _balloon(canvas, Offset(size.width * 0.51, size.height * 0.12), 24 * s,
        pen(0.26));
    _heart(canvas, Offset(size.width * 0.60, size.height * 0.26), 13 * s,
        pen(0.24));

    // ── Top-right: sun + scribble ───────────────────────────────────────
    _sunny(canvas, Offset(size.width * 0.90, size.height * 0.16), 24 * s,
        pen(0.34));
    _scribble(canvas, Offset(size.width * 0.70, size.height * 0.28), 56 * s,
        7 * s, pen(0.24));

    // ── Left middle: flower ─────────────────────────────────────────────
    _flower(canvas, Offset(size.width * 0.10, size.height * 0.48), 24 * s,
        pen(0.34));
    _sparkle(canvas, Offset(size.width * 0.16, size.height * 0.58), 16 * s,
        pen(0.24));

    // ── Right middle: flower + small smiley ─────────────────────────────
    _flower(canvas, Offset(size.width * 0.92, size.height * 0.52), 20 * s,
        pen(0.32));
    _smiley(canvas, Offset(size.width * 0.81, size.height * 0.61), 15 * s,
        pen(0.24));

    // ── Bottom-left: big heart ──────────────────────────────────────────
    _heart(canvas, Offset(size.width * 0.14, size.height * 0.82), 34 * s,
        pen(0.34));
    _dot(canvas, Offset(size.width * 0.24, size.height * 0.88), 2.2 * s,
        fill(0.30));

    // ── Bottom-center: joyful person ────────────────────────────────────
    _personJoy(canvas, Offset(size.width * 0.56, size.height * 0.88), 22 * s,
        pen(0.24));

    // ── Bottom-right: star + sparkle ────────────────────────────────────
    _handStar(canvas, Offset(size.width * 0.88, size.height * 0.82), 26 * s,
        pen(0.32));
    _sparkle(canvas, Offset(size.width * 0.78, size.height * 0.90), 16 * s,
        pen(0.24));
  }

  void _paintPhone(
    Canvas canvas,
    Size size,
    double s,
    Paint Function(double) pen,
    Paint Function(double) fill,
  ) {
    final w = size.width;
    final h = size.height;
    // Slightly larger doodles on phones so the clusters stay readable.
    final ps = s * 1.25;
    Offset at(double x, double y) => Offset(w * x, h * y);

    // ── Top-left cluster ────────────────────────────────────────────────
    _smiley(canvas, at(0.085, 0.09), 15 * ps, pen(0.32));
    _sparkle(canvas, at(0.19, 0.105), 9 * ps, pen(0.26));
    _heart(canvas, at(0.125, 0.185), 10 * ps, pen(0.26));

    // ── Top-right cluster ───────────────────────────────────────────────
    _sunny(canvas, at(0.90, 0.09), 14 * ps, pen(0.34));
    _handStar(canvas, at(0.965, 0.15), 10 * ps, pen(0.30));

    // ── Right gutter: flower + dot ──────────────────────────────────────
    _flower(canvas, at(0.955, 0.27), 11 * ps, pen(0.30));
    _dot(canvas, at(0.945, 0.34), 1.8 * ps, fill(0.30));

    // ── Left gutter: balloon then joyful person ─────────────────────────
    _balloon(canvas, at(0.048, 0.40), 11 * ps, pen(0.26));
    _personJoy(canvas, at(0.075, 0.52), 10 * ps, pen(0.24));
    _sparkle(canvas, at(0.16, 0.55), 8 * ps, pen(0.24));

    // ── Bottom-left cluster (hearts) ────────────────────────────────────
    _heart(canvas, at(0.10, 0.79), 16 * ps, pen(0.34));
    _heart(canvas, at(0.20, 0.87), 10 * ps, pen(0.26));
    _sparkle(canvas, at(0.055, 0.90), 9 * ps, pen(0.26));

    // ── Bottom-right cluster (star + smiley + balloon) ──────────────────
    _handStar(canvas, at(0.93, 0.79), 13 * ps, pen(0.32));
    _smiley(canvas, at(0.84, 0.87), 9 * ps, pen(0.24));
    _balloon(canvas, at(0.955, 0.94), 9 * ps, pen(0.26));

    // ── Bottom scribble ─────────────────────────────────────────────────
    _scribble(canvas, at(0.30, 0.965), w * 0.42, 5 * s, pen(0.22));
  }

  void _dot(Canvas canvas, Offset c, double r, Paint fill) {
    canvas.drawCircle(c, r, fill);
  }

  /// Four-point diamond sparkle (hand-drawn feel).
  void _sparkle(Canvas canvas, Offset c, double r, Paint pen) {
    final path = Path();
    const outer = 8;
    for (var i = 0; i < outer; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final radius = i.isEven ? r * 0.34 : r;
      final p = Offset(
            c.dx + math.cos(angle) * radius,
            c.dy + math.sin(angle) * radius,
          );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, pen);
  }

  /// Hand-drawn five-point star.
  void _handStar(Canvas canvas, Offset c, double r, Paint pen) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final radius = i.isEven ? r : r * 0.46;
      final p = Offset(
            c.dx + math.cos(angle) * radius,
            c.dy + math.sin(angle) * radius,
          );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, pen);
  }

  /// Outline heart with a pencil feel.
  void _heart(Canvas canvas, Offset c, double s, Paint pen) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s)
      ..cubicTo(
        c.dx - 1.15 * s,
        c.dy + 0.10 * s,
        c.dx - 1.05 * s,
        c.dy - 0.60 * s,
        c.dx,
        c.dy - 0.18 * s,
      )
      ..cubicTo(
        c.dx + 1.05 * s,
        c.dy - 0.60 * s,
        c.dx + 1.15 * s,
        c.dy + 0.10 * s,
        c.dx,
        c.dy + s,
      );
    canvas.drawPath(path, pen);
  }

  /// Simple smiling face (joy).
  void _smiley(Canvas canvas, Offset c, double r, Paint pen) {
    canvas.drawCircle(c, r, pen);
    final cc = r * 0.11;
    canvas.drawCircle(
      Offset(c.dx - r * 0.35, c.dy - r * 0.12),
      cc,
      pen,
    );
    canvas.drawCircle(
      Offset(c.dx + r * 0.35, c.dy - r * 0.12),
      cc,
      pen,
    );
    final mouth = Path()
      ..addArc(
        Rect.fromCircle(center: c.translate(0, r * 0.18), radius: r * 0.62),
        math.pi * 0.15,
        math.pi * 0.7,
      );
    canvas.drawPath(mouth, pen);
  }

  /// Sun with soft rays (brightness / joy).
  void _sunny(Canvas canvas, Offset c, double r, Paint pen) {
    canvas.drawCircle(c, r, pen);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final inner = Offset(c.dx + math.cos(a) * (r + 4), c.dy + math.sin(a) * (r + 4));
      final outer = Offset(c.dx + math.cos(a) * (r + 11), c.dy + math.sin(a) * (r + 11));
      canvas.drawLine(inner, outer, pen);
    }
  }

  /// Simple flower (joy / gratitude).
  void _flower(Canvas canvas, Offset c, double r, Paint pen) {
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * math.pi / 5;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r),
        r * 0.48,
        pen,
      );
    }
    canvas.drawCircle(c, r * 0.30, pen);
  }

  /// Balloon with a wavy string (celebration).
  void _balloon(Canvas canvas, Offset c, double r, Paint pen) {
    final oval = Path()
      ..moveTo(c.dx - r, c.dy - r * 0.55)
      ..cubicTo(
        c.dx - r,
        c.dy - r * 1.15,
        c.dx + r,
        c.dy - r * 1.15,
        c.dx + r,
        c.dy - r * 0.55,
      )
      ..cubicTo(
        c.dx + r,
        c.dy + r * 0.75,
        c.dx,
        c.dy + r * 1.05,
        c.dx,
        c.dy + r * 1.05,
      )
      ..cubicTo(
        c.dx,
        c.dy + r * 1.05,
        c.dx - r,
        c.dy + r * 0.75,
        c.dx - r,
        c.dy - r * 0.55,
      );
    canvas.drawPath(oval, pen);
    // Knot + string.
    final string = Path()
      ..moveTo(c.dx, c.dy + r * 1.05)
      ..cubicTo(
        c.dx - r * 0.5,
        c.dy + r * 1.6,
        c.dx + r * 0.5,
        c.dy + r * 1.9,
        c.dx,
        c.dy + r * 2.4,
      );
    canvas.drawPath(string, pen);
  }

  /// Tiny joyful person with both arms raised (hooray!).
  void _personJoy(Canvas canvas, Offset c, double s, Paint pen) {
    // Head.
    canvas.drawCircle(c.translate(0, -0.55 * s), 0.18 * s, pen);
    // Body.
    canvas.drawLine(c.translate(0, -0.35 * s), c.translate(0, 0.35 * s), pen);
    // Raised arms.
    canvas.drawLine(c.translate(0, -0.12 * s), c.translate(-0.5 * s, -0.55 * s), pen);
    canvas.drawLine(c.translate(0, -0.12 * s), c.translate(0.5 * s, -0.55 * s), pen);
    // Legs.
    canvas.drawLine(c.translate(0, 0.35 * s), c.translate(-0.2 * s, 0.7 * s), pen);
    canvas.drawLine(c.translate(0, 0.35 * s), c.translate(0.2 * s, 0.7 * s), pen);
    // Smile.
    final mouth = Path()
      ..addArc(
        Rect.fromCircle(center: c.translate(0, -0.52 * s), radius: 0.09 * s),
        math.pi * 0.1,
        math.pi * 0.8,
      );
    canvas.drawPath(mouth, pen);
  }

  /// Wavy underline scribble.
  void _scribble(
    Canvas canvas,
    Offset start,
    double length,
    double amp,
    Paint pen,
  ) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + length * 0.33,
        start.dy - amp,
        start.dx + length * 0.66,
        start.dy + amp,
        start.dx + length,
        start.dy,
      );
    canvas.drawPath(path, pen);
  }

  @override
  bool shouldRepaint(_DoodlePainter oldDelegate) => false;
}