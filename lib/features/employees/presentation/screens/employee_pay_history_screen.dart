import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/employee.dart';

class EmployeePayHistoryScreen extends StatelessWidget {
  final Employee employee;

  const EmployeePayHistoryScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    final mockPayRecords = [
      {
        'month': 'مارس 2024',
        'date': '31 مارس 2024',
        'base': 4500,
        'allowance': 400,
        'deduction': 250,
        'net': 4650,
        'status': 'مسدد عبر البنك',
        'reference': 'PAY-2024-03-1048',
      },
      {
        'month': 'فبراير 2024',
        'date': '29 فبراير 2024',
        'base': 4500,
        'allowance': 400,
        'overtime': 250,
        'deduction': 0,
        'net': 5150,
        'status': 'مسدد عبر البنك',
        'reference': 'PAY-2024-02-1048',
      },
      {
        'month': 'يناير 2024',
        'date': '31 يناير 2024',
        'base': 4500,
        'allowance': 400,
        'deduction': 100,
        'net': 4800,
        'status': 'مسدد عبر البنك',
        'reference': 'PAY-2024-01-1048',
      },
      {
        'month': 'ديسمبر 2023',
        'date': '31 ديسمبر 2023',
        'base': 4500,
        'allowance': 400,
        'deduction': 0,
        'net': 4900,
        'status': 'مسدد نقداً - خزينة الفرع',
        'reference': 'PAY-2023-12-1048',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('سجل الرواتب والدفعات'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Employee Quick Identity
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
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      employee.name.length >= 2 ? employee.name.substring(0, 2) : 'مو',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onPrimaryFixed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.paddingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${employee.role} • ${employee.branchName}',
                          style: AppTypography.bodySm.copyWith(color: AppColors.secondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                    ),
                    child: Text(
                      '#${employee.code}',
                      style: AppTypography.labelSm.copyWith(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.paddingMd),

            // Bento Metrics Strip
            Row(
              children: [
                Expanded(
                  child: Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'إجمالي المنصرف 2024',
                              style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 11),
                            ),
                            const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '19,500 ج.م',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '4 مسيرات معتمدة',
                          style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 10),
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
                            Text(
                              'آخر دفعة معتمدة',
                              style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 11),
                            ),
                            const Icon(Icons.receipt_long, size: 18, color: AppColors.tertiary),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '4,650 ج.م',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'عن شهر مارس 2024',
                          style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.paddingLg),

            // Pay History List
            Text(
              'سجل المسيرات الشهرية المعتمدة',
              style: AppTypography.headlineSm.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimens.paddingSm),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mockPayRecords.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rec = mockPayRecords[index];
                return Container(
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
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                rec['month'] as String,
                                style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF5EA),
                                  borderRadius: BorderRadius.circular(AppDimens.radiusFull),
                                ),
                                child: Text(
                                  rec['status'] as String,
                                  style: AppTypography.labelSm.copyWith(
                                    color: const Color(0xFF2E8B2E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${rec['net']} ج.م',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              'الأساسي: ${rec['base']} ج.م',
                              style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 11),
                            ),
                            Text(
                              'البدلات: +${rec['allowance']} ج.م',
                              style: AppTypography.labelSm.copyWith(color: const Color(0xFF2E8B2E), fontSize: 11),
                            ),
                            if ((rec['deduction'] as int) > 0)
                              Text(
                                'الخصومات: -${rec['deduction']} ج.م',
                                style: AppTypography.labelSm.copyWith(color: AppColors.error, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            rec['reference'] as String,
                            style: AppTypography.labelSm.copyWith(
                              fontFamily: 'monospace',
                              color: AppColors.secondary,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            rec['date'] as String,
                            style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
