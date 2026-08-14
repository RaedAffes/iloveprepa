import 'package:flutter/material.dart';

import 'landing_colors.dart';

/// Where your transparent PNG/SVG illustration goes.
/// Replace this widget's child with:
///   Image.asset('assets/images/library_illustration.png')
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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.midBlue.withValues(alpha: 0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        'Illustration goes here\n(Image.asset(...))',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.midBlue.withValues(alpha: 0.5),
          fontSize: 14,
        ),
      ),
    );
  }
}
