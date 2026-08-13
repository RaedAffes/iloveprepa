import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_typography.dart';

/// Small, elegant file-type mark — avoids giant PDF logos.
class FileMark extends StatelessWidget {
  const FileMark({
    super.key,
    required this.isPdf,
    required this.extension,
    this.size = 42,
  });

  final bool isPdf;
  final String extension;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = isPdf
        ? 'PDF'
        : (extension.isEmpty ? 'FILE' : extension.toUpperCase());

    final Color bg;
    final Color fg;
    final Color border;
    if (isPdf) {
      bg = AppColors.accentSoft;
      fg = AppColors.accentDark;
      border = AppColors.accent.withValues(alpha: 0.25);
    } else {
      bg = AppColors.surfaceMuted;
      fg = AppColors.secondary;
      border = AppColors.border;
    }

    return Container(
      width: size,
      height: size + (size * 0.24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip + 2),
        border: Border.all(color: border, width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.metadata(fg).copyWith(
          fontSize: size >= 42 ? 11 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
