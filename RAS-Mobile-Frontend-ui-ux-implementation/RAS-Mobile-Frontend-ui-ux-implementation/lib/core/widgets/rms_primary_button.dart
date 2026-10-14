import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// Full-width primary action button (`h-12 bg-primary rounded-lg shadow-sm`).
///
/// While [isLoading] is true the button is disabled and shows a spinner with
/// [loadingLabel] (falls back to [label]).
class RmsPrimaryButton extends StatelessWidget {
  const RmsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.mirrorIcon = false,
    this.isLoading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Flips [icon] horizontally (designs use `scale-x-[-1]` for some RTL icons).
  final bool mirrorIcon;
  final bool isLoading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.controlHeight,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: ButtonStyle(
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
            ),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.primary.withValues(
                  alpha: isLoading ? 0.85 : 0.4,
                );
              }
              if (states.contains(WidgetState.hovered)) {
                return AppColors.primaryContainer;
              }
              return AppColors.primary;
            }),
            foregroundColor: const WidgetStatePropertyAll(AppColors.onPrimary),
            textStyle: WidgetStatePropertyAll(AppTypography.labelMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              else if (icon != null)
                Transform.flip(
                  flipX: mirrorIcon,
                  child: Icon(
                    icon,
                    size: AppSizes.iconMd,
                    color: AppColors.onPrimary,
                  ),
                ),
              if (isLoading || icon != null)
                const SizedBox(width: AppSpacing.sm),
              Text(isLoading ? (loadingLabel ?? label) : label),
            ],
          ),
        ),
      ),
    );
  }
}
