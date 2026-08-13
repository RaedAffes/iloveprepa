import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography scale — Inter, restrained and modern.
///
/// ```
/// Page title   30 / 700
/// Section      20 / 600
/// Card title   16 / 600
/// Body         14 / 400
/// Metadata     12 / 500
/// ```
class AppTypography {
  AppTypography._();

  static TextStyle pageTitle([Color? color]) => GoogleFonts.inter(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: color ?? AppColors.darkCharcoal,
  );

  static TextStyle sectionTitle([Color? color]) => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
    color: color ?? AppColors.darkCharcoal,
  );

  static TextStyle cardTitle([Color? color]) => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color ?? AppColors.darkCharcoal,
  );

  static TextStyle tileTitle([Color? color]) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color ?? AppColors.darkCharcoal,
  );

  static TextStyle body([Color? color]) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color ?? AppColors.secondary,
  );

  static TextStyle metadata([Color? color]) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: color ?? AppColors.secondary,
  );

  static TextStyle label([Color? color]) => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color ?? AppColors.darkCharcoal,
  );

  static TextStyle eyebrow([Color? color]) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    color: color ?? AppColors.muted,
  );
}
