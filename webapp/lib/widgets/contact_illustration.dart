import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Builds the contact-form illustration from the same SVG the design uses.
/// The base scene (clouds, letter, figures) is drawn once and stays static;
/// the floating envelope and the six blinking stars are layered on top so each
/// can be animated independently, mirroring the source CSS (`float` on the
/// envelope, staggered `blink` on the stars). Every layer shares the full
/// canvas so the elements keep their exact positions from the original art.
class ContactIllustration extends StatefulWidget {
  const ContactIllustration({super.key, required this.height});

  final double height;

  @override
  State<ContactIllustration> createState() => _ContactIllustrationState();
}

class _ContactIllustrationState extends State<ContactIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.height * (790 / 563),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _SvgView('assets/illustrations/contact_art.svg'),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.linear.transform(_controller.value);
              final y = -math.sin(t * 2 * math.pi) * 20;
              return Transform.translate(
                offset: Offset(0, y),
                child: const _SvgView('assets/illustrations/contact_envelope.svg'),
              );
            },
          ),
          _BlinkingStar('assets/illustrations/contact_star1.svg', 100,
              _controller),
          _BlinkingStar('assets/illustrations/contact_star2.svg', 100,
              _controller),
          _BlinkingStar('assets/illustrations/contact_star3.svg', 500,
              _controller),
          _BlinkingStar('assets/illustrations/contact_star4.svg', 700,
              _controller),
          _BlinkingStar('assets/illustrations/contact_star5.svg', 300,
              _controller),
          _BlinkingStar('assets/illustrations/contact_star6.svg', 200,
              _controller),
        ],
      ),
    );
  }
}

class _BlinkingStar extends StatelessWidget {
  const _BlinkingStar(this.asset, this.offsetMs, this.controller);

  final String asset;
  final int offsetMs;
  final AnimationController controller;

  // Blink repeats every 1s (mirrors the source animation); offsetMs staggers
  // each star around the loop.
  static const int _periodMs = 1000;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value * _periodMs + offsetMs) % _periodMs /
            _periodMs;
        final opacity = t < 0.5 ? t / 0.5 : 1.5 - t / 0.5;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: _SvgView(asset),
        );
      },
    );
  }
}

class _SvgView extends StatelessWidget {
  const _SvgView(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      fit: BoxFit.contain,
    );
  }
}