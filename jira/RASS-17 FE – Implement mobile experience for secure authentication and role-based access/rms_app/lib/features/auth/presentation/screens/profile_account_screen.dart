import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/user_session.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class ProfileAccountScreen extends StatelessWidget {
  const ProfileAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated || !state.isAuthenticated) {
          context.go('/login');
        }
      },
      builder: (context, state) {
        final session = state.session;
        final userName = session?.name.isNotEmpty == true ? session!.name : 'المستخدم المعتمد';
        final userRole = session?.role.titleArabic.isNotEmpty == true ? session!.role.titleArabic : 'موظف تشغيلي';
        final userEmail = session?.email.isNotEmpty == true ? session!.email : 'user@rms-ops.com';
        final branchName = session?.branchName.isNotEmpty == true ? session!.branchName : 'الفرع الرئيسي';
        final isCeo = session?.role == StaffRole.ceo;
        final isManager = session?.role == StaffRole.branchManager;
        final securityLevel = isCeo
            ? 'المستوى 5 (إدارة عليا)'
            : (isManager ? 'المستوى 3 (إشراف فرع)' : 'المستوى 1 (تشغيل نقاط البيع)');

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            context.safePop(fallback: '/home');
          },
          child: Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppBar(
              backgroundColor: AppColors.surface.withValues(alpha: 0.9),
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
                onPressed: () => context.safePop(fallback: '/home'),
              ),
            title: Text(
              'الملف الشخصي والحساب',
              style: AppTypography.headlineSm.copyWith(fontSize: 18),
            ),
            actions: [
              IconButton(
                icon: const Icon(Symbols.notifications, color: AppColors.secondary),
                onPressed: () => showRmsNotificationsDialog(context),
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
                          child: const Icon(
                            Symbols.cloud_done,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مزامنة البيانات التشغيلية نشطة',
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'الفرع المتصل: $branchName',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusFull,
                            ),
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
                              child: const Icon(
                                Symbols.person,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          userName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.headlineSm.copyWith(
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Symbols.verified,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    userRole,
                                    style: AppTypography.labelMd.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    branchName,
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF5EA),
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusFull,
                                ),
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
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusLg,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'البريد المؤسسي / المعرف',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.secondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      userEmail,
                                      style: AppTypography.labelMd.copyWith(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
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
                                  borderRadius: BorderRadius.circular(
                                    AppDimens.radiusLg,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'النطاق المصرح به',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.secondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isCeo ? 'كافة الفروع والمستودعات' : branchName,
                                      style: AppTypography.labelMd.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
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
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Symbols.shield,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'مستوى الأمان والتصاريح',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelMd.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppDimens.radiusFull,
                                ),
                              ),
                              child: Text(
                                securityLevel,
                                style: AppTypography.labelSm.copyWith(fontSize: 11),
                              ),
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
                              const Icon(
                                Symbols.security,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'المصادقة وتأمين الجلسة',
                                      style: AppTypography.labelMd.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'جلسة مشفرة ومحمية ببروتوكول الأمان الموحد',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'مُؤمّن بنجاح',
                                style: AppTypography.labelSm.copyWith(
                                  color: const Color(0xFF2E8B2E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                              const Icon(
                                Symbols.devices,
                                color: AppColors.secondary,
                                size: 22,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'حالة الجلسة التشغيلية',
                                      style: AppTypography.labelMd.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'جلسة موثقة نشطة • $branchName',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.secondary,
                                      ),
                                    ),
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
                  Text(
                    'إجراءات الحساب والنظام',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
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
                            child: const Icon(
                              Symbols.lock_reset,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'تغيير كلمة المرور (AUTH-07)',
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'تحديث كلمة المرور ورمز PIN',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                          trailing: const Icon(
                            Symbols.arrow_back_ios_new,
                            size: 16,
                            color: AppColors.secondary,
                          ),
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
                            child: const Icon(
                              Symbols.supervisor_account,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'إدارة حسابات المدير التنفيذي (AUTH-11)',
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            isCeo ? 'تعيين مدراء الفروع ومفاتيح الوصول' : 'مقتصر على المدير التنفيذي (CEO)',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                          trailing: const Icon(
                            Symbols.arrow_back_ios_new,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          onTap: () {
                            if (isCeo) {
                              context.push('/auth/ceo/accounts');
                            } else {
                              context.push('/auth/access-denied');
                            }
                          },
                        ),
                        const Divider(height: 1, color: AppColors.surfaceContainer),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Symbols.lock_clock,
                              color: Color(0xFFC77A00),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'محاكاة انتهاء مدة الجلسة (AUTH-08)',
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'اختبار شاشة القفل التلقائي',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                          trailing: const Icon(
                            Symbols.arrow_back_ios_new,
                            size: 16,
                            color: AppColors.secondary,
                          ),
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
        ),
      );
    },
  );
  }
}
