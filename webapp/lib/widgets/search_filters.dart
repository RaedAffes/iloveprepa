import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/library_index.dart';

/// Filter chips ([SearchScope]) + Year / Semester / Subject / Type dropdowns
/// shown above the search results.
class SearchFilters extends StatelessWidget {
  const SearchFilters({
    super.key,
    required this.scope,
    required this.onScopeChanged,
    required this.yearOptions,
    required this.semesterOptions,
    required this.subjectOptions,
    required this.typeOptions,
    required this.year,
    required this.semester,
    required this.subject,
    required this.type,
    required this.onYearChanged,
    required this.onSemesterChanged,
    required this.onSubjectChanged,
    required this.onTypeChanged,
  });

  final SearchScope scope;
  final ValueChanged<SearchScope> onScopeChanged;
  final List<String> yearOptions;
  final List<String> semesterOptions;
  final List<String> subjectOptions;
  final List<String> typeOptions;
  final String? year;
  final String? semester;
  final String? subject;
  final String? type;
  final ValueChanged<String?> onYearChanged;
  final ValueChanged<String?> onSemesterChanged;
  final ValueChanged<String?> onSubjectChanged;
  final ValueChanged<String?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              for (final s in SearchScope.values) ...[
                _Chip(
                  label: s.label,
                  selected: scope == s,
                  onTap: () => onScopeChanged(s),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Dropdown(
              label: 'Année',
              value: year,
              options: yearOptions,
              onChanged: onYearChanged,
            ),
            _Dropdown(
              label: 'Semestre',
              value: semester,
              options: semesterOptions,
              onChanged: onSemesterChanged,
            ),
            _Dropdown(
              label: 'Matière',
              value: subject,
              options: subjectOptions,
              onChanged: onSubjectChanged,
            ),
            _Dropdown(
              label: 'Type',
              value: type,
              options: typeOptions,
              onChanged: onTypeChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.label(
              selected ? AppColors.white : AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.searchR,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.xs,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          borderRadius: AppRadius.searchR,
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          iconEnabledColor: AppColors.secondary,
          style: AppTypography.label(AppColors.ink),
          hint: Text(label, style: AppTypography.label(AppColors.muted)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Tous · $label',
                style: AppTypography.metadata(AppColors.secondary),
              ),
            ),
            for (final option in options)
              DropdownMenuItem<String?>(value: option, child: Text(option)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
