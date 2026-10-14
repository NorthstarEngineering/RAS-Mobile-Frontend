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
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() => context.read<AuthBloc>().add(LoginSubmitted(
        identifier: _identifierController.text,
        password: _passwordController.text,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (!state.isAuthenticated) return;
            final session = state.session!;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('مرحباً بك، ${session.name} (${session.role.titleArabic})'),
              backgroundColor: AppColors.success,
            ));
            context.go(session.mustChangePassword
                ? '/auth/change-password?required=1'
                : '/home');
          },
          builder: (context, state) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.margin,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: AppRadius.lgAll,
                    ),
                    alignment: Alignment.center,
                    child: const Text('R', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26,
                    )),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('RMS TERMINAL', style: AppTypography.headlineSm),
                ]),
                const SizedBox(height: AppSpacing.xl),
                Text('تسجيل الدخول للنظام', style: AppTypography.headlineLg),
                const SizedBox(height: AppSpacing.xs),
                Text('أدخل البريد الإلكتروني وكلمة المرور المعتمدين.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.secondary)),
                const SizedBox(height: AppSpacing.lg),
                const RmsBanner(
                  icon: Symbols.shield_lock,
                  title: 'سياسة نقطة البيع',
                  message: 'للموظفين المصرح لهم فقط. تُسجل محاولات الدخول وتخضع للصلاحيات المعتمدة.',
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  RmsBanner(
                    icon: Symbols.error,
                    tone: RmsBannerTone.error,
                    message: state.errorMessage!,
                    onClose: () => context.read<AuthBloc>().add(const ClearAuthError()),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                RmsTextField(
                  label: 'البريد الإلكتروني',
                  controller: _identifierController,
                  hint: 'name@example.com',
                  prefixIcon: Symbols.badge,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                RmsTextField(
                  label: 'كلمة المرور',
                  controller: _passwordController,
                  hint: '••••••••••••',
                  prefixIcon: Symbols.lock,
                  isPassword: true,
                  trailing: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('استعادة كلمة المرور غير متاحة من الخادم الحالي. تواصل مع المدير التنفيذي.')),
                    ),
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                RmsPrimaryButton(
                  label: 'تسجيل الدخول للجهاز',
                  loadingLabel: 'جاري التحقق من الصلاحيات...',
                  icon: Symbols.login,
                  isLoading: state.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(child: Text(
                  'اتصال بخدمات المؤسسة • الإعداد من بيئة التشغيل',
                  style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
                  textAlign: TextAlign.center,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
