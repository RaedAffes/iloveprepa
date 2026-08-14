import 'package:flutter/material.dart';

/// The hero illustration for the landing page.
/// The image is clipped with large rounded corners so it blends into the
/// page instead of looking like a separate boxed asset.
class IllustrationPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  const IllustrationPlaceholder({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/main.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
