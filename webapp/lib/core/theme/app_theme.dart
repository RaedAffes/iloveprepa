import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Material theme assembled from the design tokens.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.accentGreen,
        secondary: AppColors.accentGreen,
        surface: AppColors.white,
        onSurface: AppColors.darkCharcoal,
        onSurfaceVariant: AppColors.secondary,
        surfaceContainerHighest: AppColors.surfaceSecondary,
      ),
      scaffoldBackgroundColor: AppColors.white,
      // AppBar theme - very subtle
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.darkCharcoal,
        elevation: 0,
        titleTextStyle: AppTypography.tileTitle(),
        centerTitle: false,
      ),
      // Card theme - rounded corners, subtle shadow
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      // Divider theme
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 8,
      ),
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
        hintStyle: AppTypography.body(AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      // Elevated button theme - subtle
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGreen,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.body(AppColors.white),
        ),
      ),
      // Outline button theme - subtle
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkCharcoal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border, width: 1),
          ),
          textStyle: AppTypography.body(AppColors.darkCharcoal),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(),
    );

    // Override specific text styles for the workspace aesthetic
    return theme.copyWith(
      textTheme: GoogleFonts.interTextTheme(theme.textTheme).copyWith(
        // Display/headline styles
        displayLarge: theme.textTheme.displayLarge!.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 32,
          color: AppColors.darkCharcoal,
        ),
        displayMedium: theme.textTheme.displayMedium!.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 28,
          color: AppColors.darkCharcoal,
        ),
        displaySmall: theme.textTheme.displaySmall!.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 24,
          color: AppColors.darkCharcoal,
        ),
        // Body/subbody styles
        bodyLarge: theme.textTheme.bodyLarge!.copyWith(
          fontSize: 16,
          color: AppColors.darkCharcoal,
        ),
        bodyMedium: theme.textTheme.bodyMedium!.copyWith(
          fontSize: 14,
          color: AppColors.darkCharcoal,
        ),
        bodySmall: theme.textTheme.bodySmall!.copyWith(
          fontSize: 13,
          color: AppColors.secondary,
        ),
        // Label styles
        labelLarge: theme.textTheme.labelLarge!.copyWith(
          fontSize: 12,
          color: AppColors.muted,
        ),
        labelMedium: theme.textTheme.labelMedium!.copyWith(
          fontSize: 11,
          color: AppColors.muted,
        ),
        labelSmall: theme.textTheme.labelSmall!.copyWith(
          fontSize: 10,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
