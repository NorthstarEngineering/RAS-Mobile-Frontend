import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/overtime_record.dart';

class OvertimeReviewScreen extends StatefulWidget {
  const OvertimeReviewScreen({
    super.key,
    required this.record,
  });

  final OvertimeRecord record;

  @override
  State<OvertimeReviewScreen> createState() => _OvertimeReviewScreenState();
}

class _OvertimeReviewScreenState extends State<OvertimeReviewScreen> {
  bool _isLoading = false;

  void _onApprove() async {
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم اعتماد الساعات الإضافية وترحيلها لمستحقات الراتب بنجاح (OT-04).'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
  }

  void _onReject() async {
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم رفض طلب الساعات الإضافية وإخطار الموظف.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
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
          'مراجعة واعتماد الساعات (OT-03)',
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
              // Employee Profile Card
              RmsCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryFixed,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.record.initials,
                        style: AppTypography.headlineSm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimaryFixedVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.record.employeeName,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${widget.record.role} (#${widget.record.employeeCode})',
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
              const SizedBox(height: AppSpacing.md),

              // Overtime Breakdown Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const RmsSectionHeader(
                      icon: Symbols.more_time,
                      title: 'تفاصيل الساعات الإضافية',
                      trailing: RmsChip(
                        label: 'بصمة بيومترية',
                        tone: RmsChipTone.primarySoft,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailBox(
                            'عدد الساعات',
                            '${widget.record.hours.toStringAsFixed(0)} ساعات',
                            Symbols.timelapse,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _buildDetailBox(
                            'المستحق المالي',
                            '+${widget.record.overtimePay.toStringAsFixed(0)} ج.م',
                            Symbols.payments,
                            valueColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildDetailBox(
                      'الفترة الزمنية',
                      '${widget.record.date} • ${widget.record.timeRange}',
                      Symbols.calendar_today,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'مبرر العمل الإضافي المسجل:',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: Text(
                        widget.record.reason,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Approve Button (OT-04)
              RmsPrimaryButton(
                label: 'اعتماد الساعات الإضافية (OT-04)',
                loadingLabel: 'جاري الاعتماد...',
                icon: Symbols.check,
                isLoading: _isLoading,
                onPressed: _onApprove,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Reject Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.controlHeight),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.lgAll,
                  ),
                  side: const BorderSide(color: AppColors.errorContainer),
                  foregroundColor: AppColors.error,
                ),
                icon: const Icon(Symbols.close, size: 20),
                label: Text(
                  'رفض الطلب وإلغاء الاستحقاق',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _isLoading ? null : _onReject,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailBox(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.secondary),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
