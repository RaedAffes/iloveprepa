import 'package:flutter/material.dart';

/// Extremely restrained shadows — prefer borders and surface contrast.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> xs = [
    BoxShadow(color: Color(0x0A17181C), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x1417181C), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1A17181C), blurRadius: 24, offset: Offset(0, 6)),
  ];

  static const Color scrim = Color(0x33000000);
}
