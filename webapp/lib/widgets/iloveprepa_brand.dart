import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The "I♥Prepa" wordmark shared by the sidebar and the top bar, so the brand
/// stays identical wherever it appears (and stays visible even when the
/// sidebar is collapsed).
class IloveprepaBrand extends StatelessWidget {
  const IloveprepaBrand({
    super.key,
    this.fontSize = 26,
    this.iconSize = 24,
    this.color,
    this.onTap,
  });

  final double fontSize;
  final double iconSize;
  final Color? color;

  /// Optional tap handler (e.g. returning to the landing page). When null the
  /// wordmark is not interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = Text.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: color ?? AppColors.darkCharcoal,
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
    final onTap = this.onTap;
    if (onTap == null) return brand;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: brand,
      ),
    );
  }
}
