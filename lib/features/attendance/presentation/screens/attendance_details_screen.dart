import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/attendance_record.dart';

class AttendanceDetailsScreen extends StatelessWidget {
  final AttendanceRecord record;

  const AttendanceDetailsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final hasDelay = record.delayMinutes > 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('تفاصيل سجل الحضور'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'سجل الحضور التاريخي',
            onPressed: () =>
                context.push('/attendance/history', extra: record.employeeName),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Context Banner
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'الثلاثاء، 16 أبريل 2024',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.paddingSm),
                Container(
                  constraints: const BoxConstraints(maxWidth: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasDelay
                        ? AppColors.errorContainer
                        : const Color(0xFFEAF5EA),
                    borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                  ),
                  child: Text(
                    hasDelay ? 'حالة غير مكتملة (تأخير)' : 'منضبط',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm.copyWith(
                      color: hasDelay
                          ? AppColors.onErrorContainer
                          : const Color(0xFF2E8B2E),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Employee Card
            Container(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
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
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppDimens.paddingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.employeeName,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          record.role,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'الفرع الرئيسي - وسط البلد (#01)',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Schedule vs Actual Comparison
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
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timelapse,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'سجل البصمة مقابل المواعيد',
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
                      const SizedBox(width: AppDimens.paddingSm),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 130),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusFull,
                          ),
                        ),
                        child: Text(
                          'الوردية الصباحية A',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingMd),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppDimens.paddingMd),
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
                                'الموعد المجدول',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '09:00 ص - 05:00 م',
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '8 ساعات عمل',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppDimens.paddingMd),
                          decoration: BoxDecoration(
                            color: hasDelay
                                ? AppColors.errorContainer.withValues(
                                    alpha: 0.4,
                                  )
                                : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              AppDimens.radiusLg,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'البصمة الفعلية',
                                style: AppTypography.labelSm.copyWith(
                                  color: hasDelay
                                      ? AppColors.error
                                      : AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${record.checkInTime} - ${record.checkOutTime}',
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: hasDelay
                                      ? AppColors.error
                                      : AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hasDelay
                                    ? 'تأخير ${record.delayMinutes} دقيقة'
                                    : 'حضور منضبط',
                                style: AppTypography.labelSm.copyWith(
                                  color: hasDelay
                                      ? AppColors.error
                                      : const Color(0xFF2E8B2E),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.paddingMd),

                  // Deduction Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الخصم الآلي المسجل',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                            Text(
                              '${record.deductionAmount.toStringAsFixed(2)} ج.م',
                              style: AppTypography.headlineSm.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hasDelay
                                    ? AppColors.error
                                    : AppColors.onSurface,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        if (record.isDeductionAdjusted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusFull,
                              ),
                            ),
                            child: Text(
                              'معدل إدارياً',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingLg),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: () =>
                  context.push('/attendance/adjust', extra: record),
              icon: const Icon(Icons.edit_note),
              label: const Text('تعديل الخصم الإداري (ATT-03)'),
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
              onPressed: () => context.push(
                '/attendance/history',
                extra: record.employeeName,
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('عرض سجل الحضور الشهري (ATT-04)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
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
}
