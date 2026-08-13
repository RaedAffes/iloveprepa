import 'package:flutter/material.dart';

/// Corner radii — soft, calm.
class AppRadius {
  AppRadius._();

  static const double button = 12;
  static const double search = 14;
  static const double card = 18;
  static const double cardSmall = 16;
  static const double dialog = 22;
  static const double nav = 10;
  static const double icon = 12;
  static const double chip = 8;

  static BorderRadius get buttonR => BorderRadius.circular(button);
  static BorderRadius get searchR => BorderRadius.circular(search);
  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get cardSmallR => BorderRadius.circular(cardSmall);
  static BorderRadius get navR => BorderRadius.circular(nav);
  static BorderRadius get iconR => BorderRadius.circular(icon);
}
