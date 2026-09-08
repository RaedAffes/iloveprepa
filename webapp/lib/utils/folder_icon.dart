import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Per-subject icon colors. Muted, professional tones chosen to stay
/// readable on the dark blue sidebar (landing midBlue #1B3FA0).
class _SubjectColor {
  static const math = Color(0xFFD4A017); // deep gold
  static const physique = Color(0xFF6FA8DC); // steel blue
  static const chimie = Color(0xFF52A88E); // teal green
  static const info = Color(0xFF8496B8); // slate blue
  static const langage = Color(0xFFC07C3B); // copper
  static const sta = Color(0xFF94979E); // gunmetal
  static const resume = Color(0xFFA64747); // wine red
}

/// Maps a folder name to its vector icon and color. Unknown folders get the
/// classic Google Drive-style yellow folder glyph.
///
/// Returned as a named record so callers can read `.icon` and `.color`.
({IconData icon, Color color}) folderIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('math')) {
    return (icon: Icons.all_inclusive, color: _SubjectColor.math);
  }
  if (n.contains('physique')) {
    return (icon: Icons.public, color: _SubjectColor.physique);
  }
  if (n.contains('chimie')) {
    return (icon: Icons.co2, color: _SubjectColor.chimie);
  }
  if (n.contains('info')) {
    return (icon: Icons.code_rounded, color: _SubjectColor.info);
  }
  if (n.contains('langage') || n.contains('langue') || n.contains('fran')) {
    return (icon: Icons.translate_rounded, color: _SubjectColor.langage);
  }
  if (n.contains('sta')) {
    return (icon: Icons.build, color: _SubjectColor.sta);
  }
  if (n.contains('resume') || n.contains('résumé')) {
    return (icon: Icons.summarize_rounded, color: _SubjectColor.resume);
  }
  return (icon: Icons.folder_rounded, color: AppColors.folderYellow);
}