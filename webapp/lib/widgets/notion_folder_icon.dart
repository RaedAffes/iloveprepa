import 'package:flutter/material.dart';

import '../utils/folder_icon.dart';

/// A folder glyph for the library tree.
///
/// Pass [name] to get the themed subject icon/color for a folder; without a
/// name, the bundled Google Drive-style folder image (assets/folder.png) is
/// shown, exactly like the subfolder rows of v4/v5.
class NotionFolderIcon extends StatelessWidget {
  const NotionFolderIcon({super.key, this.size = 24, this.name});

  final double size;
  final String? name;

  @override
  Widget build(BuildContext context) {
    if (name == null) {
      return Image.asset(
        'assets/folder.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    final (:icon, :color) = folderIcon(name!);
    final n = name!.toLowerCase();
    final extra = n.contains('chimie')
        ? 1.55
        : n.contains('info')
            ? 1.35
            : 1.0;
    final glyph = Icon(icon, size: size * extra, color: color);
    if (n.contains('chimie')) {
      return Transform.translate(offset: const Offset(0, -4), child: glyph);
    }
    return glyph;
  }
}