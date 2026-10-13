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
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController =
      TextEditingController(text: 'm.alvarez@rms-ops.com');
  final _passwordController =
      TextEditingController(text: 'SuperSecretOps2024!');

  @override
  void dispose() {
    _identifierController.dispose;
    _passwordController.dispose();
    super.dispose();
  }

  void _onPresetSelected(String identifier) {
    setState(() {
      _identifierController.text = identifier;
    });
  }

  void _onSubmit() {
    context.read<AuthBloc>().add(
          LoginSubmitted(
            identifier: _identifierController.text,
            password: _passwordController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state.isAuthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('مرحباً بك، ${state.session!.name} (${state.session!.role.titleArabic})'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              context.go('/home');
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Brand & Terminal Context Bar
                  _buildBrandBar(),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Operational Header
                  Text(
                    'تسجيل الدخول للنظام',
                    style: AppTypography.headlineLg,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'أدخل بيانات الموظف المعتمدة للوصول إلى نقطة البيع.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 3. Operational Policy Warning Banner
                  const RmsBanner(
                    icon: Symbols.shield_lock,
                    title: 'سياسة نقطة البيع',
                    message:
                        'للموظفين المصرح لهم فقط. يتم تسجيل ومراقبة جميع محاولات الدخول والورديات.',
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 4. In-Context Validation Alert (if error)
                  if (state.errorMessage != null) ...[
                    RmsBanner(
                      icon: Symbols.error,
                      tone: RmsBannerTone.error,
                      message: state.errorMessage!,
                      onClose: () {
                        context.read<AuthBloc>().add(const ClearAuthError());
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 5. Staff Identifier Field
                  RmsTextField(
                    label: 'رقم الموظف أو البريد الإلكتروني',
                    controller: _identifierController,
                    hint: 'm.alvarez@rms-ops.com',
                    prefixIcon: Symbols.badge,
                    keyboardType: TextInputType.emailAddress,
                    trailing: Text(
                      'إصدار الجهاز v4.12',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 6. Password Field
                  RmsTextField(
                    label: 'كلمة المرور',
                    controller: _passwordController,
                    hint: '••••••••••••',
                    prefixIcon: Symbols.lock,
                    isPassword: true,
                    trailing: TextButton(
                      onPressed: () => context.push('/auth/forgot-password'),
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 7. Quick Preset Switchers
                  _buildPresetsSection(),
                  const SizedBox(height: AppSpacing.lg),

                  // 8. Primary Action Button
                  RmsPrimaryButton(
                    label: 'تسجيل الدخول للجهاز',
                    loadingLabel: 'جاري التحقق من الصلاحيات...',
                    icon: Symbols.login,
                    mirrorIcon: true,
                    isLoading: state.isLoading,
                    onPressed: _onSubmit,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 9. Physical RFID / NFC Card Quick Assist
                  _buildNfcQuickAssist(),
                  const SizedBox(height: AppSpacing.xl),

                  // 10. Bottom Hardware & Location Terminal Metadata
                  _buildTerminalFooter(),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand Logo
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'R',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                text: 'RMS',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(
                    text: 'OPS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // POS Connection Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: AppRadius.fullAll,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'نقطة البيع متصلة',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'اختيار سريع تجريبي',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildPresetButton(
                  name: 'م. ألفاريز',
                  role: 'مسؤول وردية',
                  email: 'm.alvarez@rms-ops.com',
                  icon: Symbols.dinner_dining,
                  iconBg: AppColors.primaryFixed,
                  iconColor: AppColors.onPrimaryFixed,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildPresetButton(
                  name: 'ج. ميلر',
                  role: 'مدير فرع',
                  email: 'j.miller@rms-ops.com',
                  icon: Symbols.storefront,
                  iconBg: AppColors.tertiaryFixed,
                  iconColor: AppColors.onTertiaryFixed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String name,
    required String role,
    required String email,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    final isSelected = _identifierController.text == email;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: const BorderRadius.all(Radius.circular(6)),
      child: InkWell(
        onTap: () => _onPresetSelected(email),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      role,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNfcQuickAssist() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Symbols.nfc, size: 20, color: AppColors.secondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'بطاقة الموظف / شارة المدير جاهزة',
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: Text(
              'مرّر الكارت',
              style: AppTypography.labelSm.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.point_of_sale, size: 16, color: AppColors.secondary),
            const SizedBox(width: 6),
            Text(
              'نقطة بيع: الفرع الرئيسي - وسط البلد (#104)',
              style: AppTypography.labelSm.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'نظام تشغيل RMS v2.10.4 • مزامنة فورية',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.secondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
