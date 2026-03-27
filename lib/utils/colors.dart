import 'package:flutter/material.dart';

class AppColors {
  // Theme Constraint: Strict palette adherence
  static const Color background = Color(0xFFF7F8F0);
  static const Color primaryDark = Color(0xFF355872);
  static const Color secondaryAccent = Color(0xFF7AAACE);
  static const Color highlightActive = Color(0xFF9CD5FF);

  // Additional Semantic Colors
  static const Color success = Color(0xFF16A34A); // green-600 equivalent
  static const Color error = Color(0xFFEF4444); // red-500 equivalent
  static const Color warningOrange = Color(0xFFF59E0B); // amber-500
  static const Color textPrimary = Color(0xFF355872);
  static const Color textSecondary = Color(0xFF7AAACE);
  static const Color white = Colors.white;

  // Admin / Surface colors
  static const Color surfaceLight = Color(0xFFF1F5F9); // slate-100
  static const Color divider = Color(0xFFE2E8F0); // slate-200
  static const Color cardBorder = Color(0xFFCBD5E1); // slate-300

  // POS home screen only
  static const Color posBackground = Color(0xFFF0F5FA); // cool blue-grey scaffold
  static const Color posButtonIdle = Color(0xFFDEECF8); // light blue fill, inactive quick-action buttons
}
