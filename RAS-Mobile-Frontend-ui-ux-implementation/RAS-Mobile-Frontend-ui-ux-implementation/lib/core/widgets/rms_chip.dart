import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

enum RmsChipTone {
  neutral(AppColors.surfaceContainer, AppColors.onSurfaceVariant),
  primary(AppColors.primary, AppColors.onPrimary),
  primarySoft(AppColors.primaryFixed, AppColors.onPrimaryFixedVariant),
  success(AppColors.successContainer, AppColors.success),
  warning(AppColors.warningContainer, AppColors.warning),
  error(AppColors.errorContainer, AppColors.error);

  const RmsChipTone(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

/// Small status chip/badge (`px-2.5 py-0.5 rounded-full text-label-sm`).
class RmsChip extends StatelessWidget {
  const RmsChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = RmsChipTone.neutral,
  });

  final String label;
  final IconData? icon;
  final RmsChipTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone.foreground),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: AppTypography.labelSm.copyWith(color: tone.foreground),
          ),
        ],
      ),
    );
  }
}
