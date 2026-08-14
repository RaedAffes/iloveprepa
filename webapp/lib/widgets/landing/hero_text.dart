import 'package:flutter/material.dart';

import 'landing_colors.dart';

class HeroText extends StatelessWidget {
  final VoidCallback onLibraryPressed;
  const HeroText({super.key, required this.onLibraryPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ONLINE',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w300,
            color: Colors.white,
            letterSpacing: 2,
            height: 1.1,
          ),
        ),
        const Text(
          'LIBRARY',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
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
          'Lorem ipsum dolor sit amet,\nconsectetur adipiscing elit,\nsed do eiusmod tempor.',
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
            'Library',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
