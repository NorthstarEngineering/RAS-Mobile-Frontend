import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';

/// Dev-only gallery for visually checking the design system against the
/// Stitch screens. Remove once real features replace it.
class DesignSystemPreviewScreen extends StatefulWidget {
  const DesignSystemPreviewScreen({super.key});

  @override
  State<DesignSystemPreviewScreen> createState() =>
      _DesignSystemPreviewScreenState();
}

class _DesignSystemPreviewScreenState extends State<DesignSystemPreviewScreen> {
  bool _isLoading = false;
  bool _showError = true;

  Future<void> _simulateSubmit() async {
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _showError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.md,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            Text('نظام التصميم', style: AppTypography.headlineLg),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'معاينة المكونات المشتركة لتطبيق RMS.',
              style: AppTypography.bodySm.copyWith(color: AppColors.secondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            const RmsBanner(
              icon: Symbols.shield_lock,
              title: 'سياسة نقطة البيع',
              message:
                  'للموظفين المصرح لهم فقط. يتم تسجيل ومراقبة جميع محاولات الدخول والورديات.',
            ),
            if (_showError) ...[
              const SizedBox(height: AppSpacing.lg),
              RmsBanner(
                icon: Symbols.error,
                tone: RmsBannerTone.error,
                message: 'بيانات غير صحيحة.',
                emphasis: 'متبقي محاولتان (2).',
                onClose: () => setState(() => _showError = false),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            const RmsTextField(
              label: 'رقم الموظف أو البريد الإلكتروني',
              hint: 'm.alvarez@rms-ops.com',
              prefixIcon: Symbols.badge,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.lg),
            RmsTextField(
              label: 'كلمة المرور',
              hint: '••••••••••••',
              prefixIcon: Symbols.lock,
              isPassword: true,
              trailing: TextButton(
                onPressed: () {},
                child: const Text('نسيت كلمة المرور؟'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            RmsPrimaryButton(
              label: 'تسجيل الدخول للجهاز',
              loadingLabel: 'جاري التحقق من الصلاحيات...',
              icon: Symbols.login,
              mirrorIcon: true,
              isLoading: _isLoading,
              onPressed: _simulateSubmit,
            ),
            const SizedBox(height: AppSpacing.xl),
            RmsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RmsSectionHeader(
                    icon: Symbols.payments,
                    title: 'إجمالي المبيعات الشاملة',
                    trailing: RmsChip(
                      label: '+8.2%',
                      icon: Symbols.trending_up,
                      tone: RmsChipTone.success,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('184,500 ج.م', style: AppTypography.headlineLg),
                  const SizedBox(height: AppSpacing.md),
                  const Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      RmsChip(label: 'مباشر', icon: Symbols.sync),
                      RmsChip(label: '9', tone: RmsChipTone.primary),
                      RmsChip(label: 'قيد المراجعة', tone: RmsChipTone.warning),
                      RmsChip(label: 'مرفوض', tone: RmsChipTone.error),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
