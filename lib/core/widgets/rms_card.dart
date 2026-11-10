import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

/// White content card (`bg-surface-container-lowest rounded-xl shadow-sm`).
class RmsCard extends StatelessWidget {
  const RmsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.xlAll,
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );
  }
}

/// Card header row: primary icon + title, with an optional [trailing] widget
/// (badge, count, "عرض السجل" link...).
class RmsSectionHeader extends StatelessWidget {
  const RmsSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(title, style: AppTypography.labelMd)),
        ?trailing,
      ],
    );
  }
}
