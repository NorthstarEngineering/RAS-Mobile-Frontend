import 'package:flutter/material.dart';

/// Color tokens extracted from the Stitch `tailwind.config` shared by all
/// RMS screens. Names mirror the Tailwind token names so designs and code
/// can be cross-referenced 1:1.
abstract final class AppColors {
  // Brand (logo mark only — UI actions use [primary]).
  static const brand = Color(0xFFFF4C00);

  // Primary
  static const primary = Color(0xFFAA3000);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFD53E00);
  static const onPrimaryContainer = Color(0xFFFFFBFF);
  static const primaryFixed = Color(0xFFFFDBD0);
  static const primaryFixedDim = Color(0xFFFFB59F);
  static const onPrimaryFixed = Color(0xFF3A0A00);
  static const onPrimaryFixedVariant = Color(0xFF852400);
  static const inversePrimary = Color(0xFFFFB59F);
  static const surfaceTint = Color(0xFFAE3100);

  // Secondary
  static const secondary = Color(0xFF5D5E5F);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFE2E2E2);
  static const onSecondaryContainer = Color(0xFF636465);
  static const onSecondaryFixedVariant = Color(0xFF454747);

  // Tertiary
  static const tertiary = Color(0xFF005DA8);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF0076D3);
  static const onTertiaryContainer = Color(0xFFFDFCFF);
  static const tertiaryFixed = Color(0xFFD4E3FF);
  static const tertiaryFixedDim = Color(0xFFA4C9FF);
  static const onTertiaryFixed = Color(0xFF001C39);
  static const onTertiaryFixedVariant = Color(0xFF004884);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Surfaces
  static const surface = Color(0xFFFAF9FD);
  static const onSurface = Color(0xFF1A1B1E);
  static const onSurfaceVariant = Color(0xFF5C4037);
  static const surfaceDim = Color(0xFFDBD9DD);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF4F3F7);
  static const surfaceContainer = Color(0xFFEFEDF1);
  static const surfaceContainerHigh = Color(0xFFE9E7EB);
  static const surfaceContainerHighest = Color(0xFFE3E2E6);
  static const inverseSurface = Color(0xFF2F3033);
  static const inverseOnSurface = Color(0xFFF1F0F4);

  // Outline
  static const outline = Color(0xFF916F66);
  static const outlineVariant = Color(0xFFE6BEB2);

  // Status colors — Tailwind defaults used across screens for
  // success / warning / danger states (emerald, amber, rose).
  static const success = Color(0xFF047857); // emerald-700
  static const successStrong = Color(0xFF059669); // emerald-600
  static const successContainer = Color(0xFFECFDF5); // emerald-50
  static const onSuccessContainer = Color(0xFF065F46); // emerald-800
  static const warning = Color(0xFFB45309); // amber-700
  static const warningContainer = Color(0xFFFEF3C7); // amber-100
  static const onWarningContainer = Color(0xFF78350F); // amber-900
  static const danger = Color(0xFFBE123C); // rose-700
  static const dangerContainer = Color(0xFFFFE4E6); // rose-100
}
