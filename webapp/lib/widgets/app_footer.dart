import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../services/stats_service.dart';

const Color _footerLabel = Color(0xFFB9B7B1);

/// Full-width dark stats band pinned at the bottom of the page.
///
/// The numbers count up from zero each time the footer scrolls into view and
/// keep counting toward the latest value whenever a counter changes live.
class AppFooter extends StatefulWidget {
  const AppFooter({
    super.key,
    required this.documents,
    required this.countersStream,
    required this.scrollController,
  });

  /// Number of uploaded PDFs (comes straight from the API, not Firestore).
  final int documents;

  final Stream<StatsCounters> countersStream;

  /// The page's scroll controller, used to detect when the footer is visible.
  final ScrollController scrollController;

  @override
  State<AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter> {
  final GlobalKey _boxKey = GlobalKey();
  int _run = 0;
  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(AppFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      oldWidget.scrollController.removeListener(_check);
      widget.scrollController.addListener(_check);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final visible = _isVisible();
    if (visible && !_wasVisible) setState(() => _run++);
    _wasVisible = visible;
  }

  bool _isVisible() {
    final render = _boxKey.currentContext?.findRenderObject();
    if (render is! RenderBox) return false;
    final screenHeight = MediaQuery.of(context).size.height;
    final pos = render.localToGlobal(Offset.zero);
    return pos.dy < screenHeight && pos.dy + render.size.height > 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StatsCounters>(
      stream: widget.countersStream,
      builder: (context, snapshot) {
        final counters = snapshot.data ?? StatsCounters.zero();
        return Container(
          key: _boxKey,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF000000),
                Color(0xFF121212),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 88),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 160,
                runSpacing: AppSpacing.xl,
                children: [
                  _Metric(
                    label: 'Visites',
                    number: _AnimatedNumber(value: counters.visits, run: _run),
                  ),
                  _Metric(
                    label: 'Documents',
                    number: _AnimatedNumber(value: widget.documents, run: _run),
                  ),
                  _Metric(
                    label: 'Téléchargements',
                    number: _AnimatedNumber(
                      value: counters.downloads,
                      run: _run,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 88),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Made With',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.favorite,
                            color: AppColors.white,
                            size: 17,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'by: Raed Affes (Ensi) & Edam Mnif (Supcom)',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.number});

  final String label;
  final Widget number;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        number,
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.metadata(_footerLabel).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Counts from zero to [value] (fast ease-out) every time [run] changes,
/// and smoothly catches up whenever [value] changes while running.
class _AnimatedNumber extends StatefulWidget {
  const _AnimatedNumber({required this.value, required this.run});

  final int value;

  /// Changes whenever the footer becomes visible again, restarting the count.
  final int run;

  @override
  State<_AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<_AnimatedNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  late double _start;
  late int _target;

  @override
  void initState() {
    super.initState();
    _start = 0;
    _target = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.addListener(() => setState(() {}));
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.run != oldWidget.run) {
      _start = 0;
      _target = widget.value;
      _controller.forward(from: 0);
    } else if (widget.value != oldWidget.value) {
      _start = _target.toDouble();
      _target = widget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _start + (_target - _start) * _curve.value;
    return Text(
      NumberFormat.decimalPattern('fr').format(shown.round()),
      style: AppTypography.tileTitle(AppColors.white).copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
