import 'package:flutter/material.dart';

import 'landing_colors.dart';

class LandingNavBar extends StatelessWidget {
  final bool isWide;
  const LandingNavBar({super.key, required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: const [
            Icon(Icons.emoji_events, color: AppColors.orange, size: 26),
            SizedBox(width: 10),
            Text(
              'Company Logo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (isWide)
          Row(
            children: [
              NavLink('Home'),
              const SizedBox(width: 12),
              NavPill('About'),
              const SizedBox(width: 12),
              NavLink('Help'),
              const SizedBox(width: 12),
              NavLink('Info'),
            ],
          )
        else
          const Icon(Icons.menu, color: Colors.white),
      ],
    );
  }
}

class NavLink extends StatelessWidget {
  final String label;
  const NavLink(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class NavPill extends StatelessWidget {
  final String label;
  const NavPill(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
