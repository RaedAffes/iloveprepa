import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_spacing.dart';
import 'pdf_embed_platform.dart';

/// Opens a fullscreen preview of the PDF at [url] inside the current page (no
/// browser-tab switch). The viewer always covers the whole page; its slim top
/// bar holds a single close button.
Future<void> showDocumentViewer({
  required BuildContext context,
  required String url,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer l’aperçu',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, _, _) => _FullscreenViewer(url: url),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _FullscreenViewer extends StatelessWidget {
  const _FullscreenViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ViewerBar(),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border,
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.surfaceSecondary,
                child: PdfEmbed(url: url),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim top bar holding the close button.
class _ViewerBar extends StatelessWidget {
  const _ViewerBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Fermer',
            icon: const Icon(Icons.close_rounded, size: 19),
            color: AppColors.secondary,
            hoverColor: AppColors.hover,
            splashRadius: 18,
          ),
        ),
      ),
    );
  }
}
