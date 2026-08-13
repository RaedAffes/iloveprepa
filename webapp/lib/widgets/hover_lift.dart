import 'package:flutter/material.dart';

/// Subtle lift + pointer cursor on hover. Wraps any card-style widget.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.child, this.onTap, this.lift = 4});

  final Widget child;
  final VoidCallback? onTap;
  final double lift;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -widget.lift : 0, 0),
          child: widget.child,
        ),
      ),
    );
  }
}
