import 'package:flutter/material.dart';

import '../iloveprepa_brand.dart';
import 'landing_colors.dart';

class LandingNavBar extends StatelessWidget {
  final bool isWide;
  final bool scrolled;
  final ValueChanged<String> onNavigate;

  /// Scrolls the page back to the top when the brand mark is tapped.
  final VoidCallback? onHome;

  const LandingNavBar({
    super.key,
    required this.isWide,
    this.scrolled = false,
    required this.onNavigate,
    this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IloveprepaBrand(
          fontSize: 26,
          iconSize: 24,
          color: Colors.white,
          onTap: onHome,
        ),
        const Spacer(),
        if (isWide)
          Row(
            children: [
              NavPill('À propos', onTap: () => onNavigate('about')),
              const SizedBox(width: 12),
              NavPill('Faire un don', onTap: () => onNavigate('donate')),
              const SizedBox(width: 12),
              NavPill('Contact', onTap: () => onNavigate('contact')),
            ],
          )
        else
          _MenuButton(scrolled: scrolled, onNavigate: onNavigate),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.scrolled, required this.onNavigate});

  final bool scrolled;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      icon: Icon(
        Icons.menu,
        color: scrolled ? Colors.white : AppColors.midBlue,
        size: 28,
      ),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: onNavigate,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'about',
          child: Center(child: NavPill('À propos')),
        ),
        PopupMenuItem(
          value: 'donate',
          child: Center(child: NavPill('Faire un don')),
        ),
        PopupMenuItem(
          value: 'contact',
          child: Center(child: NavPill('Contact')),
        ),
      ],
    );
  }
}

class NavPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  const NavPill(
    this.label, {
    super.key,
    this.backgroundColor = AppColors.orange,
    this.textColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
