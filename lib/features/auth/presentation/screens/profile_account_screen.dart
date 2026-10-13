import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

class ProfileAccountScreen extends StatelessWidget {
  const ProfileAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'الملف الشخصي والحساب',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.notifications, color: AppColors.secondary),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.margin,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Auto-sync status banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Symbols.cloud_done, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('مزامنة البيانات التشغيلية نشطة', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                          Text('آخر تحديث لنقاط البيع: منذ دقيقتين', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                      ),
                      child: Text(
                        'مباشر',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // User Identity Card
              RmsCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Symbols.person, size: 36, color: Colors.white),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'م. ألفريد إدوارد',
                                    style: AppTypography.headlineSm.copyWith(fontSize: 18),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Symbols.verified, size: 18, color: AppColors.primary),
                                ],
                              ),
                              Text(
                                'الرئيس التنفيذي (CEO)',
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'المسؤول العام عن العمليات والفروع',
                                style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EA),
                            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          ),
                          child: Text(
                            'نشط وموثق',
                            style: AppTypography.labelSm.copyWith(
                              color: const Color(0xFF2E8B2E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1, color: AppColors.surfaceContainer),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('البريد المؤسسي', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text('ceo@rms-ops.com', style: AppTypography.labelMd.copyWith(fontFamily: 'monospace', fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('النطاق المصرح به', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text('كافة الفروع والمستودعات', style: AppTypography.labelMd.copyWith(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Security & Authority Insights Module
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Symbols.shield, color: AppColors.primary, size: 20),
                            const SizedBox(width: 6),
                            Text('مستوى الأمان والتصاريح', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                          ),
                          child: Text('المستوى 5 (كامل)', style: AppTypography.labelSm.copyWith(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // 2FA status
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                      child: Row(
                        children: [
                          const Icon(Symbols.security, color: AppColors.primary, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('المصادقة الثنائية (2FA)', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                                Text('مفتاح أمان عتادي ومصادقة سحابية', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                              ],
                            ),
                          ),
                          Text('مُفعّل بالكامل', style: AppTypography.labelSm.copyWith(color: const Color(0xFF2E8B2E), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Session status
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      ),
                      child: Row(
                        children: [
                          const Icon(Symbols.devices, color: AppColors.secondary, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('آخر جلسة تشغيلية', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                                Text('اليوم 11:42 ص • محطة POS المحمولة #104', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                              ],
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Operational Actions
              Text('إجراءات الحساب والنظام', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.secondary)),
              const SizedBox(height: 6),
              RmsCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Symbols.lock_reset, color: AppColors.primary, size: 20),
                      ),
                      title: Text('تغيير كلمة المرور (AUTH-07)', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text('تحديث كلمة المرور ورمز PIN', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                      trailing: const Icon(Symbols.arrow_back_ios_new, size: 16, color: AppColors.secondary),
                      onTap: () => context.push('/auth/change-password'),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceContainer),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Symbols.supervisor_account, color: AppColors.primary, size: 20),
                      ),
                      title: Text('إدارة حسابات المدير التنفيذي (AUTH-11)', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text('تعيين مدراء الفروع ومفاتيح الوصول', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                      trailing: const Icon(Symbols.arrow_back_ios_new, size: 16, color: AppColors.secondary),
                      onTap: () => context.push('/auth/ceo/accounts'),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceContainer),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Symbols.lock_clock, color: Color(0xFFC77A00), size: 20),
                      ),
                      title: Text('محاكاة انتهاء مدة الجلسة (AUTH-08)', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text('اختبار شاشة القفل التلقائي', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                      trailing: const Icon(Symbols.arrow_back_ios_new, size: 16, color: AppColors.secondary),
                      onTap: () => context.push('/auth/session-expired'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Logout Button
              ElevatedButton.icon(
                onPressed: () {
                  context.read<AuthBloc>().add(const LogoutRequested());
                  context.go('/login');
                },
                icon: const Icon(Symbols.logout),
                label: const Text('تسجيل الخروج من النظام'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
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
      ),
    );
  }
}
