import 'package:flutter/material.dart';

/// Google Drive-style folder icon rendered from the bundled asset
/// (assets/folder.png).
class NotionFolderIcon extends StatelessWidget {
  const NotionFolderIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/folder.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
