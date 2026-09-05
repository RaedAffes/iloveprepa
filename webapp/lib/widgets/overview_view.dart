import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../models/library_folder.dart';
import '../utils/folder_icon.dart';

/// Home shown while no folder is selected: just the top-level folder icons
/// and their names, centered — no tiles, no counts, minimal and clean.
class OverviewView extends StatelessWidget {
  const OverviewView({
    super.key,
    required this.folders,
    required this.onOpenFolder,
  });

  final List<LibraryFolder> folders;
  final void Function(List<String> path) onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final sorted = List<LibraryFolder>.from(folders)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (sorted.isEmpty) return _empty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 860
                ? 5
                : width >= 640
                    ? 4
                    : width >= 420
                        ? 3
                        : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.xl,
                childAspectRatio: 0.92,
              ),
              itemCount: sorted.length,
              itemBuilder: (context, index) => _FolderIcon(
                folder: sorted[index],
                onOpen: () => onOpenFolder([sorted[index].name]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Center(
        child: Text(
          'Aucune matière disponible',
          style: AppTypography.label(_greyMuted),
        ),
      ),
    );
  }
}

class _FolderIcon extends StatefulWidget {
  const _FolderIcon({required this.folder, required this.onOpen});

  final LibraryFolder folder;
  final VoidCallback onOpen;

  @override
  State<_FolderIcon> createState() => _FolderIconState();
}

class _FolderIconState extends State<_FolderIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: AppRadius.cardR,
        hoverColor: AppColors.hover,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.identity()..scaleByDouble(_hovered ? 1.06 : 1.0, _hovered ? 1.06 : 1.0, _hovered ? 1.06 : 1.0, 1.0),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.asset(
                    folderIcon(widget.folder.name),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.folder.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(_ink).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Color _ink = Color(0xFF1B1B1B);
const Color _greyMuted = Color(0xFF6B7280);
