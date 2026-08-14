import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// The "I♥Prepa" wordmark shared by the sidebar and the top bar, so the brand
/// stays identical wherever it appears (and stays visible even when the
/// sidebar is collapsed).
class IloveprepaBrand extends StatelessWidget {
  const IloveprepaBrand({super.key, this.fontSize = 26, this.iconSize = 24});

  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: AppColors.darkCharcoal,
        ),
        children: [
          TextSpan(text: 'I'),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(
              Icons.favorite_rounded,
              size: iconSize,
              color: Colors.red,
            ),
          ),
          TextSpan(text: 'Prepa'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
