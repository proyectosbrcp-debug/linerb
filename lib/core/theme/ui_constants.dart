import 'package:flutter/material.dart';

class LinerbSpacing {
  const LinerbSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class LinerbRadius {
  const LinerbRadius._();

  static const double card = 12;
  static const double button = 10;
}

class LinerbTouchTarget {
  const LinerbTouchTarget._();

  static const double min = 48;
  static const double primaryButtonHeight = 55;
  static const double secondaryButtonHeight = 52;
}

class LinerbColors {
  const LinerbColors._();

  static const Color background = Color(0xFFF4F7FA);
  static const Color primaryBlue = Color(0xFF0D47A1);
  static const Color danger = Color(0xFFB71C1C);
  static const Color success = Color(0xFF2E7D32);
  static const Color warningText = Color(0xFF6D4C00);
}

class LinerbTextStyles {
  const LinerbTextStyles._();

  static const TextStyle screenTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: LinerbColors.primaryBlue,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
}
