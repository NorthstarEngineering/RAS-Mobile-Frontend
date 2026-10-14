import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _identifierController = TextEditingController(
    text: 'm.alvarez@rms-ops.com',
  );
  bool _isLoading = false;
  String _selectedMethod = 'sms'; // 'sms' or 'email'

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  void _onSendOtp() async {
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Navigate to OTP Screen (AUTH-04)
    context.push('/auth/otp', extra: _identifierController.text);
  }

  @override
  Widget build(BuildContext context) {
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
          'نسيت كلمة المرور',
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
              // Security Authority Badge
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Symbols.lock_reset,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'صلاحيات الأمان',
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Title and Description
              Text('نسيت كلمة المرور', style: AppTypography.headlineLg),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'أدخل رقم الموظف أو بريد العمل المسجل. هنبعتلك كود تأكيد مكون من 6 أرقام (OTP) على جهازك المعتمد.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.secondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Form Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Recovery Identifier field
                    RmsTextField(
                      label: 'رقم الموظف أو بريد العمل',
                      controller: _identifierController,
                      hint: 'مثال: ST-4089 أو name@rms-ops.com',
                      prefixIcon: Symbols.badge,
                      trailing: const Icon(
                        Symbols.check_circle,
                        color: AppColors.success,
                        size: 20,
                        fill: 1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Symbols.info,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'لو مفيش رقم هاتف أو إيميل مسجل لحسابك، يرجى مراجعة المدير التنفيذي (CEO) أو مسؤول النظام.',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 11,
                              color: AppColors.secondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Delivery Method Selection
                    Text(
                      'طريقة استلام رمز التأكيد',
                      style: AppTypography.labelMd,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildChannelOption(
                      id: 'sms',
                      title: 'رسالة نصية قصيرة (SMS)',
                      subtitle: 'إلى رقم الهاتف المنتهي بـ •••• 9821',
                      icon: Symbols.sms,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildChannelOption(
                      id: 'email',
                      title: 'البريد الإلكتروني للعمل',
                      subtitle: 'إلى m.alv***@rms-ops.com',
                      icon: Symbols.mail,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Primary Button
                    RmsPrimaryButton(
                      label: 'إرسال رمز التحقق (OTP)',
                      loadingLabel: 'جاري إرسال الرمز...',
                      icon: Symbols.arrow_back,
                      isLoading: _isLoading,
                      onPressed: _onSendOtp,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Quick Support Box
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.lgAll,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.headset_mic,
                      size: 20,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'تواجه صعوبة في الوصول؟ تواصل مع الدعم الفني الداخلي.',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
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

  Widget _buildChannelOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == id;

    return Material(
      color: isSelected
          ? AppColors.primaryFixed.withValues(alpha: 0.35)
          : AppColors.surfaceContainerLow,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = id),
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryFixed
                      : AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Symbols.radio_button_checked
                    : Symbols.radio_button_unchecked,
                color: isSelected ? AppColors.primary : AppColors.secondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
