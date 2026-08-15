import 'package:flutter/material.dart';

import 'landing_colors.dart';

class HeroText extends StatelessWidget {
  final VoidCallback onLibraryPressed;
  final bool isCompact;
  const HeroText({
    super.key,
    required this.onLibraryPressed,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = isCompact ? 26.0 : 42.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'BIBLIOTHÈQUE',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 2,
            height: 1.1,
          ),
        ),
        Text(
          'EN LIGNE',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w300,
            color: Colors.white,
            letterSpacing: 2,
            height: 1.1,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 14, bottom: 18),
          width: 60,
          height: 3,
          color: AppColors.orange,
        ),
        const Text(
          'Tous vos cours, Ds et examens,\norganisés par matière et par niveau,\ndans un accès simple et sécurisé.',
          style: TextStyle(
            color: AppColors.mutedWhite,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: onLibraryPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Bibliothèque',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
