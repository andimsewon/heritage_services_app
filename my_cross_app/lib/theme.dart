import 'package:flutter/material.dart';

/// Centralizes shared design tokens used across the heritage detail redesign.
class AppTheme {
  const AppTheme._();

  static const Color primaryBlue = Color(0xFF1F4E79);
  static const Color sectionBorder = Color(0xFF40658A);
  static const Color tableHeaderBackground = Color(0xFFF6F8FA);
  static const Color tableRowAlt = Color(0xFFF0F3F6);
  static const Color tableDivider = Color(0xFFE0E6EB);

  static const double cardRadius = 12;
  static const double cardElevation = 1.5;

  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 20,
  );

  static const EdgeInsets sectionTitlePadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  static const double sectionGap = 24;
  static const double denseGap = 16;

  static const Map<String, Color> gradeColors = {
    'A': Color(0xFF4CAF50),
    'B': Color(0xFF8BC34A),
    'C': Color(0xFFFFC107),
    'D': Color(0xFFFF9800),
    'E': Color(0xFFF44336),
  };
}
