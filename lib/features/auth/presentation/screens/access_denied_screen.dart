import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('غير مصرح بالدخول'),
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(AppDimens.radiusFull),
            ),
            child: Text(
              'HTTP 403',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onErrorContainer,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppDimens.paddingLg),

            // Red Restricted Shield Icon
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 38,
                      color: AppColors.error,
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 16,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Title and Description
            Text(
              'الدخول محظور',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ليس لديك صلاحية لعرض هذا القسم. تتطلب هذه الشاشة صلاحيات المدير التنفيذي (CEO) أو مسؤول النظام العام.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.secondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppDimens.paddingLg),

            // Security Audit Trace Box
            Container(
              padding: const EdgeInsets.all(AppDimens.paddingLg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'تتبع سجل التدقيق والأمان',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                        ),
                        child: Text(
                          'مسار مؤمّن',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onErrorContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildTraceItem(
                    'الدور الحالي للحساب',
                    'مسؤول وردية (Shift Supervisor)',
                  ),
                  const SizedBox(height: 8),
                  _buildTraceItem(
                    'الصلاحية المطلوبة',
                    'المدير التنفيذي (role:exec_ceo)',
                  ),
                  const SizedBox(height: 8),
                  _buildTraceItem(
                    'القسم المستهدف',
                    '/admin/financial/executive-dashboard',
                  ),
                  const SizedBox(height: 8),
                  _buildTraceItem(
                    'معرّف الحادثة الأمني',
                    'SEC-403-894102',
                    isMonospace: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingXl),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('العودة للرئيسية المعتمدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال طلب الصلاحية للإدارة التنفيذية'),
                  ),
                );
              },
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('طلب ترقية الصلاحيات'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTraceItem(
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.secondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodySm.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}
