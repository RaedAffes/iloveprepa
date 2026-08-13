import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_typography.dart';

/// Editorial navigation trail (Accueil / Subject / Folder …).
///
/// [segments] is the current folder path; tapping any entry navigates back.
/// Tapping "Accueil" passes `-1` to [onTap].
class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({super.key, required this.segments, required this.onTap});

  final List<String> segments;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _crumb('Accueil', index: -1),
      for (var i = 0; i < segments.length; i++) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('›', style: AppTypography.metadata(AppColors.muted)),
        ),
        _crumb(segments[i], index: i),
      ],
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }

  Widget _crumb(String label, {required int index}) {
    final isLast = index == segments.length - 1;
    final Color color = isLast ? AppColors.greenDark : AppColors.accentDark;
    final FontWeight weight = isLast ? FontWeight.w700 : FontWeight.w600;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: AppRadius.navR,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: AppTypography.metadata(color).copyWith(fontWeight: weight),
        ),
      ),
    );
  }
}
