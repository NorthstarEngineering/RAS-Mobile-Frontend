import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Wraps mobile screens on Web/Desktop into a centered phone-sized viewport
/// (~430px) with subtle elevation and background contrast, while expanding
/// to native full-screen on mobile devices.
class MobileViewport extends StatelessWidget {
  const MobileViewport({super.key, required this.child, this.maxWidth = 430.0});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) {
          return child;
        }

        return Container(
          color: const Color(
            0xFF1E1E24,
          ), // Sleek studio dark backdrop for desktop
          alignment: Alignment.center,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRect(child: child),
          ),
        );
      },
    );
  }
}
