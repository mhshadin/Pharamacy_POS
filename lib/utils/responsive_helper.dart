import 'package:flutter/material.dart';

/// Central responsive utility for PharmaPOS.
/// Breakpoints: <360 (small phone) | 360-600 (phone) | >600 (tablet)
class ResponsiveHelper {
  ResponsiveHelper._();

  // ── Breakpoint checks ──────────────────────────────────────────────────────

  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  // ── Spacing & padding ──────────────────────────────────────────────────────

  /// Standard screen edge padding.
  static EdgeInsets screenPadding(BuildContext context) {
    if (isSmallPhone(context)) return const EdgeInsets.all(12);
    if (isTablet(context)) return const EdgeInsets.all(24);
    return const EdgeInsets.all(16);
  }

  /// Horizontal-only screen padding (useful for horizontal scroll content).
  static EdgeInsets horizontalPadding(BuildContext context) {
    if (isSmallPhone(context)) return const EdgeInsets.symmetric(horizontal: 12);
    if (isTablet(context)) return const EdgeInsets.symmetric(horizontal: 24);
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  // ── Typography ─────────────────────────────────────────────────────────────

  static double titleSize(BuildContext context) =>
      isSmallPhone(context) ? 18.0 : 22.0;

  static double subtitleSize(BuildContext context) =>
      isSmallPhone(context) ? 13.0 : 15.0;

  static double bodySize(BuildContext context) =>
      isSmallPhone(context) ? 13.0 : 15.0;

  // ── Layout helpers ─────────────────────────────────────────────────────────

  /// Whether form fields should be laid out in two columns.
  /// Returns false on small phones (< 380) so fields stack vertically.
  static bool useTwoColumnForm(BoxConstraints constraints) =>
      constraints.maxWidth >= 380;

  /// Number of stat card columns on the dashboard.
  static int statCardColumns(BuildContext context) =>
      isTablet(context) ? 4 : 2;

  /// Responsive vertical gap between form sections.
  static double formGap(BuildContext context) =>
      isSmallPhone(context) ? 10.0 : 12.0;

  // ── Widgets ────────────────────────────────────────────────────────────────

  /// Builds a responsive two-column layout that falls back to single column
  /// when [constraints.maxWidth] is below [breakpoint] (default 380).
  static Widget responsiveRow({
    required BoxConstraints constraints,
    required Widget left,
    required Widget right,
    double spacing = 12,
    double breakpoint = 380,
  }) {
    if (constraints.maxWidth < breakpoint) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          SizedBox(height: spacing),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: spacing),
        Expanded(child: right),
      ],
    );
  }

  /// Same as [responsiveRow] but for three widgets (e.g., Boxes/Strips/Pieces).
  static Widget responsiveTriple({
    required BoxConstraints constraints,
    required Widget first,
    required Widget second,
    required Widget third,
    double spacing = 12,
    double breakpoint = 380,
  }) {
    if (constraints.maxWidth < breakpoint) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          first,
          SizedBox(height: spacing),
          second,
          SizedBox(height: spacing),
          third,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        SizedBox(width: spacing),
        Expanded(child: second),
        SizedBox(width: spacing),
        Expanded(child: third),
      ],
    );
  }
}
