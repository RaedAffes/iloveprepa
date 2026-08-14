import 'package:flutter/material.dart';

/// Central UI colors — "Notion-inspired workspace" palette.
///
/// Clean, minimal, soft-white workspace with charcoal accents and pastel accents.
/// No saturated neon colors. Only very soft pastel accents for interactive hints.
class AppColors {
  AppColors._();

  // Main background (Notion workspace)
  static const background = Color(0xFFFFFFFF);
  // Sidebar (Notion sidebar tone)
  static const sidebar = Color(0xFFF7F7F5);
  // Secondary surfaces
  static const surfaceSecondary = Color(0xFFF7F7F5);
  // Hover / selected surface (Notion hover tone)
  static const hover = Color(0xFFEFEFEE);

  // Ink / primary text (Notion ink)
  static const darkCharcoal = Color(0xFF37352F);
  static const secondary = Color(0xFF787774);
  static const muted = Color(0xFF9B9A97);

  // Borders
  static const border = Color(0xFFE9E9E7);

  // Google Drive style folder yellow
  static const folderYellow = Color(0xFFFFD24D);
  static const folderYellowDark = Color(0xFFE8A71B);
  static const folderYellowSoft = Color(0xFFFFF5D1);

  // Primary accent — Notion grey family (replaces the former green accent).
  static const accentGreen = Color(0xFF787774);
  static const accentGreenSoft = Color(0xFFF1F1EF);
  static const accentCoral = Color(0xFFF7B2A9);
  static const accentCoralSoft = Color(0xFFFDF0F3);
  static const accentYellow = Color(0xFFFDE9A3);
  static const accentYellowSoft = Color(0xFFFEF3CF);
  static const accentBlue = Color(0xFFCBE8F5);
  static const accentBlueSoft = Color(0xFFF7FAFD);
  static const accentPurple = Color(0xFFE0E7FF);
  static const accentPurpleSoft = Color(0xFFF8F4FA);

  // Deeper tones for glyphs sitting on the pale fills above.
  static const accentCoralDark = Color(0xFFB4482F);
  static const accentYellowDark = Color(0xFF9A7410);
  static const accentBlueDark = Color(0xFF2F6F9E);
  static const accentPurpleDark = Color(0xFF5B52C4);

  // Rules & states
  static const white = Colors.white;
  static const black = Colors.black;

  // Legacy-friendly aliases
  static const textPrimary = darkCharcoal;
  static const textSecondary = secondary;
  static const danger = Color(0xFFC4432F);
  static const dangerSoft = Color(0xFFFCEFEC);

  // ── Workspace aliases (used by the dashboard + shared widgets) ───────────

  /// White canvas for cards and content surfaces.
  static const surface = white;

  /// Very slightly tinted surface for chips, tags and quiet panels.
  static const surfaceMuted = surfaceSecondary;

  /// Primary ink for headings.
  static const ink = darkCharcoal;

  /// Primary accent (Notion grey) — focus rings, active chips, highlights.
  static const accent = accentGreen;

  /// Pale accent fill for icon tiles and selected rows.
  static const accentSoft = accentGreenSoft;

  /// Deeper accent for icon glyphs sitting on pale fills (Notion ink).
  static const accentDark = Color(0xFF37352F);

  // Grey family (aliases kept for the library widgets).
  static const greenDark = accentDark;
  static const greenSoft = accentGreenSoft;
}
