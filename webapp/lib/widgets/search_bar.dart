import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_typography.dart';

/// Minimal focused search field with a shortcut hint and clear action.
class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.autoFocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final bool autoFocus;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _hovered = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_sync);
  }

  @override
  void dispose() {
    _focus.removeListener(_sync);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _sync() {
    if (mounted && _focused != _focus.hasFocus) {
      setState(() => _focused = _focus.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS;
    final query = widget.controller.text;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.searchR,
          border: Border.all(
            color: _focused
                ? AppColors.accent
                : _hovered
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.border,
            width: _focused ? 1.4 : 1,
          ),
          boxShadow: _focused ? AppShadows.xs : null,
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          autofocus: widget.autoFocus,
          style: AppTypography.body(AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Rechercher une matière, un dossier ou un document…',
            hintStyle: AppTypography.body(),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 19,
              color: AppColors.textSecondary,
            ),
            suffixIcon: query.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _ShortcutChip(label: isMac ? '⌘K' : 'Ctrl K'),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      onPressed: () {
                        widget.controller.clear();
                        widget.onChanged('');
                      },
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close_rounded, size: 17),
                      color: AppColors.textSecondary,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(30, 30),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.metadata().copyWith(fontSize: 11),
      ),
    );
  }
}
