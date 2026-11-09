import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type scale from the Stitch config (majority variant used by 45+ screens).
///
/// Font: Cairo. The non-auth Stitch screens declare Inter, which has no
/// Arabic glyphs, so the browser fell back to a system font. Cairo (declared
/// by the AUTH screens) is used everywhere for a consistent Arabic rendering.
///
/// Letter spacing is intentionally 0: Arabic is a cursive script and any
/// tracking breaks glyph joining in Flutter.
abstract final class AppTypography {
  static TextStyle _cairo(double size, double lineHeight, FontWeight weight) =>
      GoogleFonts.cairo(
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        color: AppColors.onSurface,
      );

  /// `headline-lg` — 28 / 34, bold.
  static final headlineLg = _cairo(28, 34, FontWeight.w700);

  /// `headline-sm` — 20 / 26, semibold.
  static final headlineSm = _cairo(20, 26, FontWeight.w600);

  /// `body-md` — 16 / 24, regular.
  static final bodyMd = _cairo(16, 24, FontWeight.w400);

  /// `body-sm` — 14 / 20, regular.
  static final bodySm = _cairo(14, 20, FontWeight.w400);

  /// `label-md` — 15 / 20, semibold.
  static final labelMd = _cairo(15, 20, FontWeight.w600);

  /// `label-sm` — 12 / 16, regular.
  static final labelSm = _cairo(12, 16, FontWeight.w400);

  static TextTheme get textTheme => TextTheme(
    headlineLarge: headlineLg,
    headlineSmall: headlineSm,
    bodyLarge: bodyMd,
    bodyMedium: bodySm,
    labelLarge: labelMd,
    labelSmall: labelSm,
  );
}
