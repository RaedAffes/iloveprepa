/// Backward-compatible entry point.
///
/// Existing code imports `theme/app_theme.dart`; this shim re-exports the
/// tokenised core so the whole app reads visual values from one place.
library;

export '../core/theme/app_colors.dart';
export '../core/theme/app_motion.dart';
export '../core/theme/app_radius.dart';
export '../core/theme/app_shadows.dart';
export '../core/theme/app_spacing.dart';
export '../core/theme/app_theme.dart';
export '../core/theme/app_typography.dart';
 
