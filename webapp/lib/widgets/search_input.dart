import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_typography.dart';

/// Library-wide search field. Rendered in the sidebar (compact) but styled
/// consistently everywhere it appears.
class SearchInput extends StatefulWidget {
  const SearchInput({
    super.key,
    required this.controller,
    required this.onChanged,
    this.compact = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool compact;

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  final FocusNode _focus = FocusNode();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_sync);
  }

  @override
  void dispose() {
    _focus.removeListener(_sync);
    _focus.dispose();
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final borderColor = focused
        ? AppColors.darkCharcoal.withValues(alpha: 0.35)
        : _hovered
            ? AppColors.secondary.withValues(alpha: 0.35)
            : AppColors.border;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.searchR,
          border: Border.all(color: borderColor, width: 1),
          boxShadow: _hovered || focused ? AppShadows.xs : null,
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          onSubmitted: widget.onChanged,
          style: widget.compact
              ? AppTypography.body(AppColors.darkCharcoal).copyWith(
                  fontSize: 13,
                )
              : AppTypography.body(AppColors.darkCharcoal).copyWith(
                  fontSize: 15,
                ),
          decoration: InputDecoration(
            hintText: 'Rechercher une matière, un dossier ou un document…',
            hintStyle: widget.compact
                ? AppTypography.body(AppColors.muted).copyWith(fontSize: 13)
                : AppTypography.body(AppColors.muted).copyWith(fontSize: 15),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: widget.compact ? 18 : 21,
              color: AppColors.secondary,
            ),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.secondary,
                  ),
            border: InputBorder.none,
            contentPadding: widget.compact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          ),
        ),
      ),
    );
  }
}
