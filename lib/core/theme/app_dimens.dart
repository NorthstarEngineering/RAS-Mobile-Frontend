import 'package:flutter/material.dart';

/// Spacing scale from the Stitch config (`space-*`, `margin`, `gutter`).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Horizontal page padding (`px-margin`).
  static const double margin = 16;
  static const double gutter = 12;
}

/// Corner radii. Note the Stitch config overrides Tailwind's defaults:
/// `rounded` = 2, `rounded-lg` = 4, `rounded-xl` = 8, `rounded-full` = 12.
abstract final class AppRadius {
  static const double sm = 2; // rounded
  static const double md = 6; // rounded-md (Tailwind default)
  static const double lg = 4; // rounded-lg
  static const double xl = 8; // rounded-xl
  static const double full = 12; // rounded-full (NOT a true pill)

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}

/// Shadows used by the designs.
abstract final class AppShadows {
  /// Tailwind `shadow-sm`: 0 1px 2px rgba(0,0,0,0.05).
  static const sm = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// Fixed top header: 0 1px 8px rgba(0,0,0,0.04).
  static const header = [
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 8),
  ];

  /// Fixed bottom navigation: 0 -2px 12px rgba(0,0,0,0.04).
  static const bottomNav = [
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, -2), blurRadius: 12),
  ];
}

/// Fixed component sizes that recur across screens.
abstract final class AppSizes {
  static const double controlHeight = 48; // h-12 inputs & buttons
  static const double headerHeight = 56; // h-14
  static const double bottomNavHeight = 64; // h-16
  static const double touchTarget = 44; // w-11 h-11 icon buttons
  static const double iconMd = 20;
  static const double iconLg = 24;
}

/// Unified Dimens alias for padding and radius
abstract final class AppDimens {
  static const double paddingXs = AppSpacing.xs;
  static const double paddingSm = AppSpacing.sm;
  static const double paddingMd = AppSpacing.md;
  static const double paddingLg = AppSpacing.lg;
  static const double paddingXl = AppSpacing.xl;

  static const double radiusSm = AppRadius.sm;
  static const double radiusMd = AppRadius.md;
  static const double radiusLg = AppRadius.lg;
  static const double radiusXl = AppRadius.xl;
  static const double radiusFull = AppRadius.full;
}
