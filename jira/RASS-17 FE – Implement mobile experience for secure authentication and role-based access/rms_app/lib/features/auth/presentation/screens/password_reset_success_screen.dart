import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

class PasswordResetSuccessScreen extends StatelessWidget {
  const PasswordResetSuccessScreen({
    super.key,
    this.identifier = '',
    this.timestamp = '',
  });

  final String identifier;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final accountText = identifier.isNotEmpty ? identifier : 'الحساب المعتمد';
    final timeText = timestamp.isNotEmpty ? timestamp : 'اليوم، تم التحديث الآن';
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.margin,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Success Icon & Message
              Column(
                children: [
                  const SizedBox(height: 32),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Symbols.check,
                      size: 32,
                      color: AppColors.success,
                      weight: 700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'تم تحديث كلمة المرور بنجاح',
                    style: AppTypography.headlineLg,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'تم إعادة تعيين كلمة المرور الخاصة بك بأمان. تم إبطال جميع الجلسات النشطة على الأجهزة ونقاط البيع الأخرى.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.secondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Session Details Card
                  RmsCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        _buildRow(
                          'الحساب',
                          accountText,
                          isLtr: true,
                        ),
                        const Divider(
                          height: 16,
                          color: AppColors.surfaceContainer,
                        ),
                        _buildRow('وقت التحديث', timeText),
                        const Divider(
                          height: 16,
                          color: AppColors.surfaceContainer,
                        ),
                        _buildRow('الجهاز', 'نقطة بيع محمولة #104'),
                        const Divider(
                          height: 16,
                          color: AppColors.surfaceContainer,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الحالة',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F5E9),
                                borderRadius: AppRadius.fullAll,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2E8B2E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'نشط ومؤمّن',
                                    style: AppTypography.labelSm.copyWith(
                                      color: const Color(0xFF2E8B2E),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bottom Actions
              Column(
                children: [
                  RmsPrimaryButton(
                    label: 'المتابعة لتسجيل الدخول',
                    icon: Symbols.arrow_back,
                    onPressed: () => context.go('/login'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Symbols.support_agent,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'هل تحتاج لمساعدة؟ مركز المساعدة متاح 24/7',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isLtr = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: isLtr ? TextAlign.left : TextAlign.start,
            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w600),
            textDirection: isLtr ? TextDirection.ltr : null,
          ),
        ),
      ],
    );
  }
}
