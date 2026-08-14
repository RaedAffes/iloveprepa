import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import 'pdf_embed_platform.dart';

/// Opens a floating, draggable preview window for the PDF at [url] inside the
/// current page (no browser-tab switch). The window stays centred and never
/// covers the whole page — the app stays visible around it — and its slim top
/// bar can be grabbed to move it around like a real window. The bar carries a
/// single close button.
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
    pageBuilder: (context, _, _) => _WindowedViewer(url: url),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _WindowedViewer extends StatefulWidget {
  const _WindowedViewer({required this.url});

  final String url;

  @override
  State<_WindowedViewer> createState() => _WindowedViewerState();
}

class _WindowedViewerState extends State<_WindowedViewer> {
  static const double _maxWindowWidth = 1060;
  static const double _maxWindowHeight = 840;
  static const double _minEdgeVisible = 80;

  // Layout-derived caches (recomputed every build, read from the drag handler).
  Size _bounds = Size.zero;
  double _winW = 0;
  double _winH = 0;

  // Offset added to the centred position while dragging.
  Offset _drag = Offset.zero;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_winW <= 0 || _winH <= 0) return;
    setState(() {
      _drag = Offset(
        (_drag.dx + details.delta.dx)
            .clamp(-(_winW - _minEdgeVisible), _bounds.width - _minEdgeVisible),
        (_drag.dy + details.delta.dy).clamp(
          0,
          _bounds.height - _minEdgeVisible,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          _bounds = Size(constraints.maxWidth, constraints.maxHeight);
          final winW = math.min(_maxWindowWidth, constraints.maxWidth * 0.86);
          final winH = math.min(_maxWindowHeight, constraints.maxHeight * 0.86);
          _winW = winW;
          _winH = winH;

          final left = (constraints.maxWidth - winW) / 2 + _drag.dx;
          final top = (constraints.maxHeight - winH) / 2 + _drag.dy;

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: winW,
                height: winH,
                child: Material(
                  color: AppColors.surface,
                  elevation: 24,
                  shadowColor: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppRadius.dialog),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ViewerBar(onDrag: _onDragUpdate),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: AppColors.surfaceSecondary,
                          child: PdfEmbed(url: widget.url),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Slim, draggable top bar holding a single close button.
class _ViewerBar extends StatelessWidget {
  const _ViewerBar({required this.onDrag});

  final void Function(DragUpdateDetails details) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onDrag,
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: SizedBox(
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
        ),
      ),
    );
  }
}
