import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_typography.dart';

enum RmsBannerTone {
  /// `bg-primary-fixed/40` with primary icon/title (policy / notice banners).
  notice(
    background: Color(0x66FFDBD0),
    iconColor: AppColors.primary,
    titleColor: AppColors.primary,
    messageColor: AppColors.onSurfaceVariant,
  ),

  /// `bg-error-container` (validation / failure alerts).
  error(
    background: AppColors.errorContainer,
    iconColor: AppColors.error,
    titleColor: AppColors.onErrorContainer,
    messageColor: AppColors.onErrorContainer,
  ),

  /// Emerald success alerts.
  success(
    background: AppColors.successContainer,
    iconColor: AppColors.success,
    titleColor: AppColors.onSuccessContainer,
    messageColor: AppColors.onSuccessContainer,
  );

  const RmsBannerTone({
    required this.background,
    required this.iconColor,
    required this.titleColor,
    required this.messageColor,
  });

  final Color background;
  final Color iconColor;
  final Color titleColor;
  final Color messageColor;
}

/// Inline alert/notice banner (`p-3 rounded-lg flex gap-2`).
///
/// With a [title] it renders the two-line notice layout; without one it
/// renders the compact single-line alert. [emphasis] is appended to
/// [message] in semibold. Passing [onClose] shows a dismiss button.
class RmsBanner extends StatelessWidget {
  const RmsBanner({
    super.key,
    required this.icon,
    required this.message,
    this.tone = RmsBannerTone.notice,
    this.title,
    this.emphasis,
    this.onClose,
  });

  final IconData icon;
  final String message;
  final RmsBannerTone tone;
  final String? title;
  final String? emphasis;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        crossAxisAlignment:
            hasTitle ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: hasTitle ? 2 : 0),
            child: Icon(icon, size: AppSizes.iconMd, color: tone.iconColor, fill: 1),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: hasTitle ? _titledContent() : _inlineContent()),
          if (onClose != null)
            IconButton(
              tooltip: 'إغلاق التنبيه',
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Symbols.close,
                size: 18,
                color: tone.messageColor.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  Widget _titledContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title!,
          style: AppTypography.labelMd.copyWith(
            color: tone.titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          message,
          style: AppTypography.labelSm.copyWith(color: tone.messageColor),
        ),
      ],
    );
  }

  Widget _inlineContent() {
    final style = AppTypography.bodySm.copyWith(color: tone.messageColor);
    return Text.rich(
      TextSpan(
        text: message,
        children: [
          if (emphasis != null)
            TextSpan(
              text: ' $emphasis',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
