import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/http_auth_repository.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.identifier = '',
    this.resetToken = '',
  });

  final String identifier;
  final String resetToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final HttpAuthRepository _authRepository;

  bool _isLoading = false;
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    if (sl.isRegistered<HttpAuthRepository>()) {
      _authRepository = sl<HttpAuthRepository>();
    } else if (sl.isRegistered<AuthRepository>() &&
        sl<AuthRepository>() is HttpAuthRepository) {
      _authRepository = sl<AuthRepository>() as HttpAuthRepository;
    } else {
      _authRepository = HttpAuthRepository(
        apiClient: sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null,
      );
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _hasMinLength = value.length >= 8;
      _hasNumber = RegExp(r'[0-9]').hasMatch(value);
      _hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value);
    });
  }

  void _onSubmit() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمات المرور غير متطابقة'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور يجب أن لا تقل عن 6 أحرف'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authRepository.resetPassword(
        identifier: widget.identifier,
        resetToken: widget.resetToken,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Route to Success Screen (AUTH-06) passing dynamic account and timestamp
      context.pushReplacement(
        '/auth/success',
        extra: {
          'identifier': widget.identifier,
          'timestamp': DateTime.now().toLocal().toString().substring(0, 16),
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString().replaceAll('Exception: ', '').replaceAll('NetworkException: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isNotEmpty ? msg : 'تعذر إعادة تعيين كلمة المرور'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _hasMinLength && _hasNumber;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_forward, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'إعادة تعيين كلمة المرور',
          style: AppTypography.headlineSm.copyWith(fontSize: 18),
        ),
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
              // Secondary Context Bar / Step
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الخطوة 3 من 3',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: AppRadius.fullAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Symbols.lock_reset,
                          size: 14,
                          color: AppColors.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'تأمين الحساب',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Header
              Text('إنشاء كلمة مرور جديدة', style: AppTypography.headlineLg),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'اختر كلمة مرور قوية متوافقة مع معايير أمان التشغيل لنظام RMS.',
                style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Operational Alert Banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.xlAll,
                  boxShadow: AppShadows.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Symbols.security,
                        size: 20,
                        color: AppColors.primary,
                        fill: 1,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سياسة نقاط البيع بالمطعم',
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'حماية دفاتر الوردية الحساسة، أقفال الأدراج، وخصومات المديرين.',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Form
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RmsTextField(
                      label: 'كلمة المرور الجديدة',
                      controller: _newPasswordController,
                      hint: '••••••••••••',
                      prefixIcon: Symbols.lock,
                      isPassword: true,
                      onChanged: _onPasswordChanged,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isValid
                              ? AppColors.tertiaryFixed
                              : AppColors.surfaceContainer,
                          borderRadius: AppRadius.fullAll,
                        ),
                        child: Text(
                          isValid ? 'قوية' : 'متوسطة',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isValid
                                ? AppColors.tertiary
                                : AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    RmsTextField(
                      label: 'تأكيد كلمة المرور الجديدة',
                      controller: _confirmPasswordController,
                      hint: '••••••••••••',
                      prefixIcon: Symbols.lock_clock,
                      isPassword: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Password rules indicators
                    Text(
                      'متطلبات كلمة المرور:',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildRuleItem('8 أحرف على الأقل', _hasMinLength),
                    const SizedBox(height: 4),
                    _buildRuleItem('تحتوي على أرقام (0-9)', _hasNumber),
                    const SizedBox(height: 4),
                    _buildRuleItem('تحتوي على رموز خاصة (!@#\$%)', _hasSpecial),
                    const SizedBox(height: AppSpacing.xl),

                    RmsPrimaryButton(
                      label: 'تحديث كلمة المرور والمتابعة',
                      loadingLabel: 'جاري حفظ كلمة المرور...',
                      icon: Symbols.check,
                      isLoading: _isLoading,
                      onPressed: isValid ? _onSubmit : null,
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

  Widget _buildRuleItem(String text, bool met) {
    return Row(
      children: [
        Icon(
          met ? Symbols.check_circle : Symbols.radio_button_unchecked,
          size: 16,
          color: met ? AppColors.success : AppColors.secondary,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTypography.labelSm.copyWith(
            color: met ? AppColors.onSurface : AppColors.secondary,
            fontWeight: met ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
