import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/routing/navigation_utils.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../../../core/di/service_locator.dart';

class DeductionAdjustmentScreen extends StatefulWidget {
  const DeductionAdjustmentScreen({super.key, required this.record});

  final AttendanceRecord record;

  @override
  State<DeductionAdjustmentScreen> createState() =>
      _DeductionAdjustmentScreenState();
}

class _DeductionAdjustmentScreenState extends State<DeductionAdjustmentScreen> {
  late final TextEditingController _amountController;
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String _presetReason = 'traffic'; // traffic, medical, official

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.record.deductionAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onExcuse() {
    setState(() {
      _amountController.text = '0';
    });
  }

  void _onHalf() {
    setState(() {
      final half = widget.record.deductionAmount / 2;
      _amountController.text = half.toStringAsFixed(0);
    });
  }

  void _onSave() async {
    setState(() => _isLoading = true);
    try {
      final deductionAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final reasonText = _reasonController.text.trim().isNotEmpty
          ? _reasonController.text.trim()
          : (_presetReason == 'traffic'
              ? 'عذر مروري وازدحام طرق معتمد'
              : (_presetReason == 'medical'
                  ? 'عذر طبي طارئ'
                  : 'مأمورية عمل رسمية بتكليف مسبق'));
      final waivedMins = deductionAmount <= 0.0
          ? widget.record.delayMinutes
          : (deductionAmount < widget.record.deductionAmount
              ? (widget.record.delayMinutes / 2).round()
              : 0);

      await sl<AttendanceRepository>().adjustDeduction(
        attendanceId: widget.record.id,
        deductionAmount: deductionAmount,
        reason: reasonText,
        waivedMinutes: waivedMins,
        originalLateMinutes: widget.record.delayMinutes,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اعتماد تعديل الخصم الإداري وتحديث كشف الراتب.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل اعتماد تعديل الخصم الإداري: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          onPressed: () => context.safePop(fallback: '/attendance'),
        ),
        title: Text(
          'تعديل الخصم الإداري (ATT-03)',
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
              // Employee Info Summary Card
              RmsCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.warningContainer,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Symbols.schedule,
                            color: AppColors.warning,
                            size: 24,
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
                    const SizedBox(height: AppSpacing.md),
                    const Divider(height: 1, color: AppColors.surfaceContainer),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مدة التأخير المسجلة',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                '${widget.record.delayMinutes} دقيقة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'الخصم التلقائي المحسوب',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                '${widget.record.deductionAmount.toStringAsFixed(0)} ج.م',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
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
              const SizedBox(height: AppSpacing.lg),

              // Quick Actions Box
              Text('الإجراءات الإدارية السريعة', style: AppTypography.labelMd),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onExcuse,
                      icon: const Icon(Symbols.verified, size: 18),
                      label: const Text('إعفاء تام (0 ج.م)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onHalf,
                      icon: const Icon(Symbols.percent, size: 18),
                      label: const Text('خصم النصف'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Adjustment Form Card
              RmsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RmsTextField(
                      label: 'قيمة الخصم المعدلة النهائية (ج.م)',
                      controller: _amountController,
                      prefixIcon: Symbols.payments,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text('سبب التعديل الإداري', style: AppTypography.labelMd),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        ChoiceChip(
                          label: const Text('عطل مواصلات عامة'),
                          selected: _presetReason == 'traffic',
                          onSelected: (_) =>
                              setState(() => _presetReason = 'traffic'),
                        ),
                        ChoiceChip(
                          label: const Text('ظرف طبي طارئ'),
                          selected: _presetReason == 'medical',
                          onSelected: (_) =>
                              setState(() => _presetReason = 'medical'),
                        ),
                        ChoiceChip(
                          label: const Text('تكليف إداري خارجي'),
                          selected: _presetReason == 'official',
                          onSelected: (_) =>
                              setState(() => _presetReason = 'official'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    RmsTextField(
                      label: 'ملاحظات إضافية للمدير',
                      controller: _reasonController,
                      hint: 'اكتب تفاصيل التوجيه الإداري...',
                      prefixIcon: Symbols.notes,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    RmsPrimaryButton(
                      label: 'اعتماد تعديل الخصم الإداري',
                      loadingLabel: 'جاري الاعتماد...',
                      icon: Symbols.check,
                      isLoading: _isLoading,
                      onPressed: _onSave,
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
}
